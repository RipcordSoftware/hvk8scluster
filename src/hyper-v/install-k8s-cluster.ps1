param (
    [int] $nodeCount = 3,
    [int] $nodeMemoryMB = 4096,
    [int] $masterMemoryMB = 2048,
    [string] $vmTemplateName = 'k8s-template',
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm,
    [switch] $skipVmProvisioning,
    [switch] $skipLbProvisioning,
    [switch] $ignoreKeyPermissions,
    [switch] $disableVmTemplate
)

$ErrorActionPreference = "Stop"

. ./scripts/config.ps1
. ./scripts/ssh.ps1
. ./scripts/vm.ps1
. ./scripts/cluster.ps1

if (!$global:rs.Vm::IsInstalled()) {
    Write-Error "Hyper-V is not installed or the service isn't running, please install manually or using the provided scripts"
}

if (!$global:rs.Vm::IsAdministrator()) {
    Write-Error "You require Administrator rights or membership of the 'Hyper-V Administrator' group"
}

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = $global:rs.Ssh::DiscoverPrivateKeyPath($global:rs.Config::RepoRoot)
}

# define the cluster
[object] $master = @{ vmName = "k8s-master"; hostname = "k8s-master"; ip = $global:rs.Config::Vm.Master.Ip; node = $false; memoryMB = $masterMemoryMB }
[object] $cluster = @( $master )

if ($nodeCount -gt 0) {
    $cluster += @(1 .. $nodeCount) | ForEach-Object {
        [int] $nodeId = $_
        [string] $hostIp = $global:rs.Config::Vm.Master.Ip -replace '[0-9]$',"${nodeId}"
        @{ vmName = "k8s-node${nodeId}"; hostname = "k8s-node${nodeId}"; ip = ${hostIp}; node = $true; memoryMB = $nodeMemoryMB }
    }
}

# check the read/write permissions on the private key file
if (!$ignoreKeyPermissions -and !$global:rs.Ssh::CheckKeyFilePermissions($sshPrivateKeyPath)) {
    Write-Error "The permissions on the private key file '$sshPrivateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

# check the template is available unless we are in non-template mode
if (!$disableVmTemplate -and $vmTemplateName -and !$global:rs.Vm::GetExportedVmConfigPath($vmTemplateName)) {
    Write-Error "Unable to find VM template '${vmTemplateName}', you must create the template file or specify -disableVmTemplate"
}

# check the DHCP server is available
[object] $dhcpServer = $global:rs.Vm::GetVM($global:rs.Config::Vm.Dhcp.Name)
if (!$dhcpServer -or !$global:rs.Ssh::TestSsh($global:rs.Config::Vm.Dhcp.Ip)) {
    Write-Error "Unable to find the DHCP/DNS server, is it running?"
}

# reset the DHCP server
Write-Host "Resetting the DHCP server..."
$global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Dhcp.Ip, './remote-commands/reset-dnsmasq-state.sh', $sshUser, $sshPrivateKeyPath) | Out-Null

# provision the VMs on Hyper-V
if (!$skipVmProvisioning) {
    $cluster | ForEach-Object {
        [string] $vmName = $_.vmName
        if (!$disableVmTemplate -and $vmTemplateName) {
            Write-Host "Cloning '${vmTemplateName}' to '${vmName}'..."
            .\clone-k8s-vm.ps1 `
                -vmTemplateName $vmTemplateName -vmName $vmName -vmIp $_.ip -vmMemoryMB $_.memoryMB `
                -removeVhd:$removeVhd -removeVm:$removeVm -updateVm:$updateVm
        } else {
            Write-Host "Creating '${vmName}'..."
            .\install-k8s-vm.ps1 `
                -vmName $vmName -vmIp $_.ip -vmMemoryMB $_.memoryMB `
                -removeVhd:$removeVhd -removeVm:$removeVm -updateVm:$updateVm
        }
    }

    # configure the VM networking
    $cluster | ForEach-Object {
        [string] $vmName = $_.vmName
        [string] $ip = $null

        Write-Host "Waiting for VM IP address for '${vmName}'..."
        while (!$ip) {
            $ip = $global:rs.Vm::WaitForIpv4($vmName, $true)

            if ($ip) {
                Write-Host "Waiting for active SSH on '${ip}'..."
                $global:rs.Ssh::WaitForSsh($ip, $true)

                Write-Host "Discovered '${vmName}' on '${ip}'"
                $global:rs.Cluster::SetHostName($ip, $_.hostname, $sshUser, $sshPrivateKeyPath)
            }
        }
    }
}

# initialize the master
$cluster | Where-Object { !$_.node } | ForEach-Object {
    Write-Host "Waiting for active SSH on '$($_.ip)'..."
    $global:rs.Ssh::WaitForSsh($_.ip, $true)

    Write-Host "Initializing cluster master '$($_.hostname)'..."
    $global:rs.Cluster::InitializeMaster($_.ip, $sshUser, $sshPrivateKeyPath)
    $global:rs.Cluster::InitializeCalico($_.ip, $sshUser, $sshPrivateKeyPath)
}

# get the cluster join command
[string] $masterIp = $cluster | Where-Object { !$_.node } | ForEach-Object { $_.ip } | Select-Object -First 1
[string] $joinCommand = $global:rs.Cluster::GetJoinCommand($masterIp, $sshUser, $sshPrivateKeyPath)
Write-Host "Got join command: $joinCommand"

# initialize the nodes
$cluster | Where-Object { $_.node } | ForEach-Object {
    Write-Host "Waiting for active SSH on '$($_.ip)'..."
    $global:rs.Ssh::WaitForSsh($_.ip, $true)

    Write-Host "Node '$($_.hostname)' is requesting to join the cluster..."
    $global:rs.Cluster::Join($_.ip, $joinCommand, $sshUser, $sshPrivateKeyPath)
}

if (!$skipLbProvisioning) {
    Write-Host "Installing bitnami-metallb..."
    $global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Master.Ip, './remote-commands/install-bitnami-metallb-chart.sh', $sshUser, $sshPrivateKeyPath)
}
