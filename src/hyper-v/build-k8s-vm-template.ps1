param (
    [string] $vmName = "hvk8s-template",
    [int] $vmCpuCount = 2,
    [int] $vmMemoryMB = 1024,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $skipVmProvisioning,
    [switch] $removeVmTemplate,
    [string] $debianVersion = "10.11.0"
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/hvk8s/config.ps1"

[string] $isoPath = "$($global:rs.Config::IsoDir)/preseed-hvk8s-debian-${debianVersion}-amd64-netinst.iso"

[object] $scriptArgs = @{}
$MyInvocation.MyCommand.Parameters.Keys |
    Where-Object { [System.Management.Automation.PSCmdlet]::CommonParameters -notcontains $_ } |
    Where-Object { $_ -ne 'vmMemoryMB' } |
    ForEach-Object { $scriptArgs[$_] = (Get-Variable -Name $_).Value } | Out-Null

$scriptArgs.vmMemory = $global:rs.Config::Memory.Template.Linux.Calculate($vmMemoryMB) | ConvertTo-Json -Compress

&"${PSScriptRoot}/scripts/hvk8s/build-k8s-vm-template.ps1" @scriptArgs -isoPath $isoPath