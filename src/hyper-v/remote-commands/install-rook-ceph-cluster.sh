#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

if [ ! -d "code" ]; then
    mkdir -p code
    cd code
    git clone --single-branch --branch release-1.5 --depth 1 https://github.com/rook/rook.git
    cd rook/cluster/examples/kubernetes/ceph
    kubectl apply -f cluster.yaml
    cd csi/rbd
    kubectl apply -f storageclass.yaml
fi
