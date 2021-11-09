#Requires -RunAsAdministrator

param (
    [string] $powerShellVersion = '7.1.5'
)

$ErrorActionPreference = 'Stop'

[string] $powershellCorePath = "${env:SystemDrive}\Program Files\PowerShell\7\pwsh.exe"
if (!(Test-Path $powershellCorePath)) {
    Start-Process -Wait 'msiexec.exe' -ArgumentList @('/i', "${PSScriptRoot}\bin\PowerShell-${powerShellVersion}-win-x64.msi", '/passive', '/norestart')
}