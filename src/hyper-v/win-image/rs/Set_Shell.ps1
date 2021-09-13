$ErrorActionPreference = 'Stop'

Write-Host 'Setting the default shell...'
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon' -Name Shell -Value 'PowerShell.exe'