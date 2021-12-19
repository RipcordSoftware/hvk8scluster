#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

CHART_VERSION=1.8.1

helm repo add rook-release https://charts.rook.io/release

# Operator
# see: https://github.com/rook/rook/blob/release-1.7/cluster/charts/rook-ceph/values.yaml
cat <<EOF > rook-ceph.values.yaml
nodeSelector:
  "kubernetes.io/os": linux
discover:
  nodeAffinity: kubernetes.io/os=linux
csi:
  provisionerNodeAffinity: kubernetes.io/os=linux
  pluginNodeAffinity: kubernetes.io/os=linux
  rbdProvisionerNodeAffinity: kubernetes.io/os=linux
  rbdPluginNodeAffinity: kubernetes.io/os=linux
  cephFSProvisionerNodeAffinity: kubernetes.io/os=linux
  cephFSPluginNodeAffinity: kubernetes.io/os=linux
agent:
  nodeAffinity: kubernetes.io/os=linux
admissionController:
  nodeAffinity: kubernetes.io/os=linux
EOF

helm upgrade -i \
    -n rook-ceph \
    --create-namespace \
    --version ${CHART_VERSION} \
    -f rook-ceph.values.yaml \
    --wait \
    rook-ceph rook-release/rook-ceph

# Cluster
# see: https://github.com/rook/rook/blob/release-1.7/cluster/charts/rook-ceph-cluster/values.yaml
cat <<EOF > rook-ceph-cluster.values.yaml
toolbox:
  enabled: true
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
cephClusterSpec:
  dashboard:
    enabled: false
  crashCollector:
    disable: true
  placement:
    all:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/os
              operator: In
              values:
              - linux
EOF

helm upgrade -i \
    -n rook-ceph \
    --create-namespace \
    --version ${CHART_VERSION} \
    -f rook-ceph-cluster.values.yaml \
    rook-ceph-cluster rook-release/rook-ceph-cluster
