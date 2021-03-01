###############################################################################
# Installs Apache httpd into the Kubernetes cluster with Helm
# requires:
# - a valid ~/.kube/config file
# - a running cluster with MetalLB
# - a running cluster with ingress
# - helm.exe
# - kubectl.exe (to recover the password)
# - updateHosts requires Administrator mode

param (
    [string] $ingressIp = '172.31.0.100',
    [switch] $updateHosts
)

$ErrorActionPreference = "Stop"

helm repo add bitnami https://charts.bitnami.com/bitnami
if (!$?) {
    Write-Error "Unable to add the bitnami repository to helm"
}

helm repo update
if (!$?) {
    Write-Error "Unable to update the bitnami repository"
}

# values: https://github.com/bitnami/charts/blob/master/bitnami/apache/values.yaml
helm upgrade -i `
    --set ingress.enabled=true `
    --set ingress.hostname=www.hvk8s.com `
    --set service.type=ClusterIP `
    --set ingress.annotations.kubernetes\.io/ingress\.class=nginx `
    --set ingress.tls="" `
    www-hvk8s-com-apache bitnami/apache --version 8.3.0 --wait
if (!$?) {
    Write-Error "Failed to install the apache chart"
}

if ($updateHosts) {
    Write-Host "Updating hosts with www.hvk8s.com..."
    "${ingressIp} www.hvk8s.com" | Out-File -Append -Encoding ascii -FilePath "${env:SystemRoot}\System32\drivers\etc\hosts"
}
