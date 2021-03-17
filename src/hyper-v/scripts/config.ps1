$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/git.ps1"

class Config {
    static [string] $RepoRoot = $script:Git::RepoRoot

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

[type] $script:Config = &{ return [Config] }
