# Run a Kubernetes cluster on Hyper-V
Assuming you have Hyper-V and Ubuntu/WSL installed you can now create a cluster on your computer.

## Preseed Images
The Linux OS hosting this Kubernetes cluster is Debian. In order to provision the cluster we must first create custom ISO files based on images downloaded from Debian.
The `debian-image` directory contains the `build.sh` script and `preseed` configuration files which will create two custom images:
* `preseed-dhcp-dns.cfg` - defines an image with a pre-configured DHCP/DNS server (dnsmasq) and a range of fixed IP addresses for the nodes
* `preseed-k8s.cfg` - defines an image with Docker, kubeadm and associated tools installed, this will become control plane and worker node VMs

The preseed images are created by running the build script in Ubuntu (under WSL) as follows:
```sh
./build.sh preseed-dhcp-dns.cfg
./build.sh preseed-k8s.cfg
```

> When you open Ubuntu you will need to change the working directory to the Windows directory where this repository is cloned.
> The Windows file system is mapped into the Ubuntu file system under the path `/mnt/c/`, from there you can navigate to the
> correct repository directory.

## Hyper-V Switch
The Kubernetes nodes require a dedicated [subnet](https://docs.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/create-a-virtual-switch-for-hyper-v-virtual-machines) 
in Hyper-V. The script `install-k8s-nat.ps1` will create the switch and the network. The script should be run as an administrator.

## SSH Keys
The Linux VMs require ssh keys during the creation process, these should be created from a Windows terminal by executing `ssh-keygen` and accepting the defaults. You should 
now have public and private key files in the `.ssh` directory under your home directory.

## DHCP/DNS VM
The first VM that should be created is the DHCP/DNS VM, run the `install-dhcp-dns-vm.ps1` script as Administrator. This VM manages the control and node IP addresses of the cluster.

## Cluster
The `install-k8s-cluster.ps1` script creates the Kubernetes cluster. It requires both the switch and DHCP/DNS scripts to have run successfully. The script will take at least 10 minutes to run.

### Authentication
Your ssh keys can be used to access the nodes directly, for example, from your Windows host, `ssh hvk8s@172.31.0.10` will start a session on the master control plane node. You can 
recover the cluster config file from the master node by executing `cat ~/.kube/config`, in one step this would be:

```sh
ssh hvk8s@172.31.0.10 cat ./.kube/config
```

You can use the copied configuration information to run `kubectl` or other tools like Lens.
