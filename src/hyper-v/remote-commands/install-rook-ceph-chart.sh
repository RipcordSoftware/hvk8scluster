#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

helm repo add rook-release https://charts.rook.io/release

if [ ! $(kubectl get ns rook-ceph) ]; then
    kubectl create namespace rook-ceph
fi

helm upgrade -i --namespace rook-ceph rook-ceph rook-release/rook-ceph
