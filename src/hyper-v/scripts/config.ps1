$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/git.ps1"

class Config {
    static [string] $RepoRoot = $script:Git::RepoRoot
    static [string] $BinPath = "$([Config]::RepoRoot)/bin"
    static [string] $IsoPath = "$([Config]::BinPath)/isos"
    static [string] $ExportPath = "$([Config]::BinPath)/exports"
}
