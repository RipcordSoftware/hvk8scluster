param (
    [string] $vmName = "k8s-unknown",
    [int] $vmCpuCount = 2,
    [int] $vmMinMemoryMB = 1024,
    [int] $vmMaxMemoryMB = 2048,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [string] $debianVersion = "10.7.0"
)

$ErrorActionPreference = "Stop"

. ./scripts/vm.ps1
. ./scripts/git.ps1

[string] $repoRoot = [Git]::RepoRoot
[string] $isoPath = "${repoRoot}/bin/preseed-k8s-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $isoPath)) {
    Write-Error "The ISO image '$isoPath' is missing, please build it before proceeding"
}

[Vm]::Create($vmName, $isoPath, $vmCpuCount, $vmMinMemoryMB, $vmMaxMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm)
