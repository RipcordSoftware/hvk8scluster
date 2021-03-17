. "${PSScriptRoot}/../k8s.ps1"

Describe 'Get-K8s' {
    BeforeAll {
        $K8s = $global:rs.K8s
    }

    It 'K8s should be in scope' {
        $K8s | Should -BeOfType [object]
    }
}
