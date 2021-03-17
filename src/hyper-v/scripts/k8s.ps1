$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
}

&{
    class K8s {
        static [object] $Memory = @{ Mi = 1024 * 1024; Gi = 1024 * 1024 * 1024 }
    }

    [type] $global:rs.K8s = &{ return [K8s] }
}
