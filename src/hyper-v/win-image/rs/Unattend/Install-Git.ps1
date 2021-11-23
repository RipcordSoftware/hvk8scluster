#Requires -RunAsAdministrator

param (
    [string] $gitVersion = '2.33.1'
)

$ErrorActionPreference = 'Stop'

[string] $gitPath = "${env:SystemDrive}\Program Files\Git\bin\git.exe"
if (!(Test-Path $gitPath)) {
    Start-Process -Wait "${PSScriptRoot}\bin\Git-${gitVersion}-64-bit.exe" -ArgumentList @('/verysilent', '/norestart')
}