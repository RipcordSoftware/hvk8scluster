param (
    [Parameter(Mandatory)][string] $command,
    [Parameter(ValueFromRemainingArguments=$true)][string[]] $arguments
)

$ErrorActionPreference = 'Stop'

# create the setup\scripts dir
[string] $scriptsDir = "${env:SystemRoot}\Setup\Scripts"
if (!(Test-Path $scriptsDir)) {
    New-Item $scriptsDir -ItemType Directory -Force
}

# create the setupcomplete command file
[string] $setupCompletePath = "${scriptsDir}\setupcomplete.cmd"
if (!(Test-Path $setupCompletePath)) {
    "powershell.exe -NoProfile -NonInteractive -File ${PSScriptRoot}\SetupComplete.ps1" | Out-File "${setupCompletePath}" -Force -Encoding ascii
}

[object] $script = @{ command = $command; arguments = $arguments }

# append the script to the scripts file
$script | ConvertTo-Json -Compress | Out-File "${PSScriptRoot}\SetupComplete.dat" -Append -Force -Encoding ascii