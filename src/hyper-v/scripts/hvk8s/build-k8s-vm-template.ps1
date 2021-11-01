param (
    [string] $vmName = "hvk8s-template",
    [int] $vmCpuCount = 2,
    [int] $vmMemoryMB = 768,
    [int] $vmDiskSizeGB = 40,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [switch] $skipVmProvisioning,
    [switch] $removeVmTemplate,
    [Parameter(Mandatory)][string] $isoPath,
    [Parameter(ValueFromRemainingArguments)][string] $ignoredArguments
)

$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/config.ps1"
. "${PSScriptRoot}/../modules/vm.ps1"
. "${PSScriptRoot}/../modules/ssh.ps1"
. "${PSScriptRoot}/../modules/backgroundprocess.ps1"

# give the background processes access to the app args
$global:rs.BackgroundProcess::SetInitialVars($MyInvocation)

if (!$skipVmProvisioning) {
    # check the preseed image is available
    if (!(Test-Path $isoPath)) {
        Write-Error "The ISO image '${isoPath}' is missing, please build it before proceeding"
    }

    # check the DHCP server is available
    $global:rs.BackgroundProcess::SpinWait("Checking the DHCP server is available...", {
        [object] $dhcpServer = $global:rs.Vm::GetVM($global:rs.Config::Vm.Dhcp.Name)
        if (!$dhcpServer -or !$global:rs.Ssh::TestSsh($global:rs.Config::Vm.Dhcp.Ip)) {
            Write-Error "Unable to find the DHCP/DNS server, is it running?"
        }
    })

    # create the VM
    $global:rs.BackgroundProcess::SpinWait("Creating the virtual machine...", { param ($isoPath)
        $global:rs.Vm::Create($vmName, $isoPath, $vmCpuCount, $vmMemoryMB, $vmDiskSizeGB, $vmSwitch, $removeVhd, $removeVm, $false) | Out-Null
    }, @{ isoPath = $isoPath })

    # wait for the VM to come up
    [string] $ip = $global:rs.BackgroundProcess::SpinWait("Waiting for VM IP address for '${vmName}'...", {
        return $global:rs.Vm::WaitForIpv4($vmName, $false)
    })

    # wait for the SSH daemon to start
    $global:rs.BackgroundProcess::SpinWait("Waiting for active SSH on '${ip}'...", { param ($ip)
        $global:rs.Ssh::WaitForSsh($ip, $false)
    }, @{ ip = $ip })
}

# stop the VM
$global:rs.BackgroundProcess::SpinWait("Stopping the template VM...", {
    Stop-Vm -Name $vmName
})

# export the VM to the template path
$global:rs.BackgroundProcess::SpinWait("Exporting the template VM...", {
    $global:rs.Vm::EjectIsoMedia($vmName)
    $global:rs.Vm::Export($vmName, $global:rs.Config::ExportDir, $removeVmTemplate)
})

# set the template vm to not start on boot
Set-Vm -Name $vmName -AutomaticStartAction Nothing
