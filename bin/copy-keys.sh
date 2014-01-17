#!/bin/bash

if [ -z $1 ] || [ -z `grep "^$1:" /etc/passwd` ] || [ -z $2 ]; then
  echo "This script requires two parameters: username, host-to-copy-from"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

echo "registering remote host as known host"
# TODO and here as well
su -l $1 -c "ssh-keyscan -H $2 > /home/$1/.ssh/known_hosts"

echo "Stealing keys from remote host"
su -l $1 -c "scp -r $1@$2:/home/$1/.ssh /home/$1"

status=$?
if [ $status -ne 0 ]; then
    echo "Couldn't log in to $1@$2."
    exit 0
fi

echo "registering localhost as known host"
su -l $1 -c "ssh-keyscan -H localhost >> ~/.ssh/known_hosts"
su -l $1 -c "ssh-keyscan -H 127.0.0.1 >> ~/.ssh/known_hosts"
su -l $1 -c "ssh-keyscan -H ::1 >> ~/.ssh/known_hosts"

echo "registering masters as known hosts"
su -l $1 -c "ssh-keyscan -H $HADOOP_NAMENODE_FQDN >> ~/.ssh/known_hosts"
su -l $1 -c "ssh-keyscan -H $HADOOP_SECONDARY_NAMENODE_FQDN >> ~/.ssh/known_hosts"
su -l $1 -c "ssh-keyscan -H $HADOOP_RESOURCEMANAGER_FQDN >> ~/.ssh/known_hosts"

# TODO the problem with this approach is that known_host might have a lot of duplicative records in cases when namenode == secondary == resourcemanager
echo "registering me as known host for masters"
su -l $1 -c "ssh $HADOOP_NAMENODE_FQDN ssh-keyscan -H $2 >> ~/.ssh/known_hosts"
su -l $1 -c "ssh $HADOOP_SECONDARY_NAMENODE_FQDN ssh-keyscan -H $2 >> ~/.ssh/known_hosts"
su -l $1 -c "ssh $HADOOP_RESOURCEMANAGER_FQDN ssh-keyscan -H $2 >> ~/.ssh/known_hosts"
