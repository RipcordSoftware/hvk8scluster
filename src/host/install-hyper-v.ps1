#Requires -RunAsAdministrator

param (
    [switch] $disableGroupAdd,
    [switch] $disableRestart
)

$ErrorActionPreference = 'Stop'

if ((Get-ComputerInfo).OsProductType -eq "Server") {
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
} else {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
}

if (!$disableGroupAdd) {
    [object] $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    [object] $groupMembers = Get-LocalGroupMember -Name "Hyper-V Administrators"
    [bool] $isMember = $groupMembers | Where-Object { $_.Name -eq $user.Name }
    if (!$isMember) {
        Add-LocalGroupMember -Group "Hyper-v Administrators" -Member $user.Name
    }
}

if (!$disableRestart) {
    Write-Host "Restarting computer in 10s, press CTRL+C abort..."
    Start-Sleep 10
    Restart-Computer -Force
}
