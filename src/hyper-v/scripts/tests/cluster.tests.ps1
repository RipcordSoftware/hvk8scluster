. "${PSScriptRoot}/../cluster.ps1"

Describe 'Get-Cluster' {
    BeforeAll {
        $Cluster = $global:rs.Cluster
    }

    It 'Cluster should be in scope' {
        $Cluster | Should -BeOfType [object]
    }
}
