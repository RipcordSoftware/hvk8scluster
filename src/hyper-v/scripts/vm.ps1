$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/k8s.ps1"
. "${PSScriptRoot}/ssh.ps1"

class Vm {
    static [string] $VhdPath = "$($env:PUBLIC)\Documents\Hyper-V\Virtual Hard Disks"

    static [bool] Create(
        [string] $vmName,
        [string] $isoPath,
        [int] $vmCpuCount = 2,
        [int] $vmMinMemoryMB = 256,
        [int] $vmMaxMemoryMB = 1024,
        [int] $vmDiskSizeGB = 4,
        [string] $vmSwitch = "Kubernetes",
        [switch] $removeVhd,
        [switch] $removeVm,
        [switch] $updateVm
    ) {
        if ($removeVm -and $updateVm) {
            Write-Error "Only one of removeVm or updateVm may be specified"
        }

        [object] $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

        if ($vm -and !$updateVm) {
            if ($removeVm) {
                [Vm]::Remove($vmName)
                $vm = $null
            } else {
                Write-Error "The VM '${vmName}' already exists and neither removeVm or updateVm has been specified"
            }
        }

        [bool] $createdVm = $false
        [int64] $vmMinMemory = $vmMinMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmMaxMemory = $vmMaxMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmDiskSize = $vmDiskSizeGB * $script:K8s::Memory.Gi

        if (!$vm) {
            [Vm]::RemoveVhd($vmName)

            [string] $diskPath = [Vm]::GetVhdPath($vmName)
            $vm = New-VM -Name $vmName -SwitchName $vmSwitch -NewVHDPath $diskPath -NewVHDSizeBytes $vmDiskSize -Generation 2
            $createdVm = $true
        }

        if ($createdVm) {
            try {
                Set-VM -Name $vmName -MemoryStartupBytes $vmMaxMemory -AutomaticStartAction Start -AutomaticStartDelay 30 -ProcessorCount $vmCpuCount -DynamicMemory -MemoryMinimumBytes $vmMinMemory -MemoryMaximumBytes $vmMaxMemory

                [object] $scsi = Get-VMScsiController -VMName $vmName
                [object] $dvdDrive = Add-VMDvdDrive -VMDriveController $scsi -Path $isoPath -Passthru
                Set-VMFirmware -VMName $vmName -EnableSecureBoot Off -FirstBootDevice $dvdDrive

                Start-VM -Name $vmName
            } catch {
                Remove-VM -Name $vmName -Force -ErrorAction Continue
                throw
            }
        } else {
            [Vm]::Update($vmName, $vmCpuCount, $vmMinMemoryMB, $vmMaxMemoryMB)
        }

        return $createdVm
    }

    static [void] Update([string] $vmName, [int] $vmCpuCount, [int] $vmMinMemoryMB, [int] $vmMaxMemoryMB) {
        [int64] $vmMinMemory = $vmMinMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmMaxMemory = $vmMaxMemoryMB * $script:K8s::Memory.Mi

        [object] $vmMemory = Get-VMMemory -VMName $vmName
        [object] $vmCpu = Get-VMProcessor -VMName $vmName

        [object] $changes = @{}
        if ($vmCpu.Count -ne $vmCpuCount) {
            $changes.ProcessorCount = $vmCpuCount
        }
        if ($vmMaxMemory -gt $vmMemory.Maximum) {
            $changes.MemoryMaximumBytes = $vmMaxMemory
        }
        if ($vmMinMemory -gt $vmMemory.Minimum) {
            $changes.MemoryMinimumBytes = $vmMinMemory
        }
        if ($changes.Count -gt 0) {
            Set-VM -Name $vmName @changes
        }
    }

    static [void] RemoveVhd([string] $vmName) {
        [string] $diskDir = [Vm]::GetVhdDirectory($vmName)
        if (Test-Path $diskDir) {
            Remove-Item $diskDir -Recurse -Force
        }
    }

    static [void] Remove([string] $vmName) {
        Remove-VM -Name $vmName -Force
    }

    static [string] GetVhdDirectory([string] $vmName) {
        return "$([Vm]::VhdPath)/${vmName}"
    }

    static [string] GetVhdPath([string] $vmName) {
        return [Vm]::GetVhdPath($vmName, $vmName)
    }

    static [string] GetVhdPath([string] $vmName, [string] $diskName) {
        return "$([Vm]::VhdPath)/${vmName}/${diskName}.vhdx"
    }

    static [string] WaitForIpv4([string] $vmName, [bool] $echoConsole) {
        [int] $echoTicks = 0

        [string] $ip = $null
        while (!$ip) {
            [object] $adapter = Get-VMNetworkAdapter -VMName $vmName
            while ($adapter.IPAddresses.Count -lt 1) {
                Start-Sleep -Seconds 10
                if ($echoConsole) {
                    Write-Host -NoNewline "."
                    $echoTicks++
                }
            }

            $ip = $adapter.IPAddresses | Where-Object { $_.Contains(".") } | Select-Object -First 1
        }

        if ($echoTicks -gt 0) {
            Write-Host
        }

        return $ip
    }

    static [object] GetVm([string] $vmName) {
        [object] $vm = Get-Vm -Name $vmName -ErrorAction SilentlyContinue

        # note: PS won't return an invalid vm object instance, so handle this by returning null instead
        if ($vm) {
            return $vm
        } else {
            return $null
        }
    }
}
