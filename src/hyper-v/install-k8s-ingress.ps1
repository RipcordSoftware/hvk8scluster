param (
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [switch] $ignoreKeyPermissions
)

$ErrorActionPreference = "Stop"

. ./scripts/config.ps1
. ./scripts/ssh.ps1

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = [Ssh]::DiscoverPrivateKeyPath([Config]::RepoRoot)
}

# check the read/write permissions on the private key file
if (!$ignoreKeyPermissions -and ![Ssh]::CheckKeyFilePermissions($sshPrivateKeyPath)) {
    Write-Error "The permissions on the private key file '$sshPrivateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

Write-Host "Installing ingress-nginx..."
[Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, './remote-commands/install-ingress-nginx-chart.sh', $sshUser, $sshPrivateKeyPath)
