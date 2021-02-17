$ErrorActionPreference = "Stop"

class Git {
    static [string] $RepoRoot = $(git rev-parse --show-toplevel)
}

[type] $script:Git = &{ return [Git] }