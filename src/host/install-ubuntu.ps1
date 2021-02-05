$version = '1804'

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-${version} -OutFile ~\Downloads\Ubuntu-${version}.appx -UseBasicParsing
Add-AppxPackage ~\Downloads\Ubuntu-${version}.appx