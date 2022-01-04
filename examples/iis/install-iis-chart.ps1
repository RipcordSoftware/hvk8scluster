###############################################################################
# Installs Microsoft IIS into the Kubernetes cluster with Helm
# requires:
# - a valid ~/.kube/config file
# - a running cluster with MetalLB
# - a running cluster with ingress
# - helm.exe
# - updateHosts requires Administrator mode

param (
    [string] $ingressIp = '172.31.0.100',
    [switch] $updateHosts
)

$ErrorActionPreference = "Stop"

helm upgrade -i iis-hvk8s-com $PSScriptRoot --wait
if (!$?) {
    Write-Error "Failed to install the IIS chart"
}

if ($updateHosts) {
    Write-Host "Updating hosts with iis.hvk8s.com..."
    "${ingressIp} iis.hvk8s.com" | Out-File -Append -Encoding ascii -FilePath "${env:SystemRoot}\System32\drivers\etc\hosts"
}
