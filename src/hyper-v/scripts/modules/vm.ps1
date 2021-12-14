$ErrorActionPreference = "Stop"

. "${PSScriptRoot}/k8s.ps1"

if (!$global:rs) {
    $global:rs = @{}
    $global:rs.__modules = @()
}

&{
    class Vm {
        static [string] $VhdPath = "$($env:PUBLIC)\Documents\Hyper-V\Virtual Hard Disks"
        static [string] $HyperVAdminSid = "S-1-5-32-578"

        static [bool] Create(
            [string] $vmName,
            [string] $isoPath,
            [int] $vmCpuCount = 2,
            [object] $vmMemory = @{ dynamic = $false; startupMB = 256; minMB = 256; maxMB = 256 },
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
            [int64] $startupMemory = $vmMemory.startupMB * $global:rs.K8s::Memory.Mi
            [int64] $minMemory = $vmMemory.minMB * $global:rs.K8s::Memory.Mi
            [int64] $maxMemory = $vmMemory.maxMB * $global:rs.K8s::Memory.Mi
            [int64] $vmDiskSize = $vmDiskSizeGB * $global:rs.K8s::Memory.Gi

            if (!$vm) {
                [Vm]::RemoveVhd($vmName)

                [string] $diskPath = [Vm]::GetVhdPath($vmName)
                $vm = New-VM -Name $vmName -SwitchName $vmSwitch -NewVHDPath $diskPath -NewVHDSizeBytes $vmDiskSize -Generation 2
                $createdVm = $true
            }

            if ($createdVm) {
                try {
                    Set-VM -Name $vmName -AutomaticStartAction Start -AutomaticStartDelay 30 `
                        -ProcessorCount $vmCpuCount -CheckpointType Disabled

                    if ($vmMemory.dynamic) {
                        Set-VM -Name $vmName -DynamicMemory -MemoryStartupBytes $startupMemory `
                            -MemoryMinimumBytes $minMemory -MemoryMaximumBytes $maxMemory
                    } else {
                        [int64] $memory = (@($startupMemory, $minMemory, $maxMemory) | Measure-Object -Maximum).Maximum
                        Set-VM -Name $vmName -StaticMemory -MemoryStartupBytes $memory
                    }

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
            [int64] $vmMemoryBytes = $vmMemoryMB * $global:rs.K8s::Memory.Mi

            [object] $vmMemory = Get-VMMemory -VMName $vmName
            [object] $vmCpu = Get-VMProcessor -VMName $vmName

            [object] $changes = @{}
            if ($vmCpu.Count -ne $vmCpuCount) {
                $changes.ProcessorCount = $vmCpuCount
            }

            if ($vmMemory.DynamicMemoryEnabled -and $vmMemoryBytes -gt $vmMemory.Maximum) {
                $changes.MemoryMaximumBytes = $vmMemoryBytes
            } elseif (!$vmMemory.DynamicMemoryEnabled -and $vmMemoryBytes -gt $vmMemory.Startup) {
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

        static [void] EjectIsoMedia([string] $vmName) {
            [object] $controller = Get-VMScsiController -VMName $vmName
            if ($controller) {
                $controller.Drives |
                    Where-Object { $_.DvdMediaType } |
                    ForEach-Object {
                        Set-VMDvdDrive -VMName $vmName -ControllerNumber $_.ControllerNumber -ControllerLocation $_.ControllerLocation -Path $null
                    }
            }
        }

        static [object] Export([string] $vmName, [string] $exportDir, [bool] $remove) {
            [string] $exportPath = "${exportDir}/${vmName}"
            if ($remove -and (Test-Path -Path $exportPath)) {
                Remove-Item -Path $exportPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            # export the VM to the template path
            return Export-Vm -Name $vmName -Path $exportDir -Passthru
        }

        static [object] Import([string] $exportDir, [string] $source, [string] $dest) {
            [string] $sourceVmcxPath = [Vm]::GetExportedVmConfigPath($exportDir, $source)
            if (!$sourceVmcxPath) {
                Write-Error "Unable to find a vmcx file for the exported VM '${source}'"
            }

            [string] $diskDir = [Vm]::GetVhdDirectory($dest)
            [object] $vm = Import-Vm -Path $sourceVmcxPath -VhdDestinationPath $diskDir -Copy -GenerateNewId

            # rename the VM
            Get-VM -id $vm.Id | Rename-VM -NewName $dest

            return $vm
        }

        static [string] GetExportedVmConfigPath([string] $exportDir, [string] $vmName) {
            [string] $path = [Vm]::GetExportedVmDir($exportDir, $vmName)
            return Get-ChildItem -Path $path -Include "*.vmcx" -Recurse | Select-Object -First 1
        }

        static [string] GetExportedVmDir([string] $exportDir, [string] $vmName) {
            return "${exportDir}/${vmName}"
        }

        static [bool] IsAdministrator() {
            return !!([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups | Where-Object { $_.Value -eq [Vm]::HyperVAdminSid })
        }

        static [bool] IsInstalled() {
            [object] $vmms = Get-Service vmms -ErrorAction SilentlyContinue
            [object] $compute = Get-Service vmcompute -ErrorAction SilentlyContinue
            return !!$vmms -and !!$compute
        }
    }

    $global:rs.Vm = &{ return [Vm] }

    if ($global:rs.__modules -notcontains $PSCommandPath) {
        $global:rs.__modules += $PSCommandPath
    }
}
