$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
}

&{
    enum CopyFileMode {
        None = 0
        SetExecutable = 1
        IncludeSourcePath = 2
    }

    class Ssh {
        static [object] $defaultSshArgs = @("-q", "-o", "StrictHostKeyChecking=no")

        static [void] RemoveHostKeys([string[]] $keys) {
            [string[]] $knownHosts = Get-Content -Path "~/.ssh/known_hosts" -ErrorAction SilentlyContinue
            $knownHosts | Where-Object {
                [string[]] $parts = $_ -split ' '
                return !$parts -or ($keys -notcontains $parts[0])
            } | Out-File -FilePath "~/.ssh/known_hosts" -Encoding ascii
        }

        static [void] CopyFile([string] $ip, [string] $file, [string] $remotePath, [string] $user, [string] $privateKeyPath, [CopyFileMode] $mode) {
            if (!(Test-Path -Path $file -PathType leaf)) {
                Write-Error "Unable to find file '${file}'"
            }

            [string] $targetPath = $remotePath
            if ($mode -band [CopyFileMode]::IncludeSourcePath) {
                $targetPath = [System.IO.Path]::Combine($remotePath, $file) -replace '\\','/'
            }

            [string] $targetDir = [System.IO.Path]::GetDirectoryName($targetPath) -replace '\\','/'
            if ($targetDir) {
                [string] $mkdirCommand = 'mkdir -p "' + $targetDir + '"'
                [Ssh]::InvokeRemoteCommand($ip, $mkdirCommand, $user, $privateKeyPath)
            }

            [string] $target = "${user}@${ip}:${targetPath}"
            [object] $scpArgs = [Ssh]::defaultSshArgs + @("-i", $privateKeyPath, $file, $target)
            [Ssh]::StartProcess("scp.exe", $scpArgs, $file, $ip)

            if ($mode -band [CopyFileMode]::SetExecutable) {
                [string] $chmodCommand += 'chmod u+x "' + $targetPath + '"'
                [Ssh]::InvokeRemoteCommand($ip, $chmodCommand, $user, $privateKeyPath)
            }
        }

        static [string] InvokeRemoteCommand([string] $ip, [string] $command, [string] $user, [string] $privateKeyPath) {
            if (($command -match '^[a-zA-Z0-9/\\_\-. ]*$') -and (Test-Path -Path $command -PathType leaf)) {
                [Ssh]::CopyFile($ip, $command, "/tmp/", $user, $privateKeyPath, [CopyFileMode]::IncludeSourcePath -bor [CopyFileMode]::SetExecutable)
                $command = "/tmp/${command}"
            }

            [object] $sshArgs = [Ssh]::defaultSshArgs + @("-i", $privateKeyPath, "-l", $user, $ip, $command)
            [string] $output = [Ssh]::StartProcess("ssh.exe", $sshArgs, $command, $ip)
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

        static [bool] CheckKeyFilePermissions([string] $keyPath) {
            [object] $keyAccess = (Get-Acl -Path $keyPath).Access |
                Where-Object { ! (@("NT AUTHORITY\SYSTEM", "BUILTIN\Administrators") -contains $_.IdentityReference) } |
                Where-Object { $_.IdentityReference -notmatch "\\${env:USERNAME}`$" }
            return !$keyAccess
        }

        hidden static [string] StartProcess([string] $tool, [object] $arguments, [string] $toolHint, [string] $remoteHint) {
            [string] $output = $null

            [string] $stdErr = New-TemporaryFile
            [string] $stdOut = New-TemporaryFile

            try {
                [object] $p = Start-Process -NoNewWindow -Wait -FilePath $tool -ArgumentList $arguments `
                    -RedirectStandardError $stdErr -RedirectStandardOutput $stdOut -PassThru

                if ($p.ExitCode -eq 0) {
                    $output = Get-Content -Path $stdOut -Raw -Encoding UTF8
                } else {
                    [string] $msg = "The command '${toolHint}' on '${remoteHint}' failed with exit code $($p.ExitCode)`n" +
                    "=[stderr]======================================================================`n" +
                    "$(Get-Content -Path $stdErr -Raw  -Encoding UTF8)`n" +
                    "=[stdout]======================================================================`n" +
                    "$(Get-Content -Path $stdOut -Raw  -Encoding UTF8)`n" +
                    "===============================================================================`n"
                    Write-Error $msg
                }
            } finally {
                Remove-Item -Path @($stdOut, $stdErr) -Force -ErrorAction Continue
            }

            return $output
        }

        static [string] DiscoverPrivateKeyPath([string] $repoRoot) {
            return @("${repoRoot}/src/keys/id_rsa", "~/.ssh/id_rsa") | Where-Object { Test-Path $_ } | Select-Object -First 1
        }
    }

    $global:rs.CopyFileMode = &{ return [CopyFileMode] }
    $global:rs.Ssh = &{ return [Ssh] }
}