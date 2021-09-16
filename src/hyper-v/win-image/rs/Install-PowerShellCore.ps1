#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

Start-Process -Wait 'msiexec.exe' -ArgumentList @('/i', "${PSScriptRoot}\bin\PowerShell-7.1.4-win-x64.msi", '/passive', '/norestart')