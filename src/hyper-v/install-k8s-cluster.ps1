param (
    [int] $nodeCount = 2,
    [int] $nodeMemoryMB = 6144,
    [int] $masterMemoryMB = 4096,
    [string] $vmTemplateName,
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm,
    [switch] $skipVmProvisioning,
    [switch] $ignoreKeyPermissions
)

$ErrorActionPreference = "Stop"

. ./scripts/git.ps1
. ./scripts/ssh.ps1
. ./scripts/vm.ps1
. ./scripts/cluster.ps1

if (!$sshPrivateKeyPath) {
    [string] $repoRoot = [Git]::RepoRoot
    $sshPrivateKeyPath = @("${repoRoot}/src/keys/id_rsa", "~/.ssh/id_rsa") | Where-Object { Test-Path $_ } | Select-Object -First 1
}

# define the cluster
[object] $master = @{ vmName = "k8s-master"; hostname = "k8s-master"; ip = "172.31.0.10"; node = $false; minMemoryMB = 256; maxMemoryMB = $masterMemoryMB }
[object] $cluster = @( $master )

if ($nodeCount -gt 0) {
    $cluster += @(1 .. $nodeCount) | ForEach-Object {
        [int] $nodeId = $_
        [int] $hostIp = 10 + $nodeId
        @{ vmName = "k8s-node${nodeId}"; hostname = "k8s-node${nodeId}"; ip = "172.31.0.${hostIp}"; node = $true; minMemoryMB = 256; maxMemoryMB = $nodeMemoryMB }
    }
}

# check the read/write permissions on the private key file
[object] $keyAccess = (Get-Acl -Path $sshPrivateKeyPath).Access |
    Where-Object { ! (@("NT AUTHORITY\SYSTEM", "BUILTIN\Administrators") -contains $_.IdentityReference) } |
    Where-Object { $_.IdentityReference -notmatch "\\${env:USERNAME}`$" }
if (!$ignoreKeyPermissions -and $keyAccess) {
    Write-Error "The permissions on the private key file '$sshPrivateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

# check the DHCP server is available
[object] $dhcpServer = [Vm]::GetVM("k8s-dhcp-dns")
if (!$dhcpServer -or ![Ssh]::TestSsh("172.31.0.2")) {
    Write-Error "Unable to find the DHCP/DNS server, is it running?"
}

# reset the DHCP server
[Ssh]::InvokeRemoteCommand("172.31.0.2", 'sudo systemctl stop dnsmasq && sudo rm -f rm /var/lib/misc/dnsmasq.leases && sudo systemctl start dnsmasq', $sshUser, $sshPrivateKeyPath) | Out-Null

# provision the VMs on Hyper-V
if (!$skipVmProvisioning) {
    $cluster | ForEach-Object {
        [string] $vmName = $_.vmName
        if ($vmTemplateName) {
            Write-Host "Cloning '${vmTemplateName}' to '${vmName}'..."
            .\clone-k8s-vm.ps1 `
                -vmTemplateName $vmTemplateName -vmName $vmName -vmIp $_.ip -vmMinMemoryMB $_.minMemoryMB -vmMaxMemoryMB $_.maxMemoryMB `
                -removeVhd:$removeVhd -removeVm:$removeVm -updateVm:$updateVm
        } else {
            Write-Host "Creating '${vmName}'..."
            .\install-k8s-vm.ps1 `
                -vmName $vmName -vmIp $_.ip -vmMinMemoryMB $_.minMemoryMB -vmMaxMemoryMB $_.maxMemoryMB `
                -removeVhd:$removeVhd -removeVm:$removeVm -updateVm:$updateVm
        }
    }

    # configure the VM networking
    $cluster | ForEach-Object {
        [string] $vmName = $_.vmName
        [string] $ip = $null

        Write-Host "Waiting for VM IP address for '${vmName}'..."
        while (!$ip) {
            $ip = [Vm]::WaitForIpv4($vmName, $true)

            if ($ip) {
                Write-Host "Waiting for active SSH on '${ip}'..."
                [Ssh]::WaitForSsh($ip, $true)

                Write-Host "Discovered '${vmName}' on '${ip}'"
                [Cluster]::SetHostName($ip, $_.hostname, $sshUser, $sshPrivateKeyPath)
            }
        }
    }
}

# initialize the master
$cluster | Where-Object { !$_.node } | ForEach-Object {
    Write-Host "Waiting for active SSH on '$($_.ip)'..."
    [Ssh]::WaitForSsh($_.ip, $true)

    Write-Host "Initializing cluster master '$($_.hostname)'..."
    [Cluster]::InitializeMaster($_.ip, $sshUser, $sshPrivateKeyPath)
    [Cluster]::InitializeCalico($_.ip, $sshUser, $sshPrivateKeyPath)
}

# get the cluster join command
[string] $masterIp = $cluster | Where-Object { !$_.node } | ForEach-Object { $_.ip } | Select-Object -First 1
[string] $joinCommand = [Cluster]::GetJoinCommand($masterIp, $sshUser, $sshPrivateKeyPath)
Write-Host "Got join command: $joinCommand"

# initialize the nodes
$cluster | Where-Object { $_.node } | ForEach-Object {
    Write-Host "Waiting for active SSH on '$($_.ip)'..."
    [Ssh]::WaitForSsh($_.ip, $true)

    Write-Host "Node '$($_.hostname)' is requesting to join the cluster..."
    [Cluster]::Join($_.ip, $joinCommand, $sshUser, $sshPrivateKeyPath)
}
