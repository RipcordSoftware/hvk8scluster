param (
    [string] $vmName = "hvk8s-win-template",
    [int] $vmCpuCount = 2,
    [int] $vmMemoryMB = 1024,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $skipVmProvisioning,
    [switch] $removeVmTemplate,
    [string] $winVersion = '20h2_updated_march_2021_x64_dvd_0ccc98b9'
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/hvk8s/config.ps1"

[string] $isoPath = "$($global:rs.Config::IsoDir)/en_windows_server_version_${winVersion}.iso"

[object] $scriptArgs = @{}
$MyInvocation.MyCommand.Parameters.Keys |
    Where-Object { [System.Management.Automation.PSCmdlet]::CommonParameters -notcontains $_ } |
    ForEach-Object { $scriptArgs[$_] = (Get-Variable -Name $_).Value } | Out-Null

&"${PSScriptRoot}/scripts/hvk8s/build-k8s-vm-template.ps1" @scriptArgs -isoPath $isoPath
