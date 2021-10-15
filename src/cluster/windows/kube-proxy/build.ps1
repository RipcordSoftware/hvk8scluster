param (
    [string] $tag = 'local'
)

$ErrorActionPreference = 'Stop'

docker build -t "kube-proxy:${tag}" -f Dockerfile .