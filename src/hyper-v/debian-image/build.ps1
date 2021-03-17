[CmdletBinding(PositionalBinding=$false)]
param (
    [string] $distro = 'Ubuntu-18.04',
    [string] $sshPublicKeyPath = "~/.ssh/id_rsa.pub",
    [Parameter(ValueFromRemainingArguments)][string] $commandArguments
)

. ../scripts/config.ps1

$ErrorActionPreference = "Stop"

[string] $keyDir = $global:rs.Config::KeyDir
Copy-Item -Path $sshPublicKeyPath -Destination $keyDir -Force | Out-Null

[object] $here = Get-Item -Path $PSScriptRoot
[string] $drive = $here.Root.Name.ToLower()[0]
[string] $path = $here.FullName -replace '^[a-zA-Z]:', '' -replace '\\', '/'

[string] $cwd = "/mnt/${drive}/${path}"

[string] $exec = "cd ${cwd} && ./build.sh ${commandArguments}"

wsl -d $distro --exec bash -c $exec
