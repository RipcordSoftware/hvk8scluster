# Hyper-V Kubernetes Cluster (hvk8scluster)
Creates a multi-node Kubernetes cluster on a single Hyper-V instance

## Requires
* Windows 10 or Windows Server 2019 with at least 16GB RAM and 100GB+ disk space
* Administrator access
* PowerShell
* Hyper-V capable of running VMs
* WSL with Ubuntu

## Useful Tools
* [Visual Studio Code](https://code.visualstudio.com/)
* [Windows Terminal](https://github.com/microsoft/terminal/releases)
* [Lens](https://k8slens.dev/)

## Instructions
You must prepare your [host](./src/host/README.md) computer and then run the [Hyper-V](./src/hyper-v/README.md) scripts to add the cluster VMs.
