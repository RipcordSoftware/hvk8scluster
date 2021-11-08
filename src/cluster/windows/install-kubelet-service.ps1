#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory)][string] $kubernetesPath,
    [Parameter(Mandatory)][string] $nssmExePath,
    [string] $kubeletServiceName = 'kubelet'
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/nssm.ps1"
$global:rs.Nssm::nssmExePath = $nssmExePath

if (!$global:rs.Nssm::Exists($kubeletServiceName)) {
    Write-Host "Waiting for kubeadm..."
    [string] $kubeadmFlagsPath = "${env:SystemDrive}/var/lib/kubelet/kubeadm-flags.env"
    while (!(Test-Path $kubeadmFlagsPath)) {
        Write-Host '.'
        Start-Sleep -Seconds 10
    }

    [string] $fileContent = Get-Content -Path $kubeadmFlagsPath
    [object] $kubeletArgs = $fileContent -replace '^KUBELET_KUBEADM_ARGS="' -replace '\s*"$' -split ' --' |
        ForEach-Object { if ($_ -notmatch '^--') { '--' + $_ } else { $_ } }

    $global:rs.Nssm::Install(
        $kubeletServiceName,
        "${kubernetesPath}\kubelet.exe",
        @($kubeletArgs) + @(
            "--cert-dir=${env:SYSTEMDRIVE}\var\lib\kubelet\pki"
            '--config=/var/lib/kubelet/config.yaml'
            '--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf'
            '--kubeconfig=/etc/kubernetes/kubelet.conf'
            "--hostname-override=${env:COMPUTERNAME}"
            '--pod-infra-container-image="mcr.microsoft.com/oss/kubernetes/pause:3.5"'
            '--enable-debugging-handlers'
            '--cgroups-per-qos=false'
            '--enforce-node-allocatable=""'
            '--network-plugin=cni'
            '--resolv-conf=""'
            '--log-dir=/var/log/kubelet'
            '--logtostderr=false'
            '--image-pull-progress-deadline=20m'
        ),
        @('docker', 'install-docker-host-network-service'),
        $global:rs.NssmServiceOptions::Start -bor $global:rs.NssmServiceOptions::ExitRestart)
}

# make sure we run for at least 10s (required for nssm)
Start-Sleep -Seconds 10