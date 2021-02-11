$ErrorActionPreference = "Stop"

class K8s {
    static [object] $Memory = @{ Mi = 1024 * 1024; Gi = 1024 * 1024 * 1024 }
}

[type] $script:K8s = &{ return [K8s] }
