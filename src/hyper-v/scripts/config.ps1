$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/git.ps1"

if (!$global:rs) {
    $global:rs = @{}
}

&{
    class Config {
        static [string] $RepoRoot = $global:rs.Git::RepoRoot

        static [string] $BinDir = "$([Config]::RepoRoot)/bin"
        static [string] $SrcDir = "$([Config]::RepoRoot)/src"

        static [string] $IsoDir = "$([Config]::BinDir)/isos"
        static [string] $ExportDir = "$([Config]::BinDir)/exports"
        static [string] $KeyDir = "$([Config]::SrcDir)/keys"

        static [object] $Vm = @{
            Gateway = @{ Name = "k8s-gateway"; Ip = "172.31.0.1" }  # the Hyper-V gateway/vswitch, not really a VM
            Dhcp = @{ Name = "k8s-dhcp-dns"; Ip = "172.31.0.2" }
            Master = @{ Name = "k8s-master"; Ip = "172.31.0.10" }
        }
    }

    $global:rs.Config = &{ return [Config] }
}
