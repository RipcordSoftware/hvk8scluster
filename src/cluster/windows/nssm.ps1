$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
    $global:rs.__modules = @()
}

&{
    class Nssm {
        static [string] $nssmExePath = "${env:ProgramFiles}\nssm-2.24\win64\nssm.exe"
        static [string[]] $defaultScriptArgs = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Unrestricted', '-NoExit', '-OutputFormat', 'Text', '-File')

        static [bool] Exists([string] $name) {
            return !!(Get-Service -Name $name -ErrorAction Ignore)
        }

        static [void] Install([string] $name, [string] $app, [string[]] $appArgs, [bool] $start) {
            $appArgs = $appArgs | ForEach-Object { $_ -replace @('"', '"""') }
            $appArgs = $appArgs | ForEach-Object { if (($_.IndexOf(' ') -ge 0) -and ($_[0] -ne '"')) { '"""' + $_ + '"""' } else { $_ } }

            [string] $nssm = [Nssm]::nssmExePath
            &$nssm install $name """${app}""" $appArgs
            if (!$?) {
                Write-Error "Failed to register '${name}' as a service"
            }

            if ($start) {
                Start-Service $name
            }
        }

        static [void] InstallScript([string] $name, [string] $scriptName, [string[]] $scriptArgs, [bool] $start) {
            [string] $app = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            [Nssm]::Install($name, $app, [Nssm]::defaultScriptArgs + $scriptName + $scriptArgs, $start)
        }

        static [void] Uninstall([string] $name) {
            Stop-Service $name
            sc.exe delete $name
            if (!$?) {
                Write-Error "Failed to delete the service '${name}'"
            }
        }
    }

    $global:rs.Nssm = &{ return [Nssm] }

    if ($global:rs.__modules -notcontains $PSCommandPath) {
        $global:rs.__modules += $PSCommandPath
    }
}