$ErrorActionPreference = "Stop"

class Ssh {
    static [void] RemoveHostKeys([string[]] $keys) {
        [string[]] $knownHosts = Get-Content -Path "~/.ssh/known_hosts"
        $knownHosts | Where-Object {
            [string[]] $parts = $_ -split ' '
            return !$parts -or ($keys -notcontains $parts[0])
        } | Out-File -FilePath "~/.ssh/known_hosts" -Encoding ascii
    }

    static [string] InvokeRemoteCommand([string] $ip, [string] $command, [string] $user, [string] $privateKeyPath) {
        [string] $stdErr = New-TemporaryFile
        [string] $stdOut = New-TemporaryFile

        [object] $sshArgs = @("-q", "-o", "StrictHostKeyChecking=no", "-i", $privateKeyPath, "-l", $user,  $ip, $command)

        [object] $p = Start-Process -NoNewWindow -Wait -FilePath "ssh.exe" -ArgumentList $sshArgs `
            -RedirectStandardError $stdErr -RedirectStandardOutput $stdOut -PassThru

        [string] $output = $null
        try {
            if ($p.ExitCode -eq 0) {
                $output = Get-Content -Path $stdOut -Raw
            } else {
                [string] $msg = "The command '${command}' on host '${ip}' failed with exit code $($p.ExitCode)`n" +
                "=[stderr]======================================================================`n" +
                "$(Get-Content -Path $stdErr -Raw)`n" +
                "=[stdout]======================================================================`n" +
                "$(Get-Content -Path $stdOut -Raw)`n" +
                "===============================================================================`n"
                Write-Error $msg
            }
        } finally {
            Remove-Item -Path @($stdOut, $stdErr) -Force -ErrorAction Continue
        }

        return $output
    }

    static [bool] TestSsh([string] $ip) {
        return (Test-NetConnection -ComputerName $ip -Port 22 -WarningAction SilentlyContinue).TcpTestSucceeded
    }

    static [void] WaitForSsh([string] $ip, [bool] $echoConsole) {
        [int] $echoTicks = 0
        while (![Ssh]::TestSsh($ip)) {
            Start-Sleep -Seconds 10
            if ($echoConsole) {
                Write-Host -NoNewline "."
                $echoTicks++
            }
        }
        if ($echoTicks -gt 0) {
            Write-Host
        }
    }
}

[type] $script:Ssh = &{ return [Ssh] }
