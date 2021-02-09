param (
    [string] $vmName = "k8s-unknown",
    [int] $vmCpuCount = 2,
    [int64] $vmMinMemory = 1 * 1024 * 1024 * 1024,
    [int64] $vmMaxMemory = 2 * 1024 * 1024 * 1024,
    [string] $vmDiskName = "${vmName}.vhdx",
    [int64] $vmDiskSize = 40 * 1024 * 1024 * 1024,
    [string] $vmSwitch = "Kubernetes",
    [switch] $removeVhd,
    [switch] $removeVm,
    [string] $debianVersion = "10.7.0"
)

$ErrorActionPreference = "Stop"

[object] $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
if ($vm) {
    if (!$removeVm) {
        Write-Error "The VM '$vmName' already exists"
    }

    Remove-VM -Name $vmName -Force
}

[string] $repoRoot=git rev-parse --show-toplevel

[string] $debianIsoPath = "${repoRoot}/bin/preseed-k8s-debian-${debianVersion}-amd64-netinst.iso"
if (!(Test-Path $debianIsoPath)) {
    Write-Error "The ISO image '$debianIsoPath' is missing, please build it before proceeding"
}

[string] $commonVhdPath = "$($env:PUBLIC)\Documents\Hyper-V\Virtual Hard Disks"
[string] $vmDiskPath = "${commonVhdPath}\${vmDiskName}"
if ($removeVhd -and (Test-Path $vmDiskPath)) {
    Remove-Item $vmDiskPath
}

New-VM -Name $vmName -SwitchName $vmSwitch -NewVHDPath $vmDiskName -NewVHDSizeBytes $vmDiskSize -Generation 2

try {
    Set-VM -Name $vmName -ProcessorCount $vmCpuCount -DynamicMemory -MemoryMinimumBytes $vmMinMemory -MemoryStartupBytes $vmMaxMemory -MemoryMaximumBytes $vmMaxMemory -AutomaticStartAction Start -AutomaticStartDelay 30

    [object] $scsi = Get-VMScsiController -VMName $vmName

    [object] $dvdDrive = Add-VMDvdDrive -VMDriveController $scsi -Path $debianIsoPath -Passthru

    Set-VMFirmware -VMName $vmName -EnableSecureBoot Off -FirstBootDevice $dvdDrive    

    Start-VM -Name $vmName
} catch {
    Write-Error $_
    Remove-VM -Name $vmName -Force
}
