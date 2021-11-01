$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
    $global:rs.__modules = @()
}

&{
    class Git {
        static [string] $RepoRoot = $(git rev-parse --show-toplevel)
    }

    $global:rs.Git = &{ return [Git] }

    if ($global:rs.__modules -notcontains $PSCommandPath) {
        $global:rs.__modules += $PSCommandPath
    }
}