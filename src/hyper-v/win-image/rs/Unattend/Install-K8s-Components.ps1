#Requires -RunAsAdministrator

param (
    [string] $k8sVersion = '1.22.2'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# install kubectl
[string] $kubectlPath = "${env:SystemRoot}\kubectl.exe"
if (!(Test-Path $kubectlPath)) {
    Invoke-WebRequest -UseBasicParsing -Uri "https://dl.k8s.io/release/v${k8sVersion}/bin/windows/amd64/kubectl.exe" -OutFile $kubectlPath
}

# install kubelet
[string] $installKubeletPath = "${env:SystemRoot}\install-kubelet.ps1"
if (!(Test-Path $installKubeletPath)) {
    Invoke-WebRequest -UseBasicParsing `
        -Uri "https://raw.githubusercontent.com/RipcordSoftware/hvk8scluster/main/src/cluster/windows/install-kubelet.ps1" `
        -OutFile $installKubeletPath
    &$installKubeletPath -kubernetesVersion $k8sVersion
}