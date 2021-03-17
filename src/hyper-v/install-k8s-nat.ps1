#Requires -RunAsAdministrator

param (
    [string] $switchName = "Kubernetes",
    [string] $natName = "${switchName}-nat"
)

$ErrorActionPreference = "Stop"

. ./scripts/config.ps1
. ./scripts/vm.ps1

if (![Vm]::IsInstalled()) {
    Write-Error "Hyper-V is not installed or the service isn't running, please install manually or using the provided scripts"
}

if (![Vm]::IsAdministrator()) {
    Write-Error "You require Administrator rights or membership of the 'Hyper-V Administrator' group"
}

[string] $ipGateway = [Config]::Vm.Gateway.Ip
[string] $ipNetwork = $ipGateway -replace '[0-9]+$','0/24'

New-VMSwitch -SwitchName $switchName -SwitchType Internal

[object] $adapter = Get-NetAdapter | Where-Object { $_.name.contains($switchName) }

New-NetIPAddress -IPAddress $ipGateway -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $ipNetwork
