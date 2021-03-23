#Requires -RunAsAdministrator

param (
    [string] $switchName = "Kubernetes",
    [string] $natName = "${switchName}-nat",
    [switch] $reset
)

$ErrorActionPreference = "Stop"

. ./scripts/config.ps1
. ./scripts/vm.ps1
. ./scripts/backgroundprocess.ps1

if (!$global:rs.Vm::IsInstalled()) {
    Write-Error "Hyper-V is not installed or the service isn't running, please install manually or using the provided scripts"
}

# give the background processes access to the app args
$global:rs.BackgroundProcess::SetInitialVars($MyInvocation)

[string] $ipGateway = $global:rs.Config::Vm.Gateway.Ip
[string] $ipNetwork = $ipGateway -replace '[0-9]+$','0/24'

if ($reset) {
    Remove-NetNat -Name $natName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetIPAddress -IPAddress $ipGateway -Confirm:$false -ErrorAction SilentlyContinue
    Remove-VMSwitch -SwitchName $switchName -Force -ErrorAction SilentlyContinue
}

$global:rs.BackgroundProcess::SpinWait("Adding a new network switch to Hyper-V...", {
    New-VMSwitch -SwitchName $switchName -SwitchType Internal | Out-Null
})

$global:rs.BackgroundProcess::SpinWait("Adding a new network adapter to the switch...", { param ($ipGateway)
    [object] $adapter = Get-NetAdapter | Where-Object { $_.name.contains($switchName) }
    New-NetIPAddress -IPAddress $ipGateway -PrefixLength 24 -InterfaceIndex $adapter.ifIndex | Out-Null
}, @{ ipGateway = $ipGateway })

$global:rs.BackgroundProcess::SpinWait("Enabling NAT on the new virtual network...", { param ($ipNetwork)
    New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $ipNetwork | Out-Null
}, @{ ipNetwork = $ipNetwork })
