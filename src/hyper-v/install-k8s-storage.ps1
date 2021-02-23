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

if (!$sshPrivateKeyPath) {
    [string] $repoRoot = [Config]::RepoRoot
    $sshPrivateKeyPath = @("${repoRoot}/src/keys/id_rsa", "~/.ssh/id_rsa") | Where-Object { Test-Path $_ } | Select-Object -First 1
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

[uint64] $vmStorageDiskSize = $vmStorageDiskSizeGB * [K8s]::Memory.Gi

$nodeVms | Where-Object {
        $_.HardDrives.Count -lt 2
    } | ForEach-Object {
        Write-Host "Adding a storage disk to '$($_.Name)'..."
        [string] $storageDiskPath = [Vm]::GetVhdPath($_.Name, "storage")
        New-VHD -Path $storageDiskPath -Dynamic -SizeBytes $vmStorageDiskSize
        Add-VMHardDiskDrive -VMName $_.Name -Path $storageDiskPath
    }

Write-Host "Asking Helm to install rook-ceph..."
[Ssh]::InvokeRemoteCommand(
    [Config]::Vm.Master.Ip,
    'helm repo add rook-release https://charts.rook.io/release && ' +
    'if [ ! $(kubectl get ns rook-ceph) ]; then kubectl create namespace rook-ceph; fi && ' +
    'helm upgrade -i --namespace rook-ceph rook-ceph rook-release/rook-ceph',
    $sshUser, $sshPrivateKeyPath)

Write-Host "Asking kubectl to initialize the cluster and storage class..."
[Ssh]::InvokeRemoteCommand(
    [Config]::Vm.Master.Ip,
    'if [ ! -d "code" ]; then ' +
    'mkdir -p code && cd code && ' +
    'git clone --single-branch --branch release-1.5 --depth 1 https://github.com/rook/rook.git && ' +
    'cd rook/cluster/examples/kubernetes/ceph && ' +
    'kubectl apply -f cluster.yaml && ' +
    'cd csi/rbd && ' +
    'kubectl apply -f storageclass.yaml; ' +
    'fi',
    $sshUser, $sshPrivateKeyPath)
