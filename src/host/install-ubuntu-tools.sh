#!/usr/bin/env bash

if [ $EUID -ne 0 ]; then
    echo "Error: you must run this script as su or under sudo"
    exit 1
fi

apt-get update && \
apt-get install -y xorriso genisoimage