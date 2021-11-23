param (
    [string] $vmName = "hvk8s-template",
    [int] $vmCpuCount = 2,
    [int] $vmMemoryMB = 768,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $skipVmProvisioning,
    [switch] $removeVmTemplate,
    [string] $debianVersion = "10.8.0"
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/hvk8s/config.ps1"

[string] $isoPath = "$($global:rs.Config::IsoDir)/preseed-hvk8s-debian-${debianVersion}-amd64-netinst.iso"

[object] $scriptArgs = @{}
$MyInvocation.MyCommand.Parameters.Keys |
    Where-Object { [System.Management.Automation.PSCmdlet]::CommonParameters -notcontains $_ } |
    ForEach-Object { $scriptArgs[$_] = (Get-Variable -Name $_).Value } | Out-Null

&"${PSScriptRoot}/scripts/hvk8s/build-k8s-vm-template.ps1" @scriptArgs -isoPath $isoPath