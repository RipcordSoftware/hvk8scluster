$script:ErrorActionPreference = 'Stop'

if (!$global:rs) {
    $global:rs = @{}
}

&{
    class BackgroundProcessSpinChars {

        static hidden [object] $spinChars = $null

        static hidden [object] $defaultChars = @{
            frames = @('|', '/', '-', '\')
            frameDelay = 300
            success = '+'
            fail = '!'
        }

        static hidden [object] $wtChars = @{
            frames = @([char]0x28fe, [char]0x28fd, [char]0x28fb, [char]0x28bf, [char]0x287f, [char]0x28df, [char]0x28ef, [char]0x28f7)
            frameDelay = 300
            success = [char]0x2705
            fail = [char]0x26d4
        }

        static hidden [object] GetSpinChars() {
            if (![BackgroundProcess]::spinChars) {
                if ($env:WT_SESSION) {
                    [BackgroundProcessSpinChars]::spinChars = [BackgroundProcessSpinChars]::wtChars
                } else {
                    [BackgroundProcessSpinChars]::spinChars = [BackgroundProcessSpinChars]::defaultChars
                }
            }
            return [BackgroundProcessSpinChars]::spinChars
        }
    }

    class BackgroundProcessInitialVars {
        static hidden [object] $initialVars = @{}

        static [void] SetInitialVars([object] $vars) {
            if ($vars -is [System.Management.Automation.InvocationInfo]) {
                (Get-Command -Name $vars.InvocationName).Parameters.Keys | ForEach-Object {
                    [object] $var = Get-Variable -Name $_
                    [BackgroundProcessInitialVars]::initialVars[$var.Name] = $var.Value
                }
            } else {
                [BackgroundProcessInitialVars]::initialVars = $vars
            }
        }

        static [string[]] GetInitialVars() {
            return [BackgroundProcessInitialVars]::initialVars.Keys | ForEach-Object {
                [object] $value = [BackgroundProcessInitialVars]::initialVars[$_]
                if ($value -is [string]) {
                    "`$$($_) = '${value}'"
                } elseif (($value -is [boolean]) -or ($value -is [switch])) {
                    "`$$($_) = `$${value}"
                } else {
                    "`$$($_) = ${value}"
                }
            }
        }
    }

    class BackgroundProcess {
        static [System.ConsoleColor] $errorTextColour = [System.ConsoleColor]::Red
        static [System.ConsoleColor] $infoTextColour = [System.ConsoleColor]::DarkGray
        static [System.ConsoleColor] $msgTextColour = [System.ConsoleColor]::White

        static hidden [string[]] GetScriptDependencies([string] $scriptBlock) {
            [string[]] $deps = $null
            [object] $m = [regex]::matches($scriptBlock, '\$global:rs.(?<script>\w+)')
            if ($m) {
                [object] $scripts = $m | ForEach-Object { $_.Groups['script'].Value } | Sort-Object -Unique
                $deps = $scripts | ForEach-Object {
                        "${PSScriptRoot}\$($_).ps1"
                    } | Where-Object {
                        Test-Path $_
                    } | ForEach-Object { ". `"$($_)`"" }
            }
            return $deps
        }

        static [void] SetInitialVars([object] $vars) {
            [BackgroundProcessInitialVars]::SetInitialVars($vars)
        }

        static hidden [string[]] GetInitialVars() {
            return [BackgroundProcessInitialVars]::GetInitialVars()
        }

        static [object] SpinWait([string] $msg, [ScriptBlock] $scriptBlock) {
            return [BackgroundProcess]::SpinWait($msg, $scriptBlock, $null)
        }

        static [object] SpinWait([string] $msg, [ScriptBlock] $scriptBlock, [object] $arguments) {
            [object] $ps = $null
            [object] $result = $null
            [int] $cursorTop = [Console]::CursorTop
            [object] $spinChars = [BackgroundProcessSpinChars]::GetSpinChars()

            [Console]::CursorVisible = $false

            try {
                $ps = [powershell]::Create()

                [object] $currentLocation = Get-Location
                $ps.runspace.SessionStateProxy.Path.SetLocation($currentLocation.Path)

                $ps.AddScript("`$ErrorActionPreference = '${script:ErrorActionPreference}'")
                $ps.AddScript([BackgroundProcessInitialVars]::GetInitialVars() -join '; ')
                $ps.AddScript([BackgroundProcess]::GetScriptDependencies($scriptBlock) -join '; ')
                $ps.AddScript($scriptBlock)

                if ($arguments -is [Array]) {
                    $arguments | ForEach-Object { $ps.AddArgument($_) }
                } elseif ($arguments -is [Hashtable]) {
                    $ps.AddParameters($arguments)
                } elseif ($arguments) {
                    $ps.AddArgument($arguments)
                }

                [object] $ia = $ps.BeginInvoke()

                Write-Host -NoNewline "   ${msg}" -ForegroundColor $([BackgroundProcess]::msgTextColour)

                [int] $counter = 0
                while (!$ia.IsCompleted) {
                    $frame = $spinChars.frames[$counter % $spinChars.frames.Length]

                    [Console]::SetCursorPosition(0, $cursorTop)
                    Write-Host $frame -NoNewLine

                    $counter++
                    Start-Sleep -Milliseconds $spinChars.frameDelay
                }

                [Console]::SetCursorPosition(0, $cursorTop)

                if ($ps.Streams.Error.Count -gt 0) {
                    Write-Host $spinChars.fail
                } else {
                    Write-Host $spinChars.success
                }

                try {
                    $result = $ps.EndInvoke($ia)
                } catch {
                    [object] $ex = $_.Exception
                    while ($ex.InnerException) {
                        $ex = $ex.InnerException
                    }
                    throw $ex
                } finally {
                    $ps.Streams.Information | ForEach-Object { Write-Host -ForegroundColor $([BackgroundProcess]::infoTextColour) $_ }
                }

                $ps.Streams.Error | ForEach-Object { Write-Host -ForegroundColor $([BackgroundProcess]::errorTextColour) $_ }
            } finally {
                [Console]::CursorVisible = $true

                if ($ps) {
                    $ps.Dispose()
                    $ps = $null
                }
            }

            return $result
        }
    }

    $global:rs.BackgroundProcess = &{ return [BackgroundProcess] }
}