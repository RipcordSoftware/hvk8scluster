param (
    [string] $distro = 'Ubuntu-18.04'
)

$ErrorActionPreference = "Stop"

[object] $here = Get-Item -Path $PSScriptRoot
[string] $drive = $here.Root.Name.ToLower()[0]
[string] $path = $here.FullName -replace '^[a-zA-Z]:', '' -replace '\\', '/'

[string] $cwd = "/mnt/${drive}/${path}"

[string] $exec = "cd ${cwd} && ./install-ubuntu-tools.sh"

wsl -d $distro -u root --exec bash -c $exec
