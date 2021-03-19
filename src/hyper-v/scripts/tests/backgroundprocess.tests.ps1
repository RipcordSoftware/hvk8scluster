. "${PSScriptRoot}/../backgroundprocess.ps1"

Describe 'Get-BackgroundProcess' {
    BeforeAll {
        $BackgroundProcess = $global:rs.BackgroundProcess
    }

    It 'BackgroundProcess should be in scope' {
        $BackgroundProcess | Should -BeOfType [object]
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a number' {
        $BackgroundProcess::SpinWait("Get a number", { 42 }) | Should -BeExactly 42
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a write error' {
        {
            $BackgroundProcess::SpinWait("Get a number", {
                Write-Error "It happened"
            })
        } | Should -Throw "It happened"
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get an exception' {
        {
            $BackgroundProcess::SpinWait("Get a number", {
                throw "We are doomed!"
            })
        } | Should -Throw "We are doomed!"
    }
}
