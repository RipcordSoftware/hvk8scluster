#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

[object] $networks = (docker network ls --format '{{json .}}') | ConvertFrom-Json
if (!$?) {
    Write-Error 'Unable to get the list of networks from the docker daemon'
}

# install the host docker network
if (!($networks | Where-Object { $_.Name -eq 'host'})) {
    Write-Host 'Creating the docker host network...'
    docker network create -d nat host
    if (!$?) {
        Write-Error 'Failed to create the docker host network'
    }
}

# make sure we run for at least 10s (required for nssm)
Start-Sleep -Seconds 10