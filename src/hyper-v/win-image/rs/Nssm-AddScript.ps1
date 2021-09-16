#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory)][string] $serviceName,
    [Parameter(Mandatory)][string] $scriptPath,
    [Parameter(ValueFromRemainingArguments=$true)][string[]] $scriptArgs
)

$ErrorActionPreference = 'Stop'

[string] $nssmPath = "${PSScriptRoot}\bin\nssm-2.24-101-g897c7ad\win64\nssm.exe"

[string] $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
[string] $powershellCorePath = "$env:SystemDrive\Program Files\PowerShell\7\pwsh.exe"
if (Test-Path $powershellCorePath) {
    $powershell = $powershellCorePath
}

& $nssmPath install $serviceName $powershell -NoProfile -NonInteractive -ExecutionPolicy Unrestricted -NoExit -OutputFormat Text -File $scriptPath $scriptArgs
if (!$?) {
    Write-Error "Nssm failed to install the service '${serviceName}'"
}

Set-Service $serviceName -StartupType Automatic