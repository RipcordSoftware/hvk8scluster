$ErrorActionPreference = "Stop"

if (!$global:rs) {
    $global:rs = @{}
}

&{
    class ArgumentOption {
        [string] $key = $null
        [object] $values = @()

        [void] SetKey([string] $key) { $this.key = $key -replace '^--', '' }
        [void] AppendValue([string] $value) { $this.values += $value }

        [bool] HasKey() { return !!$this.key }
        [bool] HasValues() { return $this.values.Count }

        [object] GetObject() {
            [object] $obj = $null
            if ($this.HasKey()) {
                if ($this.HasValues()) {
                    $obj = @{ $this.key = $this.values -join ' ' }
                } else {
                    $obj = @{ $this.key = $true }
                }
            }
            return $obj
        }
    }

    class Arguments {
        static [object] GetLongOptions([object] $options) {
            [object] $optObj = @{}
            [object] $currentOption = [ArgumentOption]::new()

            $options | Where-Object { !!$_ } | ForEach-Object {
                if ($_.StartsWith('--')) {
                    if ($currentOption.HasKey()) {
                        $optObj += $currentOption.GetObject()
                        $currentOption = [ArgumentOption]::new()
                    }
                    $currentOption.SetKey($_)
                } else {
                    $currentOption.AppendValue($_)
                }
            } | Out-Null

            if ($currentOption.HasKey()) {
                $optObj += $currentOption.GetObject()
            }

            return $optObj
        }
    }

    $global:rs.ArgumentOption = &{ return [ArgumentOption] }
    $global:rs.Arguments = &{ return [Arguments] }
}
