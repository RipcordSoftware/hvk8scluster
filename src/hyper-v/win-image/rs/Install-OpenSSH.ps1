#Requires -RunAsAdministrator

param (
    [string] $keyPath,
    [string] $keyUser,
    [switch] $startService,
    [switch] $reboot
)

$ErrorActionPreference = 'Stop'

[object] $serviceInstalled = !!(Get-Service | Where-Object { $_.name -eq 'sshd' })

if (!$serviceInstalled) {
    Write-Host 'Install OpenSSH.Server...'
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

    # detect which powershell to use, preferring pwsh if available
    [string] $powershell = "${env:SystemRoot}\System32\WindowsPowerShell\v1.0\powershell.exe"
    [string] $powershellCorePath = "${env:SystemDrive}\Program Files\PowerShell\7\pwsh.exe"
    if (Test-Path $powershellCorePath) {
        $powershell = $powershellCorePath
    }

    Write-Host 'Set the default SSH shell...'
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value $powershell -PropertyType String -Force

    Write-Host 'Set the services to automatic start...'
    Set-Service sshd -StartupType Automatic

    # copy the public key
    if ($keyPath -and (Test-Path $keyPath)) {
        [string] $sshdDir = "$env:ProgramData\ssh"
        [string] $adminAuthKeysPath = "${sshdDir}\administrators_authorized_keys"

        New-Item -Path $sshdDir -ItemType Directory -Force -ErrorAction SilentlyContinue
        Get-Content $keyPath | Out-File -FilePath $adminAuthKeysPath -Append -Force -Encoding ascii

        # set the ACL on the admin keys file
        [object] $acl = Get-Acl $adminAuthKeysPath
        $acl.SetAccessRuleProtection($true, $false)
        $acl.SetAccessRule([security.accesscontrol.filesystemaccessrule]::new('Administrators', 'FullControl', 'Allow'))
        $acl.SetAccessRule([security.accesscontrol.filesystemaccessrule]::new('SYSTEM', 'FullControl', 'Allow'))
        $acl | Set-Acl

        if ($keyUser) {
            [string] $userHomeDir = "${env:SystemDrive}\Users\${keyUser}"
            [string] $userSshdDir = "${userHomeDir}\.ssh"
            [string] $userAuthorizedKeysPath = "${userSshdDir}\authorized_keys"

            New-Item -Path $userSshdDir -ItemType Directory -Force -ErrorAction SilentlyContinue
            Get-Content $keyPath | Out-File -FilePath $userAuthorizedKeysPath -Append -Force -Encoding ascii
        }
    }

    if ($reboot) {
        Restart-Computer -Force
    }

    if ($startService) {
        Start-Service sshd
    }
}