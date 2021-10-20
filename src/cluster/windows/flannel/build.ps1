param (
    [string] $tag = 'local'
)

$ErrorActionPreference = 'Stop'

[string] $goBinPath = "${env:ProgramFiles}\go\bin\"
if (!(Test-Path $goBinPath)) {
    Write-Host 'The path to go.exe could not be found; is golang installed?'
}

$env:Path += ";${goBinPath}"

go build -o setup.exe setup.go
if (!$?) {
    Write-Error "Failed to build 'setup.exe'"
}

docker build -t "flannel:${tag}" -f Dockerfile .