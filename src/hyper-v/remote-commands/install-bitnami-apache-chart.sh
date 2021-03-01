#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

helm repo add bitnami https://charts.bitnami.com/bitnami

# values: https://github.com/bitnami/charts/blob/master/bitnami/apache/values.yaml
helm upgrade -i \
    --set ingress.enabled=true \
    --set ingress.hostname=www.hvk8s.com \
    --set service.type=ClusterIP \
    --set ingress.annotations.kubernetes\\.io/ingress\\.class=nginx \
    --set ingress.tls="" \
    www-hvk8s-com-apache bitnami/apache --version 8.3.0 --wait
