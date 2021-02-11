$ErrorActionPreference = "Stop"

class Git {
    static [string] $RepoRoot = $(git rev-parse --show-toplevel)
}
