#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

bash $SCRIPT_DIR/install-cherrypy-service.sh $SCRIPT_DIR/cherrypy-namenode.py
bash $SCRIPT_DIR/install-nginx.sh $HADOOP_NAMENODE_FQDN $HADOOP_NAMENODE_PORT `$SCRIPT_DIR/cherrypy-namenode.py port`
