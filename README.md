# Hyper-V Kubernetes Cluster (hvk8scluster)
Run a true multi-node multi-OS Kubernetes cluster on your Windows workstation

## Features
* Up to 10 Linux and/or 10 Windows nodes
* Networking with [Flannel][flannel] or [Calico][calico]
* Block, object and file storage by [Rook/Ceph][rook]
* Load Balancer by [MetalLB][metallb]
* Ingress by [nginx][nginx]

## Requires
* Windows 10 or Windows Server 2019 with at least 16GB RAM and 100GB+ disk space
* Administrator access
* PowerShell
* Hyper-V capable of running VMs
* [WSL1][wsl] with Ubuntu

## Instructions
You must prepare your [host][hvk8scluster-prerequisites] computer and then run the [Hyper-V][hvk8scluster-hyper-v] scripts to add the cluster VMs

## Useful Tools
* [Visual Studio Code][vscode]
* [Windows Terminal][windows-terminal]
* [Lens][lens]

[vscode]:https://code.visualstudio.com/
[windows-terminal]:https://github.com/microsoft/terminal/releases
[lens]:https://k8slens.dev/
[calico]:https://docs.projectcalico.org/getting-started/kubernetes/
[flannel]:https://github.com/flannel-io/flannel
[metallb]:https://metallb.universe.tf/
[rook]:https://rook.io/
[nginx]:https://github.com/kubernetes/ingress-nginx
[wsl]:https://docs.microsoft.com/en-us/windows/wsl/
[hvk8scluster-prerequisites]:https://github.com/RipcordSoftware/hvk8scluster/wiki/Prerequisites
[hvk8scluster-hyper-v]:https://github.com/RipcordSoftware/hvk8scluster/wiki/Building