param (
    [Parameter(Position=0)][string] $command = "help",
    [string] $sshUser = "hvk8s",
    [string] $sshPrivateKeyPath,
    [Parameter(ValueFromRemainingArguments)][object] $commandArguments
)

$ErrorActionPreference = "Stop"

. ./scripts/ssh.ps1
. ./scripts/config.ps1
. ./scripts/cluster.ps1
. ./scripts/arguments.ps1

if (!$sshPrivateKeyPath) {
    $sshPrivateKeyPath = [Ssh]::DiscoverPrivateKeyPath([Config]::RepoRoot)
}

switch ($command) {
    "config" {
        [object] $options = [Arguments]::GetLongOptions($commandArguments)
        if ($options.out) {
            [Cluster]::SaveClusterConfig($options.path, $options.force, [Config]::Vm.Master.Ip, $sshUser, $sshPrivateKeyPath)
        } else {
            [string] $output = [Cluster]::GetClusterConfig([Config]::Vm.Master.Ip, $sshUser, $sshPrivateKeyPath)
            Write-Host $output
        }
    }
    "kubectl" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubectl ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "kubeadm" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubeadm ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "helm" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "helm ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "calicoctl" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "sudo calicoctl ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "ceph" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "rados" { [Ssh]::InvokeRemoteCommand([Config]::Vm.Master.Ip, "kubectl -n rook-ceph exec deploy/rook-ceph-tools -- rados ${commandArguments}", $sshUser, $sshPrivateKeyPath) }
    "help" {
        Write-Host "hvk8sctl - Hyper-V Kuberenetes Control"
        Write-Host ""
        Write-Host "usage: command [arguments]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host " config      outputs the cluster configuration to the console or file"
        Write-Host " kubectl     runs kubectl on the master node, pass --help to get list of arguments"
        Write-Host " kubeadm     runs kubeadm on the master node, pass --help to get list of arguments"
        Write-Host " helm        runs helm on the master node, pass --help to get list of arguments"
        Write-Host " calicoctl   runs calicoctl on the master node, pass --help to get list of arguments"
        Write-Host " ceph        runs ceph on the master node, pass --help to get list of arguments"
        Write-Host " rados       runs rados on the master node, pass --help to get list of arguments"
        Write-Host ""
        Write-Host "Flags:"
        Write-Host " config      --out        write the cluster config to file, defaults to ~/.kube/config"
        Write-Host "             --force      overwrite the existing file"
        Write-Host "             --path       specify an alternate file name"
    }
}