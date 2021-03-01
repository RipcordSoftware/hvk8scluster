###############################################################################
# Installs PostgreSQL into the Kubernetes cluster with Helm
# requires:
# - a valid ~/.kube/config file
# - a running cluster with MetalLB
# - a running cluster with Rook/Ceph (for rook-ceph-block)
# - helm.exe
# - kubectl.exe (to recover the password)

$ErrorActionPreference = "Stop"

helm repo add bitnami https://charts.bitnami.com/bitnami
if (!$?) {
    Write-Error "Unable to add the bitnami repository to helm"
}

helm repo update
if (!$?) {
    Write-Error "Unable to update the bitnami repository"
}

# values: https://github.com/bitnami/charts/blob/master/bitnami/postgresql/values.yaml
helm upgrade -i `
    --set global.storageClass=rook-ceph-block `
    --set service.type=LoadBalancer `
    --version 10.3.7 `
    hvk8s-postgresql bitnami/postgresql
