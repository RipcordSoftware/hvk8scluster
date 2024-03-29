param (
    [string] $vmTemplateName = "hvk8s-template",
    [string] $vmName = "hvk8s-unknown",
    [string] $vmIp,
    [int] $vmCpuCount = 2,
    [Parameter(Mandatory)][object] $vmMemory,
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/modules/vm.ps1"
. "${PSScriptRoot}/scripts/modules/ssh.ps1"
. "${PSScriptRoot}/scripts/hvk8s/config.ps1"

# optionally convert vmMemory from JSON
if ($vmMemory -is [string]) {
    $vmMemory = $vmMemory | ConvertFrom-Json
}

[object] $vm = $global:rs.Vm::GetVm($vmName)

if ($vm -and !$updateVm) {
    if ($removeVm) {
        $global:rs.Vm::Remove($vmName)
        $vm = $null
    } else {
        Write-Error "The VM '${vmName}' already exists and neither removeVm or updateVm has been specified"
    }
}

[bool] $createdVm = $false
if (!$vm) {
    Write-Host "Removing the old VHD..."
    $global:rs.Vm::RemoveVhd($vmName)

    # import the VM
    Write-Host "Importing the template..."
    $vm = $global:rs.Vm::Import($global:rs.Config::ExportDir, $vmTemplateName, $vmName)

    $createdVm = $true
}

# update the CPU cores and memory
Write-Host "Updating the cloned VM..."
$global:rs.Vm::Update($vmName, $vmCpuCount, $vmMemory)

if ($createdVm) {
    # remove any old host keys
    if ($vmIp) {
        $global:rs.Ssh::RemoveHostKeys($vmIp)
    }

    Write-Host "Starting the cloned VM..."
    Start-VM -Name $vmName
}