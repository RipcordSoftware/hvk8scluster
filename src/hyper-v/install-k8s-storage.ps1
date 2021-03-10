param (
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [int] $vmStorageDiskSizeGB = 100,
    [string] $nodeRegEx = '^k8s-node[0-9]+$',
    [switch] $ignoreKeyPermissions
)

$ErrorActionPreference = "Stop"

. ./scripts/config.ps1
. ./scripts/ssh.ps1
. ./scripts/vm.ps1
. ./scripts/k8s.ps1

if (![Vm]::IsInstalled()) {
    Write-Error "Hyper-V is not installed or the service isn't running, please install manually or using the provided scripts"
}

if (![Vm]::IsAdministrator()) {
    Write-Error "You require Administrator rights or membership of the 'Hyper-V Administrator' group"
}

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = [Ssh]::DiscoverPrivateKeyPath([Config]::RepoRoot)
}

# check the read/write permissions on the private key file
if (!$ignoreKeyPermissions -and ![Ssh]::CheckKeyFilePermissions($sshPrivateKeyPath)) {
    Write-Error "The permissions on the private key file '$sshPrivateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

# check the DHCP server is available
[object] $dhcpServer = [Vm]::GetVM([Config]::Vm.Dhcp.Name)
if (!$dhcpServer -or ![Ssh]::TestSsh([Config]::Vm.Dhcp.Ip)) {
    Write-Error "Unable to find the DHCP/DNS server, is it running?"
}

[object] $vms = Get-VM

[object] $nodeVms = $vms | Where-Object { $_.Name -match $nodeRegEx }

if ($nodeVms.Count -lt 3) {
    Write-Error "You must have at least three nodes before Rook/Ceph can be installed; only $($nodeVms.Count) nodes found"
}

[uint64] $vmStorageDiskSize = $vmStorageDiskSizeGB * [K8s]::Memory.Gi

$nodeVms | Where-Object {
        $_.HardDrives.Count -lt 2
    } | ForEach-Object {
        Write-Host "Adding a storage disk to '$($_.Name)'..."
        [string] $storageDiskPath = [Vm]::GetVhdPath($_.Name, "storage")
        New-VHD -Path $storageDiskPath -Dynamic -SizeBytes $vmStorageDiskSize | Out-Null
        Add-VMHardDiskDrive -VMName $_.Name -Path $storageDiskPath
    }

Write-Host "Asking Helm to install rook-ceph..."
[Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "./remote-commands/install-rook-ceph-chart.sh", $sshUser, $sshPrivateKeyPath)

Write-Host "Asking kubectl to initialize the cluster and storage class..."
[Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "./remote-commands/install-rook-ceph-cluster.sh", $sshUser, $sshPrivateKeyPath)

Write-Host "Asking kubectl to initialize the ceph toolbox..."
[Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "./remote-commands/install-rook-ceph-toolbox.sh", $sshUser, $sshPrivateKeyPath)