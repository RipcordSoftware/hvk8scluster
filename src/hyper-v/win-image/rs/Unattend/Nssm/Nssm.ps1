#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

[object] $scripts = Get-Content "${PSScriptRoot}\Nssm.dat"
[string] $stdout = "${PSScriptRoot}\Nssm.stdout.log"
[string] $stderr = "${PSScriptRoot}\Nssm.stderr.log"

# use pwsh if available
[string] $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
[string] $powershellCorePath = "$env:SystemDrive\Program Files\PowerShell\7\pwsh.exe"
if (Test-Path $powershellCorePath) {
    $powershell = $powershellCorePath
}

$scripts | ForEach-Object {
    [object] $script = $_ | ConvertFrom-Json

    [string] $command = $script.command
    [string] $arguments = $script.arguments

    [object] $startProcessArguments = @(
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Unrestricted',
        '-OutputFormat', 'Text', '-File', $command
    )

    if ($arguments) {
        $startProcessArguments += $arguments
    }

    Write-Host "Running '${command}' with '${powershell}'..."
    [object] $process = Start-Process -Wait -NoNewWindow -FilePath $powershell -ArgumentList $startProcessArguments `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru

    if (!$process -or ($process.ExitCode -ne 0)) {
        Write-Error "The command '${command}' has failed with an error"
    }
}