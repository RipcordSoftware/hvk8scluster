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

    class VmMemory {
        [bool] $dynamic
        [int] $minMB
        [int] $startupMB
        [int] $maxMB

        VmMemory([bool] $dynamic, [int] $minMB, [int] $startupMB, [int] $maxMB) {
            $this.dynamic = $dynamic
            $this.minMB = $minMB
            $this.startupMB = $startupMB
            $this.maxMB = $maxMB
        }

        [object] Calculate([int] $memMB) {
            $memMB = [Math]::Max($memMB, $this.minMB)
            return [VmMemory]::new($this.dynamic, $this.minMB, [Math]::Min($memMB, $this.startupMB), [Math]::Max($memMB, $this.maxMB))
        }
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

        static [object] $Memory = @{
            Template = @{
                Linux = [VmMemory]::new($true, 640, 640, 1024)
                Windows = [VmMemory]::new($true, 256, 1024, 1024)
            }
            Dhcp = [VmMemory]::new($true, 64, 640, 1024)
            Master = [VmMemory]::new($true, 2048, 2048, 3072)
            Node = [VmMemory]::new($true, 1024, 1536, 4096)
        }

        static [object] $Vm = @{
            Gateway = @{ Name = "hvk8s-gateway"; Ip = "$([Config]::Network.subnetPrefix).1" }  # the Hyper-V gateway/vswitch, not really a VM
            Dhcp = @{ Name = "hvk8s-dhcp-dns"; Ip = "$([Config]::Network.subnetPrefix).2"; Memory = [Config]::Memory.Dhcp }
            Master = @{ Name = "hvk8s-master"; Ip = "$([Config]::Network.subnetPrefix).10"; Memory = [Config]::Memory.Master }
            Nodes = &{
                1..[Config]::MaxNodes | ForEach-Object {
                    [object] $nodeType = if ($_ -le [Config]::MaxLinuxNodes) { [ClusterNodeType]::Linux } else { [ClusterNodeType]::Windows }
                    @{ Name = "hvk8s-node$($_)"; Ip = "$([Config]::Network.subnetPrefix).$($_ + 10)"; NodeType = $nodeType; Memory = [Config]::Memory.Node }
                }
            }
        }
    }

    $global:rs.Config = &{ return [Config] }
    $global:rs.VmMemory = &{ return [VmMemory] }
    $global:rs.ClusterNodeType = &{ return [ClusterNodeType] }

    if ($global:rs.__modules -notcontains $PSCommandPath) {
        $global:rs.__modules += $PSCommandPath
    }
}
