#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

echo -e \
"domain=k8s.hvk8s.local\n"\
"dhcp-range=172.31.0.10,172.31.0.200,24h\n"\
"dhcp-option=option:router,172.31.0.1\n"\
"dhcp-host=k8s-master,172.31.0.10,infinite\n"\
"dhcp-host=k8s-node1,172.31.0.11,infinite\n"\
"dhcp-host=k8s-node2,172.31.0.12,infinite\n"\
"dhcp-host=k8s-node3,172.31.0.13,infinite\n"\
"dhcp-host=k8s-node4,172.31.0.14,infinite\n"\
"dhcp-host=k8s-node5,172.31.0.15,infinite\n"\
"dhcp-host=k8s-node6,172.31.0.16,infinite\n"\
"dhcp-host=k8s-node7,172.31.0.17,infinite\n"\
"dhcp-host=k8s-node8,172.31.0.18,infinite\n"\
"dhcp-host=k8s-node9,172.31.0.19,infinite" >> /etc/dnsmasq.conf
