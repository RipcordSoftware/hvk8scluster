param (
    [string] $vmTemplateName = "k8s-template",
    [string] $vmName = "k8s-unknown",
    [string] $vmIp,
    [int] $vmCpuCount = 2,
    [int] $vmMemoryMB = 1024,
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm
)

$ErrorActionPreference = "Stop"

. ./scripts/vm.ps1
. ./scripts/config.ps1

[object] $vm = [Vm]::GetVm($vmName)

if ($vm -and !$updateVm) {
    if ($removeVm) {
        [Vm]::Remove($vmName)
        $vm = $null
    } else {
        Write-Error "The VM '${vmName}' already exists and neither removeVm or updateVm has been specified"
    }
}

[bool] $createdVm = $false
if (!$vm) {
    Write-Host "Removing the old VHD..."
    [Vm]::RemoveVhd($vmName)

    # import the VM
    Write-Host "Importing the template..."
    $vm = [Vm]::Import($vmTemplateName, $vmName)

    $createdVm = $true
}

# update the CPU cores and memory
Write-Host "Updating the cloned VM..."
[Vm]::Update($vmName, $vmCpuCount, $vmMemoryMB)

if ($createdVm) {
    # remove any old host keys
    if ($vmIp) {
        [Ssh]::RemoveHostKeys($vmIp)
    }

    Write-Host "Starting the cloned VM..."
    Start-VM -Name $vmName
}