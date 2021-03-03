param (
    [string] $vmName = "k8s-template",
    [int] $vmCpuCount = 2,
    [int] $vmMemoryMB = 768,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $removeVmTemplate,
    [string] $debianVersion = "10.8.0"
)

$ErrorActionPreference = "Stop"

. ./scripts/vm.ps1
. ./scripts/config.ps1
. ./scripts/ssh.ps1

# check the preseed image is available
[string] $isoPath = "$([Config]::IsoPath)/preseed-k8s-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $isoPath)) {
    Write-Error "The ISO image '$isoPath' is missing, please build it before proceeding"
}

# check the DHCP server is available
[object] $dhcpServer = [Vm]::GetVM([Config]::Vm.Dhcp.Name)
if (!$dhcpServer -or ![Ssh]::TestSsh([Config]::Vm.Dhcp.Ip)) {
    Write-Error "Unable to find the DHCP/DNS server, is it running?"
}

# create the VM
[Vm]::Create($vmName, $isoPath, $vmCpuCount, $vmMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $false) | Out-Null

# wait for the VM to come up
Write-Host "Waiting for VM IP address for '${vmName}'..."
[string] $ip = [Vm]::WaitForIpv4($vmName, $true)

# wait for the SSH daemon to start
Write-Host "Waiting for active SSH on '${ip}'..."
[Ssh]::WaitForSsh($ip, $true)

# stop the VM and export it
Write-Host "Stopping the template VM..."
Stop-Vm -Name $vmName
Set-Vm -Name $vmName -AutomaticStartAction Nothing

# export the VM to the template path
Write-Host "Exporting the template VM..."
[Vm]::Export($vmName, $removeVmTemplate)
