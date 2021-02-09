#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

HVK8S_HOME=/home/hvk8s
HVK8S_SSH=$HVK8S_HOME/.ssh

mkdir -p $HVK8S_SSH
cp -f /tmp/preseed/id_rsa.pub $HVK8S_SSH/authorized_keys
chmod 600 $HVK8S_SSH/authorized_keys
chown -R hvk8s:hvk8s $HVK8S_SSH

echo "hvk8s ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
