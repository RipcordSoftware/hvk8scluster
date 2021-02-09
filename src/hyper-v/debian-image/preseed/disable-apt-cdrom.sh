#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

sed -i "/^deb cdrom:/s/^/#/" /etc/apt/sources.list
