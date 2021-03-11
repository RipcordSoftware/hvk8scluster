#Requires -RunAsAdministrator

param (
    [switch] $disableRestart
)

$ErrorActionPreference = 'Stop'

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

if (!$disableRestart) {
    Write-Host "Restarting computer in 10s, press CTRL+C to abort..."
    Start-Sleep 10
    Restart-Computer -Force
}
