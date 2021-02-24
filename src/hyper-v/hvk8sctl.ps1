param (
    [Parameter(Mandatory = $true, Position=0)][string] $command,
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [Parameter(ValueFromRemainingArguments)][string] $commandArguments
)

$ErrorActionPreference = "Stop"

. ./scripts/ssh.ps1
. ./scripts/config.ps1

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = [Ssh]::DiscoverPrivateKeyPath([Config]::RepoRoot)
}

switch ($command) {
    "config" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "cat ~/.kube/config", $sshUser, $sshPrivateKeyPath) }
    "kubectl" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubectl ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "kubeadm" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubeadm ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "helm" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "helm ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "calicoctl" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "sudo calicoctl ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "ceph" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "rados" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubectl -n rook-ceph exec deploy/rook-ceph-tools -- rados ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
}