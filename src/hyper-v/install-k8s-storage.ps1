param (
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [int] $vmStorageDiskSizeGB = 100,
    [string] $nodeRegEx = '^hvk8s-node[0-9]+$',
    [switch] $ignoreKeyPermissions
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/hvk8s/config.ps1"
. "${PSScriptRoot}/scripts/modules/ssh.ps1"
. "${PSScriptRoot}/scripts/modules/vm.ps1"
. "${PSScriptRoot}/scripts/modules/k8s.ps1"
. "${PSScriptRoot}/scripts/modules/backgroundprocess.ps1"

if (!$global:rs.Vm::IsInstalled()) {
    Write-Error "Hyper-V is not installed or the service isn't running, please install manually or using the provided scripts"
}

if (!$global:rs.Vm::IsAdministrator()) {
    Write-Error "You require Administrator rights or membership of the 'Hyper-V Administrator' group"
}

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = $global:rs.Ssh::DiscoverPrivateKeyPath($global:rs.Config::RepoRoot)
}

# check the read/write permissions on the private key file
if (!$ignoreKeyPermissions -and !$global:rs.Ssh::CheckKeyFilePermissions($sshPrivateKeyPath)) {
    Write-Error "The permissions on the private key file '$sshPrivateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

[object] $vms = Get-VM
[object] $nodeVms = $vms | Where-Object { $_.Name -match $nodeRegEx }
if ($nodeVms.Count -lt 3) {
    Write-Error "You must have at least three nodes before Rook/Ceph can be installed; only $($nodeVms.Count) nodes found"
}

# give the background processes access to the app args
$global:rs.BackgroundProcess::SetInitialVars($MyInvocation)

# check the DHCP server is available
$global:rs.BackgroundProcess::SpinWait("Checking the DHCP server is available...", {
    [object] $dhcpServer = $global:rs.Vm::GetVM($global:rs.Config::Vm.Dhcp.Name)
    if (!$dhcpServer -or !$global:rs.Ssh::TestSsh($global:rs.Config::Vm.Dhcp.Ip)) {
        Write-Error "Unable to find the DHCP/DNS server, is it running?"
    }
})

$nodeVms | Where-Object {
        $_.HardDrives.Count -lt 2
    } | ForEach-Object {
        [object] $vm = $_
        $global:rs.BackgroundProcess::SpinWait("Adding a storage disk to '$($vm.Name)'...", { param ($vm)
            [string] $storageDiskPath = $global:rs.Vm::GetVhdPath($vm.Name, "storage")
            if (!(Test-Path $storageDiskPath)) {
                [uint64] $vmStorageDiskSize = $vmStorageDiskSizeGB * $global:rs.K8s::Memory.Gi
                New-VHD -Path $storageDiskPath -Dynamic -SizeBytes $vmStorageDiskSize | Out-Null
                Add-VMHardDiskDrive -VMName $vm.Name -Path $storageDiskPath
            }
        }, @{ vm = $vm })
    }

$global:rs.BackgroundProcess::SpinWait("Asking Helm to install rook-ceph...", {
    $global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Master.Ip, "./remote-commands/install-rook-ceph-chart.sh", $sshUser, $sshPrivateKeyPath)
})

$global:rs.BackgroundProcess::SpinWait("Asking kubectl to initialize the cluster and storage class...", {
    $global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Master.Ip, "./remote-commands/install-rook-ceph-cluster.sh", $sshUser, $sshPrivateKeyPath)
})

$global:rs.BackgroundProcess::SpinWait("Asking kubectl to initialize the ceph toolbox...", {
    $global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Master.Ip, "./remote-commands/install-rook-ceph-toolbox.sh", $sshUser, $sshPrivateKeyPath)
})
