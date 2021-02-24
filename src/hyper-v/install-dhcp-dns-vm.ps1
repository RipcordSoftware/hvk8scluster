param (
    [string] $vmName = "k8s-dhcp-dns",
    [string] $vmIp = "172.31.0.2",
    [int] $vmCpuCount = 2,
    [int64] $vmMemoryMB = 768,
    [int64] $vmDiskSizeGB = 4,
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

[string] $isoPath = "$([Config]::IsoPath)/preseed-dhcp-dns-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $isoPath)) {
    Write-Error "The ISO image '${isoPath}' is missing, please build it before proceeding"
}

[bool] $created = [Vm]::Create($vmName, $isoPath, $vmCpuCount, $vmMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $updateVm)

if ($created) {
    # if we created a new VM then remove any old host keys
    if ($vmIp) {
        [Ssh]::RemoveHostKeys($vmIp)
    }

    # wait for the VM to fully come up
    Write-Host "Waiting for active SSH on '${vmIp}'..."
    [Ssh]::WaitForSsh($vmIp, $true)
}
