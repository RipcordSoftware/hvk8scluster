#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

curl https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz -o /tmp/helm.tar.gz

cd /tmp
tar xf helm.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
