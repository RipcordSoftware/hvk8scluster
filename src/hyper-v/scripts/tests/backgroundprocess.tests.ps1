. "${PSScriptRoot}/../backgroundprocess.ps1"

Describe 'BackgroundProcess' {
    BeforeAll {
        $BackgroundProcess = $global:rs.BackgroundProcess
    }

    BeforeEach {
        $BackgroundProcess::SetInitialVars(@{})
    }

    It 'BackgroundProcess should be in scope' {
        $BackgroundProcess | Should -BeOfType [object]
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a number' {
        $BackgroundProcess::SpinWait("Get a number", { 42 }) | Should -BeExactly 42
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a number by positional parameter' {
        $BackgroundProcess::SpinWait("Get a number", { param ($x) $x }, @(42)) | Should -BeExactly 42
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a number by named parameter' {
        $BackgroundProcess::SpinWait("Get a number", { param ($x) $x }, @{ x = 42 }) | Should -BeExactly 42
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a number from initial variables' {
        $BackgroundProcess::SetInitialVars(@{ x = 42 })
        $BackgroundProcess::SpinWait("Get a number", { $x }) | Should -BeExactly 42
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a string from initial variables' {
        $BackgroundProcess::SetInitialVars(@{ hello = "world" })
        $BackgroundProcess::SpinWait("Get a string", { $hello }) | Should -BeExactly "world"
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a boolean true from initial variables' {
        $BackgroundProcess::SetInitialVars(@{ enable = $true })
        $BackgroundProcess::SpinWait("Get a boolean true", { $enable }) | Should -BeExactly $true
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a boolean false from initial variables' {
        $BackgroundProcess::SetInitialVars(@{ enable = $false })
        $BackgroundProcess::SpinWait("Get a boolean false", { $enable }) | Should -BeExactly $false
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a switch true from initial variables' {
        $BackgroundProcess::SetInitialVars(@{ enable = [switch]$true })
        $BackgroundProcess::SpinWait("Get a switch true", { $enable }) | Should -BeExactly $true
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a switch false from initial variables' {
        $BackgroundProcess::SetInitialVars(@{ enable = [switch]$false })
        $BackgroundProcess::SpinWait("Get a switch false", { $enable }) | Should -BeExactly $false
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get a write error' {
        {
            $BackgroundProcess::SpinWait("Get a write error", {
                Write-Error "It happened"
            })
        } | Should -Throw "It happened"
    }

    It 'Given BackgroundProcess type loaded, we can run a task to get an exception' {
        {
            $BackgroundProcess::SpinWait("Get an exception", {
                throw "We are doomed!"
            })
        } | Should -Throw "We are doomed!"
    }
}
