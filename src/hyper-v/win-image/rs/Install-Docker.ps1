#Requires -RunAsAdministrator

param (
    [switch] $reboot
)

$ErrorActionPreference = 'Stop'

[object] $serviceInstalled = !!(Get-Service | Where-Object { $_.name -eq 'docker' })

if (!$serviceInstalled) {
    Install-PackageProvider -Name NuGet -Force
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
    Install-Package -Name Docker -ProviderName DockerMsftProvider -Force

    if ($reboot) {
        Restart-Computer -Force
    }
}
