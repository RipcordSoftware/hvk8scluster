[CmdletBinding(PositionalBinding=$false)]
param (
    [string] $distro = 'Ubuntu-18.04',
    [Parameter(ValueFromRemainingArguments)][string] $commandArguments
)

$ErrorActionPreference = "Stop"

[object] $here = Get-Item -Path $PSScriptRoot
[string] $drive = $here.Root.Name.ToLower()[0]
[string] $path = $here.FullName -replace '^[a-zA-Z]:', '' -replace '\\', '/'

[string] $cwd = "/mnt/${drive}/${path}"

[string] $exec = "cd ${cwd} && ./build.sh ${commandArguments}"

wsl -d $distro --exec bash -c $exec
