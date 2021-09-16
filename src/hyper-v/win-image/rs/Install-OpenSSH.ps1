#Requires -RunAsAdministrator

param (
    [switch] $reboot
)

$ErrorActionPreference = 'Stop'

[object] $serviceInstalled = !!(Get-Service | Where-Object { $_.name -eq 'sshd' })

if (!$serviceInstalled) {
    Write-Host 'Install OpenSSH.Server...'
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

    Write-Host 'Set the default SSH shell...'
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force

    Write-Host 'Set the services to automatic start...'
    Set-Service sshd -StartupType Automatic
    Set-Service ssh-agent -StartupType Automatic

    Start-Service sshd

    if ($reboot) {
        Restart-Computer -Force
    }
}