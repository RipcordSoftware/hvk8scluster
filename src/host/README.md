# Windows Host Configuration
Scripts in this directory can be used to configure your Windows host computer to run Kubernetes under Hyper-V.

## Requirements
* Hyper-V capable of running virtual machines
* WSL with Ubuntu
* PowerShell enabled to run scripts from this repository, for example: `Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser`

## Scripts
Run the following scripts under Powershell in Administrator mode:
* `install-hyper-v.ps1` - installs Hyper-V (requires restart)
* `install-wsl.ps1` - installs WSL (Windows Subsystem for Linux)
* `install-ubuntu.ps1` - installs Ubuntu to run under WSL

The following script should be run in an Ubuntu console session after it is installed:
* `install-ubuntu-tools.sh`

> You may have installed git with `autocrlf` enabled, in this case scripts on Ubuntu may fail since they have been modified.
> Change your setting with `git config core.autocrlf input` to prevent this problem. You will need to re-clone the repository.
