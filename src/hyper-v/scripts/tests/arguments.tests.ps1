. "${PSScriptRoot}/../arguments.ps1"

Describe 'Arguments' {
    [object] $rs = $global:rs

    It 'Given a null reference, it gets an empty object' {
        [object] $options = $rs.Arguments::GetLongOptions($null)
        $options.Count | Should -BeExactly 0
    }

    It 'Given no options, it gets an empty object' {
        [object] $options = $rs.Arguments::GetLongOptions('')
        $options.Count | Should -BeExactly 0
    }

    It 'Given a simple test option, it gets an object' {
        [object] $options = $rs.Arguments::GetLongOptions('--test')
        $options.test | Should -BeTrue
    }

    It 'Given two options, it gets an object' {
        [object] $options = $rs.Arguments::GetLongOptions(@('--abc', '--xyz'))
        $options.abc | Should -BeTrue
        $options.xyz | Should -BeTrue
    }

    It 'Given an option with a value, it gets an object' {
        [object] $options = $rs.Arguments::GetLongOptions(@('--abc', 'xyz'))
        $options.abc | Should -BeExactly "xyz"
    }

    It 'Given an option with values, it gets an object' {
        [object] $options = $rs.Arguments::GetLongOptions(@('--abc', 'xyz', 'pqr'))
        $options.abc | Should -BeExactly "xyz pqr"
    }

    It 'Given two options, one with a value, it gets an object' {
        [object] $options = $rs.Arguments::GetLongOptions(@('--abc', '--xyz', 'pqr'))
        $options.abc | Should -BeTrue
        $options.xyz | Should -BeExactly "pqr"
    }

    It 'Given two options, the last with with two values, it gets an object' {
        [object] $options = $rs.Arguments::GetLongOptions(@('--abc', '--xyz', 'pqr', 'mno'))
        $options.abc | Should -BeTrue
        $options.xyz | Should -BeExactly "pqr mno"
    }

    It 'Given two options, the first with two values, it gets an object' {
        [object] $options = $rs.Arguments::GetLongOptions(@('--xyz', 'pqr', 'mno', '--abc'))
        $options.abc | Should -BeTrue
        $options.xyz | Should -BeExactly "pqr mno"
    }
}
