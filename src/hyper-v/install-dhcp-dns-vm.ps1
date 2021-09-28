param (
    [string] $vmName = "hvk8s-dhcp-dns",
    [string] $vmIp = "172.31.0.2",
    [int] $vmCpuCount = 2,
    [int64] $vmMemoryMB = 768,
    [int64] $vmDiskSizeGB = 4,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $updateVm,
    [string] $debianVersion = "10.8.0"
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/scripts/modules/vm.ps1"
. "${PSScriptRoot}/scripts/hvk8s/config.ps1"
. "${PSScriptRoot}/scripts/modules/ssh.ps1"
. "${PSScriptRoot}/scripts/modules/backgroundprocess.ps1"

if (!$global:rs.Vm::IsInstalled()) {
    Write-Error "Hyper-V is not installed or the service isn't running, please install manually or using the provided scripts"
}

if (!$global:rs.Vm::IsAdministrator()) {
    Write-Error "You require Administrator rights or membership of the 'Hyper-V Administrator' group"
}

[string] $isoPath = "$($global:rs.Config::IsoDir)/preseed-dhcp-dns-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $isoPath)) {
    Write-Error "The ISO image '${isoPath}' is missing, please build it before proceeding"
}

# give the background processes access to the app args
$global:rs.BackgroundProcess::SetInitialVars($MyInvocation)

[bool] $created = [bool]$global:rs.BackgroundProcess::SpinWait("Creating the virtual machine...", { param ($isoPath)
    return $global:rs.Vm::Create($vmName, $isoPath, $vmCpuCount, $vmMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $updateVm)
}, @{ isoPath = $isoPath })

if ($created) {
    # if we created a new VM then remove any old host keys
    if ($vmIp) {
        $global:rs.Ssh::RemoveHostKeys($vmIp)
    }

    # wait for the VM to fully come up
    $global:rs.BackgroundProcess::SpinWait("Waiting for active SSH on '${vmIp}'...", { param ($vmIp)
        $global:rs.Ssh::WaitForSsh($vmIp, $false)
    }, @{ vmIp = $vmIp })
}
