param (
    [string] $vmName = "k8s-unknown",
    [string] $vmIp,
    [int] $vmCpuCount = 2,
    [int] $vmMemoryMB = 1024,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm,
    [string] $debianVersion = "10.8.0"
)

$ErrorActionPreference = "Stop"

. ./scripts/vm.ps1
. ./scripts/config.ps1
. ./scripts/ssh.ps1

[string] $isoPath = "$([Config]::IsoDir)/preseed-k8s-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $isoPath)) {
    Write-Error "The ISO image '$isoPath' is missing, please build it before proceeding"
}

[bool] $created = [Vm]::Create($vmName, $isoPath, $vmCpuCount, $vmMinMemoryMB, $vmMaxMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $updateVm)

# if we created a new VM then remove any old host keys
if ($created -and $vmIp) {
    [Ssh]::RemoveHostKeys($vmIp)
}
