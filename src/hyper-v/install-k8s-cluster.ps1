param (
    [int] $nodeCount = 2,
    [int] $nodeMemoryMB = 6144,
    [int] $masterMemoryMB = 4096,
    [string] $privateKeyPath,
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm,
    [switch] $skipVmProvisioning,
    [switch] $ignoreKeyPermissions
)

$ErrorActionPreference = "Stop"

. ./scripts/git.ps1

if (!$privateKeyPath) {
    [string] $repoRoot = [Git]::RepoRoot
    $privateKeyPath = @("${repoRoot}/src/keys/id_rsa", "~/.ssh/id_rsa") | Where-Object { Test-Path $_ } | Select-Object -First 1
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

function Get-VmIpV4Address([string[]] $addresses) {
    $addresses | Where-Object { $_.Contains(".") }
}

function Invoke-RemoteCommand([string] $ip, [string] $command) {
    ssh -o "StrictHostKeyChecking=no" -i $privateKeyPath hvk8s@${ip} $command
    if (!$?) {
        Write-Error "The command '${command}' on host '${ip}' has failed"
    }
}

function Set-VmHostName([string] $ip, [string] $hostName) {
    [string] $command =
        'if [ "$(hostname)" != ' + "'${hostName}' ]; then " +
        " sudo sed -i 's/k8s-unknown/${hostName}/g' /etc/hosts && " +
        " sudo sed -i 's/k8s-unknown/${hostName}/g' /etc/hostname && " +
        " sudo rm -f /var/lib/dhcp/*.leases && " +
        " sudo systemctl reboot --no-block; " +
        "fi"

    Invoke-RemoteCommand -ip $ip -command $command
}

function Initialize-ClusterMaster([string] $ip) {
    [string] $command =
        'if [ ! -d .kube ]; then ' +
        ' sudo kubeadm init --pod-network-cidr=172.30.0.0/16 && ' +
        ' mkdir -p $HOME/.kube && ' +
        ' sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && ' +
        ' sudo chown $(id -u):$(id -g) $HOME/.kube/config; ' +
        'fi'
    Invoke-RemoteCommand -ip $ip -command $command

    $command =
        'wget https://docs.projectcalico.org/v3.17/manifests/calico.yaml -O calico.yaml && ' +
        "sed -i 's/192.168.0.0/172.30.0.0/' calico.yaml && " +
        'kubectl apply -f calico.yaml'
    Invoke-RemoteCommand -ip $ip -command $command
}

function Get-ClusterJoinCommand([string] $ip) {
    [string] $command = "kubeadm token create --print-join-command"
    Invoke-RemoteCommand -ip $ip -command $command
}

# check the read/write permissions on the private key file
[object] $keyAccess = (Get-Acl -Path $privateKeyPath).Access |
    Where-Object { ! (@("NT AUTHORITY\SYSTEM", "BUILTIN\Administrators") -contains $_.IdentityReference) } |
    Where-Object { $_.IdentityReference -notmatch "\\${env:USERNAME}`$" }
if (!$ignoreKeyPermissions -and $keyAccess) {
    Write-Error "The permissions on the private key file '$privateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

# check the DHCP server is available
[object] $dhcpServer = Get-VM -Name "k8s-dhcp-dns" -ErrorAction SilentlyContinue
if (!$dhcpServer -or !(Test-NetConnection -ComputerName "172.31.0.2" -Port 22).TcpTestSucceeded) {
    Write-Error "Unable to find the DHCP/DNS server, is it running?"
}

# reset the DHCP server
Invoke-RemoteCommand -ip "172.31.0.2" -command 'sudo systemctl stop dnsmasq && sudo rm -f rm /var/lib/misc/dnsmasq.leases && sudo systemctl start dnsmasq'

# provision the VMs on Hyper-V
if (!$skipVmProvisioning) {
    $cluster | ForEach-Object { .\install-k8s-vm.ps1 -vmName $_.vmName -removeVhd:$removeVhd -removeVm:$removeVm -updateVm:$updateVm -vmMinMemoryMB $_.minMemoryMB -vmMaxMemoryMB $_.maxMemoryMB }

    # configure the VM networking
    $cluster | ForEach-Object {
        [string] $vmName = $_.vmName
        [string] $ip = $null

        Write-Host "Waiting for VM IP address for '${vmName}'"
        while (!$ip) {
            [object] $adapter = Get-VMNetworkAdapter -VMName $vmName

            while ($adapter.IPAddresses.Count -lt 1) {
                Start-Sleep -Seconds 10
                Write-Host -NoNewline "."
            }

            $ip = Get-VmIpV4Address $adapter.IPAddresses
            if ($ip -and (Test-NetConnection -ComputerName $ip -Port 22).TcpTestSucceeded) {
                Write-Host
                Write-Host "Discovered '${vmName}' on '${ip}'"
                Set-VmHostName -ip $ip -hostName $_.hostname
            }
        }
    }
}

# initialize the master
$cluster | Where-Object { !$_.node } | ForEach-Object {
    Write-Host "Waiting for active SSH on '$($_.ip)'"
    while (!(Test-NetConnection -ComputerName $_.ip -Port 22).TcpTestSucceeded) {
        Start-Sleep -Seconds 10
        Write-Host -NoNewline "."
    }
    Write-Host

    Write-Host "Initializing cluster master '$($_.hostname)'..."
    Initialize-ClusterMaster -ip $_.ip
}

# get the cluster join command
[string] $masterIp = $cluster | Where-Object { !$_.node } | ForEach-Object { $_.ip }
[string] $joinCommand = Get-ClusterJoinCommand -ip $masterIp
Write-Host "Got join command: $joinCommand"

# initialize the nodes
$cluster | Where-Object { $_.node } | ForEach-Object {
    Write-Host "Waiting for active SSH on '$($_.ip)'"
    while (!(Test-NetConnection -ComputerName $_.ip -Port 22).TcpTestSucceeded) {
        Start-Sleep -Seconds 10
        Write-Host -NoNewline "."
    }
    Write-Host

    Write-Host "Node '$($_.hostname)' is requesting to join the cluster..."
    Invoke-RemoteCommand -ip $_.ip -command "if [ ! -f /etc/kubernetes/kubelet.conf ]; then sudo ${joinCommand}; fi"
}
