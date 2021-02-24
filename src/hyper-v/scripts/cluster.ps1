$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/ssh.ps1"

class Cluster {
    static [void] InitializeMaster([string] $ip, [string] $user, [string] $privateKeyPath) {
        [string] $command =
            'if [ ! -d .kube ]; then ' +
            ' sudo kubeadm init --pod-network-cidr=172.30.0.0/16 && ' +
            ' mkdir -p $HOME/.kube && ' +
            ' sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && ' +
            ' sudo chown $(id -u):$(id -g) $HOME/.kube/config; ' +
            'fi'
        $script:Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
    }

    static [string] GetJoinCommand([string] $ip, [string] $user, [string] $privateKeyPath) {
        [string] $command = "kubeadm token create --print-join-command"
        [string] $joinCmd = $script:Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
        $joinCmd = $joinCmd -replace '\s*$', ""
        return $joinCmd
    }

    static [void] Join([string] $ip, [string] $command, [string] $user, [string] $privateKeyPath) {
        $script:Ssh::InvokeRemoteCommand($_.ip, "if [ ! -f /etc/kubernetes/kubelet.conf ]; then sudo ${command}; fi", $user, $privateKeyPath)
    }

    static [void] InitializeCalico([string] $ip, [string] $user, [string] $privateKeyPath) {
        [string] $command =
            'wget https://docs.projectcalico.org/v3.17/manifests/calico.yaml -O calico.yaml && ' +
            "sed -i 's/192.168.0.0/172.30.0.0/' calico.yaml && " +
            'kubectl apply -f calico.yaml && ' +
            'if [ ! -f /usr/local/bin/calicoctl ]; then ' +
            ' wget https://github.com/projectcalico/calicoctl/releases/download/v3.17.3/calicoctl -O calicoctl && ' +
            ' chmod a+x calicoctl && ' +
            ' sudo mv -f calicoctl /usr/local/bin/; fi'
        $script:Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
    }

    static [void] SetHostName([string] $ip, [string] $hostName, [string] $user, [string] $privateKeyPath) {
        [string] $command =
            'if [ "$(hostname)" != ' + "'${hostName}' ]; then " +
            " sudo sed -i 's/k8s-unknown/${hostName}/g' /etc/hosts && " +
            " sudo sed -i 's/k8s-unknown/${hostName}/g' /etc/hostname && " +
            " sudo rm -f /var/lib/dhcp/*.leases && " +
            " sudo systemctl reboot --no-block; " +
            "fi"

        $script:Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
    }
}
