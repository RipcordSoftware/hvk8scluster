param (
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [switch] $ignoreKeyPermissions
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/config.ps1"
. "${PSScriptRoot}/scripts/ssh.ps1"
. "${PSScriptRoot}/scripts/backgroundprocess.ps1"

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = $global:rs.Ssh::DiscoverPrivateKeyPath($global:rs.Config::RepoRoot)
}

# check the read/write permissions on the private key file
if (!$ignoreKeyPermissions -and !$global:rs.Ssh::CheckKeyFilePermissions($sshPrivateKeyPath)) {
    Write-Error "The permissions on the private key file '$sshPrivateKeyPath' are too open, OpenSSH requires these are limited to the current user only. Alternately specify -ignoreKeyPermissions on the command line."
}

# give the background processes access to the app args
$global:rs.BackgroundProcess::SetInitialVars($MyInvocation)

# install the chart
$global:rs.BackgroundProcess::SpinWait("Installing ingress-nginx...", {
    $global:rs.Ssh::InvokeRemoteCommand($global:rs.Config::Vm.Master.Ip, './remote-commands/install-ingress-nginx-chart.sh', $sshUser, $sshPrivateKeyPath)
})
