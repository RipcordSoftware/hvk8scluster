#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

echo -e \
"domain=hvk8s.local\n"\
"dhcp-range=172.31.0.10,172.31.0.200,24h\n"\
"dhcp-option=option:router,172.31.0.1\n"\
"dhcp-host=hvk8s-gateway,172.31.0.1,infinite\n"\
"dhcp-host=hvk8s-dhcp-dns,172.31.0.2,infinite\n"\
"dhcp-host=hvk8s-master,172.31.0.10,infinite\n"\
"dhcp-host=hvk8s-node1,172.31.0.11,infinite\n"\
"dhcp-host=hvk8s-node2,172.31.0.12,infinite\n"\
"dhcp-host=hvk8s-node3,172.31.0.13,infinite\n"\
"dhcp-host=hvk8s-node4,172.31.0.14,infinite\n"\
"dhcp-host=hvk8s-node5,172.31.0.15,infinite\n"\
"dhcp-host=hvk8s-node6,172.31.0.16,infinite\n"\
"dhcp-host=hvk8s-node7,172.31.0.17,infinite\n"\
"dhcp-host=hvk8s-node8,172.31.0.18,infinite\n"\
"dhcp-host=hvk8s-node9,172.31.0.19,infinite\n"\
"dhcp-host=hvk8s-node10,172.31.0.20,infinite\n"\
"dhcp-host=hvk8s-node11,172.31.0.21,infinite\n"\
"dhcp-host=hvk8s-node12,172.31.0.22,infinite\n"\
"dhcp-host=hvk8s-node13,172.31.0.23,infinite\n"\
"dhcp-host=hvk8s-node14,172.31.0.24,infinite\n"\
"dhcp-host=hvk8s-node15,172.31.0.25,infinite\n"\
"dhcp-host=hvk8s-node16,172.31.0.26,infinite\n"\
"dhcp-host=hvk8s-node17,172.31.0.27,infinite\n"\
"dhcp-host=hvk8s-node18,172.31.0.28,infinite\n"\
"dhcp-host=hvk8s-node19,172.31.0.29,infinite" >> /etc/dnsmasq.conf
