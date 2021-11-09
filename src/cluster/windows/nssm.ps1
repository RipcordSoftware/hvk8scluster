$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
    $global:rs.__modules = @()
}

&{
    [Flags()] enum NssmServiceOptions {
        None = 0x0000
        Start = 0x0001
        AutomaticStartDelayed = 0x0010
        ManualStart = 0x0020
        ExitRestart = 0x0100
        ExitNoRestart = 0x0200
    }

    class Nssm {
        static [string] $nssmExePath = "${env:ProgramFiles}\nssm-2.24\nssm.exe"
        static [string[]] $defaultScriptArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Unrestricted', '-OutputFormat', 'Text')

        static [bool] Exists([string] $name) {
            return !!(Get-Service -Name $name -ErrorAction Ignore)
        }

        static [void] Install([string] $name, [string] $app, [string[]] $appArgs, [string[]] $dependencies, [NssmServiceOptions] $options) {
            $appArgs = $appArgs | ForEach-Object { $_ -replace @('"', '"""') }
            $appArgs = $appArgs | ForEach-Object { if (($_.IndexOf(' ') -ge 0) -and ($_[0] -ne '"')) { '"""' + $_ + '"""' } else { $_ } }

            [string] $nssm = [Nssm]::nssmExePath
            &$nssm install $name """${app}""" $appArgs
            if (!$?) {
                Write-Error "Failed to register '${name}' as a service"
            }

            if (($options -band [NssmServiceOptions]::AutomaticStartDelayed) -eq [NssmServiceOptions]::AutomaticStartDelayed) {
                &$nssm set $name Start SERVICE_DELAYED_AUTO_START
            } elseif (($options -band [NssmServiceOptions]::ManualStart) -eq [NssmServiceOptions]::ManualStart) {
                &$nssm set $name Start SERVICE_DEMAND_START
            }

            if (($options -band [NssmServiceOptions]::ExitRestart) -eq [NssmServiceOptions]::ExitRestart) {
                &$nssm set $name AppExit Default Restart
                &$nssm set $name AppThrottle 5000
                &$nssm set $name AppRestartDelay 2000
            } elseif (($options -band [NssmServiceOptions]::ExitNoRestart) -eq [NssmServiceOptions]::ExitNoRestart) {
                &$nssm set $name AppExit Default Exit
            }

            if ($dependencies) {
                &$nssm set $name DependOnService $dependencies
            }

            if (($options -band [NssmServiceOptions]::Start) -eq [NssmServiceOptions]::Start) {
                Start-Service $name
            }
        }

        static [void] InstallScript([string] $name, [string] $scriptName, [string[]] $scriptArgs, [string[]] $dependencies, [NssmServiceOptions] $options) {
            [object] $nssmArgs = [Nssm]::defaultScriptArgs
            $nssmArgs += @('-File', $scriptName) + $scriptArgs

            [string] $app = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            [Nssm]::Install($name, $app, $nssmArgs, $dependencies, $options)
        }

        static [void] InstallInlineScript([string] $name, [string] $script, [string[]] $dependencies, [NssmServiceOptions] $options) {
            [string] $encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))

            [object] $nssmArgs = [Nssm]::defaultScriptArgs
            $nssmArgs += @('-EncodedCommand', $encodedScript)

            [string] $app = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            [Nssm]::Install($name, $app, $nssmArgs, $dependencies, $options)
        }

        static [void] Uninstall([string] $name) {
            Stop-Service $name
            sc.exe delete $name
            if (!$?) {
                Write-Error "Failed to delete the service '${name}'"
            }
        }
    }

    $global:rs.NssmServiceOptions = &{ return [NssmServiceOptions] }
    $global:rs.Nssm = &{ return [Nssm] }

    if ($global:rs.__modules -notcontains $PSCommandPath) {
        $global:rs.__modules += $PSCommandPath
    }
}