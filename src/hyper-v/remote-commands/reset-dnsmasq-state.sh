#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

sudo systemctl stop dnsmasq
sudo rm -f rm /var/lib/misc/dnsmasq.leases
sudo systemctl start dnsmasq
