. "${PSScriptRoot}/../ssh.ps1"

Describe 'Ssh' {
    BeforeAll {
        $Ssh = $global:rs.Ssh
        $CopyFileMode = $global:rs.CopyFileMode
    }

    It 'Ssh should be in scope' {
        $Ssh | Should -BeOfType [object]
    }

    It 'CopyFileMode should be in scope' {
        $CopyFileMode | Should -BeOfType [object]
    }
}
