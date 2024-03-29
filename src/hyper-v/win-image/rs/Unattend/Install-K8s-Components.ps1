#Requires -RunAsAdministrator

param (
    [string] $kubernetesVersion = '1.22.2',
    [string] $rancherWinsVersion = '0.0.4',
    [string] $nssmVersion = '2.24',
    [string] $downloadDir = "${env:USERPROFILE}/Downloads",
    [string] $kubernetesPath = "${env:SystemDrive}/k",
    [string] $nssmExePath = "${env:ProgramFiles}\nssm-${nssmVersion}\nssm.exe",
    [switch] $uninstall,
    [switch] $force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. "${PSScriptRoot}/../services/nssm.ps1"
$global:rs.Nssm::nssmExePath = $nssmExePath

[object] $tasks = @(
    @{
        install = {
            Write-Host "Creating the Kubernetes directory at '${kubernetesPath}'..."
            $null = New-Item -Path $kubernetesPath -ItemType Directory -Force

            if ($env:PATH -notmatch $kubernetesPath) {
                Write-Host "Adding the Kubernetes directory '${kubernetesPath}' to the system path ..."

                [string] $path = "${env:PATH};${kubernetesPath};"
                Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'Path' -Value $path
                $env:PATH = $path
            }
        }
        uninstall = {
            if (Test-Path $kubernetesPath) {
                if ($env:PATH -match $kubernetesPath) {
                    Write-Host "Removing the Kubernetes directory '${kubernetesPath}' from the system path ..."

                    [string] $path = $env:PATH -replace $kubernetesPath, ''
                    Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name 'Path' -Value $path
                    $env:PATH = $path
                }

                Write-Host "Removing the Kubernetes directory at '${kubernetesPath}'..."
                Remove-Item -Path $kubernetesPath -Force -Recurse
            }
        }
    }
    @{ download = @{ uri = "https://dl.k8s.io/v${kubernetesVersion}/bin/windows/amd64/kubectl.exe"; file = "kubectl-${kubernetesVersion}.exe"; targetDir = "${kubernetesPath}/kubectl.exe" } }
    @{ download = @{ uri = "https://dl.k8s.io/v${kubernetesVersion}/bin/windows/amd64/kubelet.exe"; file = "kubelet-${kubernetesVersion}.exe"; targetDir = "${kubernetesPath}/kubelet.exe" } }
    @{ download = @{ uri = "https://dl.k8s.io/v${kubernetesVersion}/bin/windows/amd64/kubeadm.exe"; file = "kubeadm-${kubernetesVersion}.exe"; targetDir = "${kubernetesPath}/kubeadm.exe" } }
    @{ download = @{ uri = "https://github.com/rancher/wins/releases/download/v${rancherWinsVersion}/wins.exe"; file = "wins-${rancherWinsVersion}.exe"; targetDir = "${kubernetesPath}/wins.exe" } }
    @{
        install = {
            # add the ipconfig-release-restart service
            if (!$global:rs.Nssm::Exists('ipconfig-release-restart')) {
                Write-Host "Installing the 'ipconfig-release-restart' service..."
                $global:rs.Nssm::InstallInlineScript(
                    'ipconfig-release-restart',
                    "Start-Sleep -Seconds 10; ipconfig /release; Restart-Computer -Force",
                    @(),
                    $global:rs.NssmServiceOptions::ManualStart -bor $global:rs.NssmServiceOptions::ExitNoRestart)
            }
        }
        uninstall = {
            # remove the ipconfig-release-restart service
            @('ipconfig-release-restart') | ForEach-Object {
                if ($global:rs.Nssm::Exists($_)) {
                    Write-Host "Removing '$($_)' service..."
                    $global:rs.Nssm::Uninstall($_)
                }
            }
        }
    }
    @{
        install = {
            # add the install-docker-host-network-service
            @('install-docker-host-network-service') | ForEach-Object {
                if (!$global:rs.Nssm::Exists($_)) {
                    Write-Host "Installing the '$($_)' service..."
                    $global:rs.Nssm::InstallScript($_, "${PSScriptRoot}\..\services\$($_).ps1", @(), @('docker'),
                        $global:rs.NssmServiceOptions::Start -bor $global:rs.NssmServiceOptions::ExitNoRestart)
                }
            }
        }
        uninstall = {
            # remove the 'install-docker-host-network-service' service
            @('install-docker-host-network-service') | ForEach-Object {
                if ($global:rs.Nssm::Exists($_)) {
                    Write-Host "Removing '$($_)' service..."
                    $global:rs.Nssm::Uninstall($_)
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
        uninstall = {
            # remove rancher-wins
            if (!!(Get-Service -Name 'rancher-wins' -ErrorAction Ignore)) {
                Write-Host 'Removing wins service...'
                Stop-Service 'rancher-wins'
                sc.exe delete 'rancher-wins'
            }

            if ($force) {
                Stop-Process -Name "rancher-wins-kube-proxy" -Force -ErrorAction Ignore
                Stop-Process -Name "rancher-wins-flanneld" -Force -ErrorAction Ignore
            }
        }
    }
    @{
        install = {
            # create the well known directories
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
        uninstall = {
            # remove the well known directories
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
                New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250 | Out-Null
            }
        }
        uninstall = {
            # remove the firewall rule for the kubelet
            if (!!(Get-NetFirewallRule -Name 'kubelet' -ErrorAction Ignore)) {
                Write-Host 'Removing the firewall rule for the kubelet...'
                Remove-NetFirewallRule -Name kubelet | Out-Null
            }
        }
    }
    @{
        install = {
            # add the install-kubelet-service
            if (!$global:rs.Nssm::Exists('install-kubelet-service')) {
                Write-Host "Installing the 'install-kubelet-service' service..."
                $global:rs.Nssm::InstallScript(
                    'install-kubelet-service',
                    "${PSScriptRoot}\..\services\install-kubelet-service.ps1",
                    @('-kubernetesPath', $kubernetesPath, '-nssmExePath', $nssmExePath),
                    @(),
                    $global:rs.NssmServiceOptions::Start -bor $global:rs.NssmServiceOptions::ExitNoRestart)
            }
        }
        uninstall = {
            # remove the kubelet services
            @('install-kubelet-service', 'kubelet') | ForEach-Object {
                if ($global:rs.Nssm::Exists($_)) {
                    Write-Host "Removing '$($_)' service..."
                    $global:rs.Nssm::Uninstall($_)
                }
            }
        }
    }
)

if (!$uninstall) {
    $tasks | ForEach-Object {
        if ($_.download) {
            [string] $file = $_.download.file
            [string] $downloadDir = if ($_.download.downloadDir) { $_.download.downloadDir } else { $downloadDir }
            [string] $filePath = "${downloadDir}/${file}"

            if (!(Test-Path $filePath)) {
                Write-Host "Downloading '${file}' to '${downloadDir}'..."
                New-Item -Path $downloadDir -ItemType Directory -Force
                Invoke-WebRequest -UseBasicParsing -Uri $_.download.uri -OutFile $filePath
            }

            [string] $targetDir =  $_.download.targetDir
            if ($targetDir) {
                if ($file -match '\.zip$') {
                    Write-Host "Expanding '${file}' to '${targetDir}'..."
                    Expand-Archive -Path $filePath -DestinationPath $targetDir -Force
                } else {
                    Write-Host "Installing '${file}' to '${targetDir}'..."
                    Copy-Item -Path $filePath -Destination $targetDir -Force
                }
            }
        }
        if ($_.install) {
            &$_.install
        }
    }
} else {
    $tasks | Sort-Object -Descending { (++$script:i) } | ForEach-Object {
        if ($_.uninstall) {
            &$_.uninstall
        }
    }
}
