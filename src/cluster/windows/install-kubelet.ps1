#Requires -RunAsAdministrator

param (
    [string] $kubernetesVersion = '1.22.2',
    [string] $rancherWinsVersion = '0.0.4',
    [string] $downloadPath = "${env:USERPROFILE}\Downloads",
    [string] $kubernetesPath = "${env:SystemDrive}\k",
    [string] $nNssmInstallDirectory = "${env:ProgramFiles}\nssm",
    [switch] $update
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# TODO: consider listing the services
if ($update) {
    if (Get-Service -Name 'rancher-wins' -ErrorAction Ignore) {
        Stop-Service -Name 'rancher-wins'
    }
}

Write-Host "Creating the Kubernetes directory at '$kubernetesPath'..."
$null = New-Item -Path $kubernetesPath -ItemType Directory -Force

# download required files
@(
    @{ uri = "https://dl.k8s.io/v${kubernetesVersion}/bin/windows/amd64/kubelet.exe"; outFile = 'kubelet.exe' }
    @{ uri = "https://dl.k8s.io/v${kubernetesVersion}/bin/windows/amd64/kubeadm.exe"; outFile = 'kubeadm.exe' }
    @{ uri = "https://github.com/rancher/wins/releases/download/v${rancherWinsVersion}/wins.exe"; outFile = 'wins.exe' }
    @{ uri = 'https://k8stestinfrabinaries.blob.core.windows.net/nssm-mirror/nssm-2.24.zip'; outFile = 'nssm.zip' }
) | ForEach-Object {
    [string] $outFile = $_.outFile
    [string] $outFilePath = "${downloadPath}\${outFile}"

    if (!(Test-Path $outFilePath)) {
        Write-Host "Downloading '${outFile}' to '${downloadPath}'..."
        Invoke-WebRequest -UseBasicParsing -Uri $_.uri -OutFile $outFilePath
    }

    Write-Host "Installing '${outFile}' to '${kubernetesPath}'..."
    Copy-Item -Path $outFilePath -Destination $kubernetesPath -Force
}

# install the host docker network
&{
    [object] $networks = (docker network ls --format '{{json .}}') | ConvertFrom-Json
    if (!$?) {
        Write-Error 'Unable to get the list of networks from the docker daemon'
    }

    if (!($networks | Where-Object { $_.Name -eq 'host'})) {
        Write-Host 'Creating the docker host network...'
        docker network create -d nat host
        if (!$?) {
            Write-Error 'Failed to create the docker host network'
        }
    }
}

# install rancher-wins
if (!(Get-Service -Name 'rancher-wins' -ErrorAction Ignore)) {
    Write-Host 'Registering wins service...'
    &"${kubernetesPath}\wins.exe" srv app run --register
    if (!$?) {
        Write-Error 'Failed to register the wins service'
    }
    Start-Service 'rancher-wins'
}

# create well known directories
@(
    @{ path = "${env:SystemDrive}\var\log\kubelet"; link = $null }
    @{ path = "${env:SystemDrive}\var\lib\kubelet\etc\kubernetes"; link = $null }
    @{ path = "${env:SystemDrive}\var\lib\kubelet\etc\kubernetes\manifests"; link = $null }
    @{ path = "${env:SystemDrive}\etc\kubernetes\pki"; link = "${env:SystemDrive}\var\lib\kubelet\etc\kubernetes\pki" }
) | ForEach-Object {
    [string] $path =$_.path
    Write-Host "Creating directory '${path}'..."
    $null = New-Item -Path $path -ItemType Directory -Force

    if ($_.link) {
        [string] $link = $_.link
        Write-Host "Creating symbolic link '${link}' to '${path}'..."
        $null = New-Item -Path $link -type SymbolicLink -value $path -Force
    }
}

# add a firewall rule for the kubelet
if (!(Get-NetFirewallRule -Name 'kubelet')) {
    Write-Host 'Creating the firewall rule for the kubelet...'
    New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
}

# run kubelet from the console
# NB. it will wait for kubeadm join
&{
    [string] $kubeadmFlagsPath = "${env:SystemDrive}\var\lib\kubelet\kubeadm-flags.env"
    while (!(Test-Path $kubeadmFlagsPath)) {
        Write-Host '.'
        Start-Sleep -Seconds 10
    }

    [string] $fileContent = Get-Content -Path $kubeadmFlagsPath
    [string] $kubeletArgs = $fileContent.TrimStart('KUBELET_KUBEADM_ARGS=').Trim('"')

    Write-Host 'Starting kubelet...'
    &"${kubernetesPath}\kubelet.exe" $kubeletArgs `
        --cert-dir=$env:SYSTEMDRIVE\var\lib\kubelet\pki `
        --config=/var/lib/kubelet/config.yaml `
        --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf `
        --kubeconfig=/etc/kubernetes/kubelet.conf `
        --hostname-override=${env:COMPUTERNAME} `
        --pod-infra-container-image="mcr.microsoft.com/oss/kubernetes/pause:3.5" `
        --enable-debugging-handlers `
        --cgroups-per-qos=false `
        --enforce-node-allocatable="" `
        --network-plugin=cni `
        --resolv-conf="" `
        --log-dir=/var/log/kubelet `
        --logtostderr=false `
        --image-pull-progress-deadline=20m
}