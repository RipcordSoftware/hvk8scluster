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
        [switch] $removeVm
    ) {
        [int64] $vmMinMemory = $vmMinMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmMaxMemory = $vmMaxMemoryMB * $script:K8s::Memory.Mi
        [int64] $vmDiskSize = $vmDiskSizeGB * $script:K8s::Memory.Gi

        [object] $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if ($vm) {
            if (!$removeVm) {
                Write-Error "The VM '$vmName' already exists"
            }

            Remove-VM -Name $vmName -Force
        }

        [string] $vmDiskName = "${vmName}.vhdx"
        [string] $commonVhdPath = "$($env:PUBLIC)\Documents\Hyper-V\Virtual Hard Disks"
        [string] $vmDiskPath = "${commonVhdPath}\${vmDiskName}"
        if ($removeVhd -and (Test-Path $vmDiskPath)) {
            Remove-Item $vmDiskPath
        }

        New-VM -Name $vmName -SwitchName $vmSwitch -NewVHDPath $vmDiskName -NewVHDSizeBytes $vmDiskSize -Generation 2

        try {
            Set-VM -Name $vmName -ProcessorCount $vmCpuCount -DynamicMemory -MemoryMinimumBytes $vmMinMemory -MemoryStartupBytes $vmMaxMemory -MemoryMaximumBytes $vmMaxMemory -AutomaticStartAction Start -AutomaticStartDelay 30

            [object] $scsi = Get-VMScsiController -VMName $vmName

            [object] $dvdDrive = Add-VMDvdDrive -VMDriveController $scsi -Path $isoPath -Passthru

            Set-VMFirmware -VMName $vmName -EnableSecureBoot Off -FirstBootDevice $dvdDrive    

            Start-VM -Name $vmName
        } catch {
            Write-Error $_
            Remove-VM -Name $vmName -Force
        }
    }
}
