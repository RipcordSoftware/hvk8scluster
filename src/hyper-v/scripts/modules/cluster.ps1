$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/ssh.ps1"

if (!$global:rs) {
    $global:rs = @{}
}

&{
    class Cluster {
        static [void] InitializeMaster([string] $ip, [string] $user, [string] $privateKeyPath) {
            [string] $command =
                'if [ ! -d .kube ]; then ' +
                ' sudo kubeadm init --pod-network-cidr=172.30.0.0/16 && ' +
                ' mkdir -p $HOME/.kube && ' +
                ' sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && ' +
                ' sudo chown $(id -u):$(id -g) $HOME/.kube/config; ' +
                'fi'
                $global:rs.Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
        }

        static [string] GetJoinCommand([string] $ip, [string] $user, [string] $privateKeyPath) {
            [string] $command = "kubeadm token create --print-join-command"
            [string] $joinCmd = $global:rs.Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
            $joinCmd = $joinCmd -replace '\s*$', ""
            return $joinCmd
        }

        static [void] Join([string] $ip, [string] $command, [string] $user, [string] $privateKeyPath) {
            $global:rs.Ssh::InvokeRemoteCommand($ip, "if [ ! -f /etc/kubernetes/kubelet.conf ]; then sudo ${command}; fi", $user, $privateKeyPath)
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
            $global:rs.Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
        }

        static [void] InitializeFlannel([string] $ip, [string] $user, [string] $privateKeyPath) {
            [string] $command =
                'wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml -O kube-flannel.yml && ' +
                "sed -i 's/10.244.0.0/172.30.0.0/' kube-flannel.yml && " +
                'kubectl apply -f kube-flannel.yml'
            $global:rs.Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
        }

        static [void] SetHostName([string] $ip, [string] $hostName, [string] $user, [string] $privateKeyPath) {
            [string] $command =
                'if [ "$(hostname)" != ' + "'${hostName}' ]; then " +
                " sudo sed -i 's/hvk8s-unknown/${hostName}/g' /etc/hosts && " +
                " sudo sed -i 's/hvk8s-unknown/${hostName}/g' /etc/hostname && " +
                " sudo rm -f /var/lib/dhcp/*.leases && " +
                " sudo systemctl reboot --no-block; " +
                "fi"

            $global:rs.Ssh::InvokeRemoteCommand($ip, $command, $user, $privateKeyPath)
        }

        static [string] GetClusterConfig([string] $ip, [string] $user, [string] $privateKeyPath) {
            return $global:rs.Ssh::InvokeRemoteCommand($ip, "cat ~/.kube/config", $user, $privateKeyPath)
        }

        static [void] SaveClusterConfig([string] $path, [bool] $force, [string] $ip, [string] $user, [string] $privateKeyPath) {
            [string] $conf = [Cluster]::GetClusterConfig($ip, $user, $privateKeyPath)

            if (!$path) {
                New-Item -Path "~/.kube" -ItemType Directory -Force
                $path = '~/.kube/config'
            }

            [object] $outArgs = @{ Encoding = 'ascii'; FilePath = $path }
            if (!$force) {
                $outArgs.NoClobber = $true
            }
            $conf | Out-File @outArgs
        }
    }

    $global:rs.Cluster = &{ [Cluster] }
}
