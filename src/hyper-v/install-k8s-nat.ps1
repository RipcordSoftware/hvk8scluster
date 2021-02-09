[string] $switchName = "Kubernetes"
[string] $natName = "${switchName}-nat"

New-VMSwitch -SwitchName $switchName -SwitchType Internal

[object] $adapter = Get-NetAdapter | Where-Object { $_.name.contains($switchName)}

New-NetIPAddress -IPAddress "172.31.0.1" -PrefixLength 24 -InterfaceIndex $adapter.ifIndex

New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix 172.31.0.0/24