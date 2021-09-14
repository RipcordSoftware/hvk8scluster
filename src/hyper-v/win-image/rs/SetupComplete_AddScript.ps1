param (
    [Parameter(Mandatory,ValueFromRemainingArguments=$true)][string[]] $commands
)

$ErrorActionPreference = 'Stop'

[string] $scriptsDir = "$env:SystemRoot\Setup\Scripts"

if (!(Test-Path $scriptsDir)) {
    New-Item $scriptsDir -ItemType Directory -Force
}

"powershell.exe -noprofile -File ${commands}" | Out-File "${scriptsDir}\setupcomplete.cmd" -Append -Force -Encoding ascii