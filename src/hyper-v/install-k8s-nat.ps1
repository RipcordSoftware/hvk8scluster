param (
    [string] $switchName = "Kubernetes",
    [string] $natName = "${switchName}-nat"
)

$ErrorActionPreference = "Stop"

. ./scripts/config.ps1

[string] $ipGateway = [Config]::Vm.Gateway.Ip
[string] $ipNetwork = $ipGateway -replace '[0-9]+$','0/24'

New-VMSwitch -SwitchName $switchName -SwitchType Internal

[object] $adapter = Get-NetAdapter | Where-Object { $_.name.contains($switchName) }

New-NetIPAddress -IPAddress $ipGateway -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $ipNetwork
