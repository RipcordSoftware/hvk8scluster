#Requires -RunAsAdministrator

param (
    [switch] $reboot,
    [string] $dockerVersion = '19.03.18'
)

$ErrorActionPreference = 'Stop'

try {
    [object] $service = Get-Service -Name 'docker' -ErrorAction Ignore
    if (!$service) {
        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
        Install-Package -Name Docker -ProviderName DockerMsftProvider -Force -RequiredVersion $dockerVersion

        if ($reboot) {
            Restart-Computer -Force
        }
    }
} catch {
    $_ | Out-File "${PSCommandPath}.log"
    throw
}