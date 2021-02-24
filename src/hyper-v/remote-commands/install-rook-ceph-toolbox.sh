#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

if [ ! -d "code/rook" ]; then
    echo "Error: the rook repository is not present, unable to continue"
    exit 1
fi

cd code/rook/cluster/examples/kubernetes/ceph
kubectl apply -f toolbox.yaml
