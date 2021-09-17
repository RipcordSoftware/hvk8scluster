#Requires -RunAsAdministrator

param (
    [string[]] $serviceNames = @(),
    [string[]] $paths = @(),
    [int] $interval = 10,
    [int] $delay = 30,
    [switch] $disableDelay,
    [Parameter(ValueFromRemainingArguments=$true, Position=1)] $cmdArgs
)

$ErrorActionPreference = 'Stop'

try {
    if (!$serviceNames -and !$paths -and $cmdArgs -match '^@') {
        [string] $argsFile = $cmdArgs.SubString(1)
        [object] $argsObj = Get-Content $argsFile | ConvertFrom-Json
        $serviceNames = $argsObj.serviceNames
        $paths = $argsObj.paths
    }

    while ($true) {
        [object] $filteredServices = @()
        if ($serviceNames) {
            $filteredServices = @(Get-Service | Where-Object { $serviceNames -contains $_.Name })
        }

        [object] $filteredPaths = @()
        if ($paths) {
            $filteredPaths = @($paths | ForEach-Object { Invoke-Expression """$($_)""" } | Where-Object { Test-Path $_ })
        }

        if (($filteredServices.Length -eq $serviceNames.Length) -and ($filteredPaths.Length -eq $paths.Length)) {
            if (!!(Get-Service | Where-Object { $_.Name -eq 'restart-computer' })) {
                Set-Service 'restart-computer' -StartupType Manual
            }

            if (!$disableDelay) {
                Write-Host "Waiting for ${delay} to restart..."
                Start-Sleep -Seconds $delay
            }

            Restart-Computer -Force
        }

        Start-Sleep -Seconds $interval
    }
} catch {
    $_ | Out-File "${PSCommandPath}.log"
    throw
}