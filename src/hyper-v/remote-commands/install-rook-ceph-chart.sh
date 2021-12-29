#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

# the Rook/Ceph chart version
# WARNING: before updating the version the rook-ceph-cluster values items cephFileSystems and cephObjectStores
# must be sync'd to match the rook-ceph-cluster/values.yaml of the new version, the placement sections should
# be re-added to the updated YAML
CHART_VERSION=1.8.1

helm repo add rook-release https://charts.rook.io/release

# Operator
# see: https://github.com/rook/rook/blob/release-1.8/deploy/charts/rook-ceph/values.yaml
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
# see: https://github.com/rook/rook/blob/release-1.8/deploy/charts/rook-ceph-cluster/values.yaml
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

cephFileSystems:
  - name: ceph-filesystem
    spec:
      metadataPool:
        replicated:
          size: 3
      dataPools:
        - failureDomain: host
          replicated:
            size: 3
      metadataServer:
        activeCount: 1
        activeStandby: true
        placement:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: kubernetes.io/os
                  operator: In
                  values:
                  - linux
    storageClass:
      enabled: true
      isDefault: false
      name: ceph-filesystem
      reclaimPolicy: Delete
      allowVolumeExpansion: true
      mountOptions: []
      parameters:
        csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
        csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
        csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
        csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
        csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
        csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
        csi.storage.k8s.io/fstype: ext4

cephObjectStores:
  - name: ceph-objectstore
    spec:
      metadataPool:
        failureDomain: host
        replicated:
          size: 3
      dataPool:
        failureDomain: host
        erasureCoded:
          dataChunks: 2
          codingChunks: 1
      preservePoolsOnDelete: true
      gateway:
        port: 80
        instances: 1
        placement:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: kubernetes.io/os
                  operator: In
                  values:
                  - linux
      healthCheck:
        bucket:
          interval: 60s
    storageClass:
      enabled: true
      name: ceph-bucket
      reclaimPolicy: Delete
      parameters:
        region: us-east-1
EOF

helm upgrade -i \
    -n rook-ceph \
    --create-namespace \
    --version ${CHART_VERSION} \
    -f rook-ceph-cluster.values.yaml \
    rook-ceph-cluster rook-release/rook-ceph-cluster
