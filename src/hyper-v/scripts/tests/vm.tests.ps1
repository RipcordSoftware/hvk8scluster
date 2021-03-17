. "${PSScriptRoot}/../vm.ps1"

Describe 'Get-Vm' {
    BeforeAll {
        $Vm = $global:rs.Vm
    }

    It 'Vm should be in scope' {
        $Vm | Should -BeOfType [object]
    }

    It 'Given a Vm type loaded, the VHD path should be present' {
        $Vm::VhdPath | Should -Exist
    }
}
