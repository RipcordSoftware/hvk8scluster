$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/../modules/git.ps1"

if (!$global:rs) {
    $global:rs = @{}
    $global:rs.__modules = @()
}

&{
    enum ClusterNodeType {
        Linux
        Windows
    }

    class Config {
        static [string] $RepoRoot = $global:rs.Git::RepoRoot

        static [string] $BinDir = "$([Config]::RepoRoot)/bin"
        static [string] $SrcDir = "$([Config]::RepoRoot)/src"

        static [string] $IsoDir = "$([Config]::BinDir)/isos"
        static [string] $ExportDir = "$([Config]::BinDir)/exports"
        static [string] $KeyDir = "$([Config]::SrcDir)/keys"

        static [object] $Network = @{
            subnetPrefix = '172.31.0'
        }

        static [int] $MaxLinuxNodes = 10
        static [int] $MaxWindowsNodes = 10
        static [int] $MaxNodes = [Config]::MaxLinuxNodes + [Config]::MaxWindowsNodes

        static [object] $Vm = @{
            Gateway = @{ Name = "hvk8s-gateway"; Ip = "$([Config]::Network.subnetPrefix).1" }  # the Hyper-V gateway/vswitch, not really a VM
            Dhcp = @{ Name = "hvk8s-dhcp-dns"; Ip = "$([Config]::Network.subnetPrefix).2" }
            Master = @{ Name = "hvk8s-master"; Ip = "$([Config]::Network.subnetPrefix).10" }
            Nodes = &{
                1..[Config]::MaxNodes | ForEach-Object {
                    [object] $nodeType = if ($_ -le [Config]::MaxLinuxNodes) { [ClusterNodeType]::Linux } else { [ClusterNodeType]::Windows }
                    @{ Name = "hvk8s-node$($_)"; Ip = "$([Config]::Network.subnetPrefix).$($_ + 10)"; NodeType = $nodeType }
                }
            }
        }
    }

    $global:rs.Config = &{ return [Config] }
    $global:rs.ClusterNodeType = &{ return [ClusterNodeType] }

    if ($global:rs.__modules -notcontains $PSCommandPath) {
        $global:rs.__modules += $PSCommandPath
    }
}
