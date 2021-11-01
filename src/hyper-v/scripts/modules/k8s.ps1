$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
    $global:rs.__modules = @()
}

&{
    class K8s {
        static [object] $Memory = @{ Mi = 1024 * 1024; Gi = 1024 * 1024 * 1024 }
    }

    $global:rs.K8s = &{ return [K8s] }

    if ($global:rs.__modules -notcontains $PSCommandPath) {
        $global:rs.__modules += $PSCommandPath
    }
}
