#Requires -RunAsAdministrator

param (
    [string] $k8sVersion = '1.21.0',
    [string] $prepareNodeVersion = '0.1.5',
    [int] $interval = 10
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# wait for docker to start
[bool] $running = $false
while (!$running) {
    [object] $service = Get-Service -Name 'docker' -ErrorAction Ignore
    $running = $service -and ($service.Status -eq 'Running')
    if (!$running) {
        Start-Sleep -Seconds $interval
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# install kubectl
[string] $kubectlPath = "${env:SystemRoot}\kubectl.exe"
if (!(Test-Path $kubectlPath)) {
    Invoke-WebRequest -UseBasicParsing -Uri "https://dl.k8s.io/release/v${k8sVersion}/bin/windows/amd64/kubectl.exe" -OutFile $kubectlPath
}

# install kubeadm
[string] $prepareNodePath = "${env:SystemRoot}\PrepareNode.ps1"
if (!(Test-Path $prepareNodePath)) {
    Invoke-WebRequest -UseBasicParsing `
        -Uri "https://github.com/kubernetes-sigs/sig-windows-tools/releases/download/v${prepareNodeVersion}/PrepareNode.ps1" `
        -OutFile $prepareNodePath
    &$prepareNodePath -KubernetesVersion "v${k8sVersion}"
}