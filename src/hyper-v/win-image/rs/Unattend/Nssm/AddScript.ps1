#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory)][string] $command,
    [Parameter(ValueFromRemainingArguments=$true)][string[]] $arguments,
    [switch] $disableNssmInstall
)

$ErrorActionPreference = 'Stop'

[string] $nssmMajorVersion = '2.24'
[string] $nssmMinorVersion = '101-g897c7ad'
[string] $nssmPath = "${PSScriptRoot}\..\bin\nssm-${nssmMajorVersion}-${nssmMinorVersion}\win64\nssm.exe"
[string] $nssmInstallDir = "${env:ProgramFiles}\nssm-${nssmMajorVersion}"

# install Nssm to Program Files
if (!$disableNssmInstall -and !(Test-Path $nssmInstallDir)) {
    New-Item -Path $nssmInstallDir -ItemType Directory
    Copy-Item -Path $nssmPath -Destination $nssmInstallDir
    $nssmPath = "${nssmInstallDir}\nssm.exe"
}

[string] $powershell = "${env:SystemRoot}\System32\WindowsPowerShell\v1.0\powershell.exe"
[string] $powershellCorePath = "${env:SystemDrive}\Program Files\PowerShell\7\pwsh.exe"
if (Test-Path $powershellCorePath) {
    $powershell = $powershellCorePath
}

[object] $service = Get-Service -Name 'install-scripts' -ErrorAction Ignore
if (!$service) {
    &$nssmPath install install-scripts """${powershell}""" -NoProfile -NonInteractive -ExecutionPolicy Unrestricted `
        -NoExit -OutputFormat Text -File """${PSScriptRoot}\Nssm.ps1"""

    if (!$?) {
        Write-Error "Nssm failed to install the service 'install-scripts'"
    }
}

[object] $script = @{ command = $command; arguments = $arguments }

# append the script to the scripts file
$script | ConvertTo-Json -Compress | Out-File "${PSScriptRoot}\Nssm.dat" -Append -Force -Encoding ascii