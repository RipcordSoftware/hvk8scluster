param (
    [string] $vmName = "k8s-dhcp-dns",
    [string] $vmIp = "172.31.0.2",
    [int] $vmCpuCount = 2,
    [int64] $vmMinMemoryMB = 256,
    [int64] $vmMaxMemoryMB = 768,
    [int64] $vmDiskSizeGB = 4,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm,
    [string] $debianVersion = "10.7.0"
)

$ErrorActionPreference = "Stop"

. ./scripts/vm.ps1
. ./scripts/git.ps1
. ./scripts/ssh.ps1

[string] $repoRoot = [Git]::RepoRoot
[string] $isoPath = "${repoRoot}/bin/preseed-dhcp-dns-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $isoPath)) {
    Write-Error "The ISO image '$isoPath' is missing, please build it before proceeding"
}

[bool] $created = [Vm]::Create($vmName, $isoPath, $vmCpuCount, $vmMinMemoryMB, $vmMaxMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $updateVm)

# if we created a new VM then remove any old host keys
if ($created -and $vmIp) {
    [Ssh]::RemoveHostKeys($vmIp)
}
