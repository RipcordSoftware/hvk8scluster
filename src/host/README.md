# Windows Host Configuration
Scripts in this directory can be used to configure your Windows host computer to run Kubernetes under Hyper-V.

## Requirements
* Hyper-V capable of running virtual machines
* WSL with Ubuntu

## Scripts
Run the following scripts under Powershell in Administrator mode:
* `install-hyper-v.ps1` - installs Hyper-V (requires restart)
* `install-wsl.ps1` - installs WSL (Windows Subsystem for Linux)
* `install-ubuntu.ps1` - installs Ubuntu to run under WSL

The following script should be run in an Ubuntu console session after it is installed:
* `install-ubuntu-tools.sh`
