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
