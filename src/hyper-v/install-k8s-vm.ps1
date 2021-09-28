param (
    [string] $vmName = "hvk8s-unknown",
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

. "${PSScriptRoot}/scripts/modules/vm.ps1"
. "${PSScriptRoot}/scripts/hvk8s/config.ps1"
. "${PSScriptRoot}/scripts/modules/ssh.ps1"

[string] $isoPath = "$($global:rs.Config::IsoDir)/preseed-hvk8s-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $isoPath)) {
    Write-Error "The ISO image '$isoPath' is missing, please build it before proceeding"
}

[bool] $created = $global:rs.Vm::Create($vmName, $isoPath, $vmCpuCount, $vmMinMemoryMB, $vmMaxMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $updateVm)

# if we created a new VM then remove any old host keys
if ($created -and $vmIp) {
    $global:rs.Ssh::RemoveHostKeys($vmIp)
}
