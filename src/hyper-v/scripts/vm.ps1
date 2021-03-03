$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/k8s.ps1"
. "${PSScriptRoot}/ssh.ps1"

class Vm {
    static [string] $VhdPath = "$($env:PUBLIC)\Documents\Hyper-V\Virtual Hard Disks"

    static [bool] Create(
        [string] $vmName,
        [string] $isoPath,
        [int] $vmCpuCount = 2,
        [int] $vmMemoryMB = 256,
        [int] $vmDiskSizeGB = 4,
        [string] $vmSwitch = "Kubernetes",
        [bool] $removeVhd,
        [bool] $removeVm,
        [bool] $updateVm
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
        [int64] $vmMemory = $vmMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmDiskSize = $vmDiskSizeGB * $script:K8s::Memory.Gi

        if (!$vm) {
            [Vm]::RemoveVhd($vmName)

            [string] $diskPath = [Vm]::GetVhdPath($vmName)
            $vm = New-VM -Name $vmName -SwitchName $vmSwitch -NewVHDPath $diskPath -NewVHDSizeBytes $vmDiskSize -Generation 2
            $createdVm = $true
        }

        if ($createdVm) {
            try {
                Set-VM -Name $vmName -MemoryStartupBytes $vmMemory -AutomaticStartAction Start -AutomaticStartDelay 30 `
                    -ProcessorCount $vmCpuCount -StaticMemory -CheckpointType Disabled

                [object] $scsi = Get-VMScsiController -VMName $vmName
                [object] $dvdDrive = Add-VMDvdDrive -VMDriveController $scsi -Path $isoPath -Passthru
                Set-VMFirmware -VMName $vmName -EnableSecureBoot Off -FirstBootDevice $dvdDrive

                Start-VM -Name $vmName
            } catch {
                Remove-VM -Name $vmName -Force -ErrorAction Continue
                throw
            }
        } else {
            [Vm]::Update($vmName, $vmCpuCount, $vmMemory)
        }

        return $createdVm
    }

    static [void] Update([string] $vmName, [int] $vmCpuCount, [int] $vmMemoryMB) {
        [int64] $vmMemoryBytes = $vmMemoryMB * $script:K8s::Memory.Mi

        [object] $vmMemory = Get-VMMemory -VMName $vmName
        [object] $vmCpu = Get-VMProcessor -VMName $vmName

        [object] $changes = @{}
        if ($vmCpu.Count -ne $vmCpuCount) {
            $changes.ProcessorCount = $vmCpuCount
        }
        if ($vmMemoryBytes -gt $vmMemory.Startup) {
            $changes.MemoryStartupBytes = $vmMemoryBytes
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

    static [object] Export([string] $vmName, [bool] $remove) {
        [string] $exportPath = "$($script:Config::ExportPath)/${vmName}"
        if ($remove -and (Test-Path -Path $exportPath)) {
            Remove-Item -Path $exportPath -Recurse -Force -ErrorAction SilentlyContinue
        }

        # export the VM to the template path
        return Export-Vm -Name $vmName -Path $script:Config::ExportPath -Passthru
    }

    static [object] Import([string] $source, [string] $dest) {
        [string] $sourceVmcxPath = [Vm]::GetExportedVmConfigPath($source)
        if (!$sourceVmcxPath) {
            Write-Error "Unable to find a vmcx file for the exported VM '${source}'"
        }

        [string] $diskDir = [Vm]::GetVhdDirectory($dest)
        [object] $vm = Import-Vm -Path $sourceVmcxPath -VhdDestinationPath $diskDir -Copy -GenerateNewId

        # rename the VM
        Get-VM -id $vm.Id | Rename-VM -NewName $dest

        return $vm
    }

    static [string] GetExportedVmConfigPath([string] $vmName) {
        [string] $path = [Vm]::GetExportedVmDir($vmName)
        return Get-ChildItem -Path $path -Include "*.vmcx" -Recurse | Select-Object -First 1
    }

    static [string] GetExportedVmDir([string] $vmName) {
        return "$($script:Config::ExportPath)/${vmName}"
    }
}
