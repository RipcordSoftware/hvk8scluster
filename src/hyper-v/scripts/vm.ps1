$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/k8s.ps1"

class Vm {
    static [void] Create(
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

        [bool] $createdVm = $false
        [int64] $vmMinMemory = $vmMinMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmMaxMemory = $vmMaxMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmDiskSize = $vmDiskSizeGB * $script:K8s::Memory.Gi

        [object] $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if ($vm) {
            if (!$removeVm -and !$updateVm) {
                Write-Error "The VM '$vmName' already exists and neither removeVm or updateVm has been specified"
            }
            elseif ($removeVm) {
                Remove-VM -Name $vmName -Force
                $vm = $null
            }
        }

        if (!$vm) {
            [string] $vmDiskName = "${vmName}.vhdx"
            [string] $commonVhdPath = "$($env:PUBLIC)\Documents\Hyper-V\Virtual Hard Disks"
            [string] $vmDiskPath = "${commonVhdPath}\${vmDiskName}"
            if ($removeVhd -and (Test-Path $vmDiskPath)) {
                Remove-Item $vmDiskPath
            }

            $vm = New-VM -Name $vmName -SwitchName $vmSwitch -NewVHDPath $vmDiskName -NewVHDSizeBytes $vmDiskSize -Generation 2
            $createdVm = $true
        }

        try {
            if ($createdVm) {
                Set-VM -Name $vmName -MemoryStartupBytes $vmMaxMemory -AutomaticStartAction Start -AutomaticStartDelay 30 -ProcessorCount $vmCpuCount -DynamicMemory -MemoryMinimumBytes $vmMinMemory -MemoryMaximumBytes $vmMaxMemory

                [object] $scsi = Get-VMScsiController -VMName $vmName
                [object] $dvdDrive = Add-VMDvdDrive -VMDriveController $scsi -Path $isoPath -Passthru
                Set-VMFirmware -VMName $vmName -EnableSecureBoot Off -FirstBootDevice $dvdDrive

                Start-VM -Name $vmName
            } else {
                [object] $vmMemory = Get-VMMemory -VMName $vmName
                [object] $vmCpu = Get-VMProcessor -VMName $vmName

                [object] $changes = @{}
                if ($vmCpu.Count -ne $vmCpuCount) {
                    $changes.ProcessorCount = $vmCpuCount
                }
                if ($vmMaxMemoryMB -gt $vmMemory.Maximum) {
                    $changes.MemoryMaximumBytes = $vmMaxMemory
                }
                if ($vmMinMemoryMB -gt $vmMemory.Minimum) {
                    $changes.MemoryMinimumBytes = $vmMinMemory
                }
                if ($changes.Count -gt 0) {
                    Set-VM -Name $vmName @changes
                }
            }
        } catch {
            Write-Error $_
            if ($createdVm) {
                Remove-VM -Name $vmName -Force
            }
        }
    }
}
