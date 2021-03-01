#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

helm repo add bitnami https://charts.bitnami.com/bitnami

# values: https://github.com/bitnami/charts/blob/master/bitnami/metallb/values.yaml
helm upgrade -i \
    --set configInline.address-pools[0].name=generic-cluster-pool \
    --set configInline.address-pools[0].protocol=layer2 \
    --set configInline.address-pools[0].addresses[0]=172.31.0.100-172.31.0.200 \
    hvk8s-metallb bitnami/metallb --version 2.3.2 --wait
