. "${PSScriptRoot}/../config.ps1"

Describe 'Get-Config' {
    BeforeAll {
        $Config = $global:rs.Config
    }

    It 'Config should be in scope' {
        $Config | Should -BeOfType [object]
    }

    It 'Given scoped config, all dirs should be present' {
        $Config::RepoRoot | Should -Exist
        $Config::BinDir | Should -Exist
        $Config::SrcDir | Should -Exist
        $Config::IsoDir | Should -Exist
        $Config::ExportDir | Should -Exist
        $Config::KeyDir | Should -Exist
    }

    It 'Given scoped config, VM entries should be present' {
        $Config::Vm.Gateway.Ip | Should -Match '^([0-9]+\.){3}[0-9]+$'
        $Config::Vm.Dhcp.Ip | Should -Match '^([0-9]+\.){3}[0-9]+$'
        $Config::Vm.Master.Ip | Should -Match '^([0-9]+\.){3}[0-9]+$'
    }
}
