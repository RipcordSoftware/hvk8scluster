$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
}

&{
    class Git {
        static [string] $RepoRoot = $(git rev-parse --show-toplevel)
    }

    $global:rs.Git = &{ return [Git] }
}