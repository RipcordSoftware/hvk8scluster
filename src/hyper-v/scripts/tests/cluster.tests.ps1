. "${PSScriptRoot}/../cluster.ps1"

Describe 'Cluster' {
    BeforeAll {
        $Cluster = $global:rs.Cluster
    }

    It 'Cluster should be in scope' {
        $Cluster | Should -BeOfType [object]
    }
}
