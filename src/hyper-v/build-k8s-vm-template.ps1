param (
    [string] $vmName = "k8s-template",
    [int] $vmCpuCount = 2,
    [int] $vmMinMemoryMB = 1024,
    [int] $vmMaxMemoryMB = 2048,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $removeTemplate,
    [string] $debianVersion = "10.7.0"
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
[object] $dhcpServer = [Vm]::GetVM("k8s-dhcp-dns")
if (!$dhcpServer -or ![Ssh]::TestSsh("172.31.0.2")) {
    Write-Error "Unable to find the DHCP/DNS server, is it running?"
}

# create the VM
[Vm]::Create($vmName, $isoPath, $vmCpuCount, $vmMinMemoryMB, $vmMaxMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $false) | Out-Null

# wait for the VM to come up
Write-Host "Waiting for VM IP address for '${vmName}'..."
[string] $ip = [Vm]::WaitForIpv4($vmName, $true)

# wait for the SSH daemon to start
Write-Host "Waiting for active SSH on '${ip}'..."
[Ssh]::WaitForSsh($ip, $true)

# stop the VM and export it
Write-Host "Stopping the template VM..."
Stop-Vm -Name $vmName

# remove the old template file
[string] $templatePath = "$([Config]::ExportPath)/${vmName}"
if ($removeTemplate -and (Test-Path -Path $templatePath)) {
    Remove-Item -Path $templatePath -Recurse -Force -ErrorAction SilentlyContinue
}

# export the VM to the template path
Write-Host "Exporting the template VM..."
Export-Vm -Name $vmName -Path $([Config]::ExportPath)
