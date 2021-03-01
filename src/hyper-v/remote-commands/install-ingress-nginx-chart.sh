#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# values: https://github.com/kubernetes/ingress-nginx/blob/master/charts/ingress-nginx/values.yaml
helm upgrade -i hvk8s-ingress-nginx \
    --set controller.service.externalIPs[0]=172.31.0.100 \
    ingress-nginx/ingress-nginx --wait
