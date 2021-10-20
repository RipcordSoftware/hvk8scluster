#Requires -RunAsAdministrator

param (
    [string] $kubernetesVersion = '1.22.2',
    [string] $rancherWinsVersion = '0.0.4',
    [string] $downloadPath = "${env:USERPROFILE}/Downloads",
    [string] $kubernetesPath = "${env:SystemDrive}/k",
    [string] $nNssmInstallDirectory = "${env:ProgramFiles}/nssm",
    [switch] $remove
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

[object] $tasks = @(
    @{
        install = {
            Write-Host "Creating the Kubernetes directory at '${kubernetesPath}'..."
            $null = New-Item -Path $kubernetesPath -ItemType Directory -Force
        }
        remove = {
            if (Test-Path $kubernetesPath) {
                Write-Host "Removing the Kubernetes directory at '${kubernetesPath}'..."
                Remove-Item -Path $kubernetesPath -Force -Recurse
            }
        }
    }
    @{ download = @{ uri = "https://dl.k8s.io/v${kubernetesVersion}/bin/windows/amd64/kubelet.exe"; file = "kubelet-${kubernetesVersion}.exe"; targetDir = "${kubernetesPath}/kubelet.exe" } }
    @{ download = @{ uri = "https://dl.k8s.io/v${kubernetesVersion}/bin/windows/amd64/kubeadm.exe"; file = "kubeadm-${kubernetesVersion}.exe.exe"; targetDir = "$kubernetesPath/kubeadm.exe" } }
    @{ download = @{ uri = "https://github.com/rancher/wins/releases/download/v${rancherWinsVersion}/wins.exe"; file = "wins-${rancherWinsVersion}.exe"; targetDir = "$kubernetesPath/wins.exe" } }
    @{ download = @{ uri = 'https://k8stestinfrabinaries.blob.core.windows.net/nssm-mirror/nssm-2.24.zip'; file = 'nssm-2.24.zip'; targetDir = $null } }
    @{
        install = {
            # install the host docker network
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
    }
    @{
        install = {
            # install rancher-wins
            if (!(Get-Service -Name 'rancher-wins' -ErrorAction Ignore)) {
                Write-Host 'Registering wins service...'
                &"${kubernetesPath}/wins.exe" srv app run --register
                if (!$?) {
                    Write-Error 'Failed to register the wins service'
                }
            }
            Write-Host 'Starting the wins service...'
            Start-Service 'rancher-wins'
        }
        remove = {
            # remove rancher-wins
            if (!!(Get-Service -Name 'rancher-wins' -ErrorAction Ignore)) {
                Write-Host 'Removing wins service...'
                Stop-Service 'rancher-wins'
                sc.exe delete 'rancher-wins'
            }
        }
    }
    @{
        install = {
            # create well known directories
            @(
                @{ path = "${env:SystemDrive}/var/log/kubelet"; link = $null }
                @{ path = "${env:SystemDrive}/var/lib/kubelet/etc/kubernetes"; link = $null }
                @{ path = "${env:SystemDrive}/var/lib/kubelet/etc/kubernetes/manifests"; link = $null }
                @{ path = "${env:SystemDrive}/etc/kubernetes/pki"; link = "${env:SystemDrive}/var/lib/kubelet/etc/kubernetes/pki" }
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
        }
        remove = {
            @("${env:SystemDrive}/var", "${env:SystemDrive}/etc") | ForEach-Object {
                if (Test-Path $_) {
                    Write-Host "Removing directory '$($_)'..."
                    Remove-Item $_ -Recurse -Force
                }
            }
        }
    }
    @{
        install = {
            # add a firewall rule for the kubelet
            if (!(Get-NetFirewallRule -Name 'kubelet' -ErrorAction Ignore)) {
                Write-Host 'Creating the firewall rule for the kubelet...'
                New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
            }
        }
        remove = {
            # remove the firewall rule for the kubelet
            if (!!(Get-NetFirewallRule -Name 'kubelet' -ErrorAction Ignore)) {
                Write-Host 'Removing the firewall rule for the kubelet...'
                Remove-NetFirewallRule -Name kubelet
            }
        }
    }
    @{
        # TODO: install a service with NSSM
        install = {
            # run kubelet from the console
            Write-Host "Running kubelet..."

            [string] $kubeadmFlagsPath = "${env:SystemDrive}/var/lib/kubelet/kubeadm-flags.env"
            while (!(Test-Path $kubeadmFlagsPath)) {
                Write-Host '.'
                Start-Sleep -Seconds 10
            }

            [string] $fileContent = Get-Content -Path $kubeadmFlagsPath
            [string] $kubeletArgs = $fileContent.TrimStart('KUBELET_KUBEADM_ARGS=').Trim('"')

            Write-Host 'Starting kubelet...'
            &"${kubernetesPath}/kubelet.exe" $kubeletArgs `
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
    }
)

if (!$remove) {
    $tasks | ForEach-Object {
        if ($_.download) {
            [string] $file = $_.download.file
            [string] $filePath = "${downloadPath}/${file}"

            if (!(Test-Path $filePath)) {
                Write-Host "Downloading '${file}' to '${downloadPath}'..."
                New-Item -Path $downloadPath -ItemType Directory -Force
                Invoke-WebRequest -UseBasicParsing -Uri $_.download.uri -OutFile $filePath
            }

            [string] $targetDir =  $_.download.targetDir
            if ($targetDir) {
                Write-Host "Installing '${file}' to '${targetDir}'..."
                Copy-Item -Path $filePath -Destination $targetDir -Force
            }
        }
        if ($_.install) {
            &$_.install
        }
    }
} else {
    $tasks | Sort-Object -Descending { (++$script:i) } | ForEach-Object {
        if ($_.remove) {
            &$_.remove
        }
    }
}
