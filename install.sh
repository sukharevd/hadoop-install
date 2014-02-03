#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/bin/hadoop-install.conf

case "$1" in
    dns-primary)
                bash $SCRIPT_DIR/bin/install-dns.sh master
                ;;
    dns-secondary)
                bash $SCRIPT_DIR/bin/install-dns.sh slave
                ;;
    openvpn)
                bash $SCRIPT_DIR/bin/install-vpn.sh
                ;;
    namenode)
                bash $SCRIPT_DIR/bin/install-hadoop-host.sh $HADOOP_NAMENODE
                ;;
#    secondary)
#                bash $SCRIPT_DIR/bin/install-hadoop-host.sh $HADOOP_SECONDARY_NAMENODE
#                ;;
    resource-manager)
                bash $SCRIPT_DIR/bin/install-hadoop-host.sh $HADOOP_RESOURCEMANAGER
                ;;
    slave)
                bash $SCRIPT_DIR/bin/install-hadoop-host.sh
                ;;
    *)
                echo 'Usage: bash install.sh (dns-primary|dns-secondary|openvpn|namenode'
                echo '       |resource-manager|slave)'
                exit 1
                ;;
esac
