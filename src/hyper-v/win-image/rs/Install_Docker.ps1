param (
    [switch] $reboot
)

$ErrorActionPreference = 'Stop'

Install-PackageProvider -Name "NuGet" -Force
Install-Module DockerMsftProvider -Force
Install-Package Docker -ProviderName DockerMsftProvider -Force

if ($reboot) {
    Restart-Computer -Force
}