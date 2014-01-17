#!/bin/bash

if [ -z $1 ] || [ -z `grep "^$1:" /etc/passwd` ] || [ ! -d /home/$1 ]; then
  echo "This script requires parameter: username"
  exit 1
fi

su -l $1 -c "rm -rf /home/$1/.ssh/*"
su -l $1 -c "ssh-keygen -b 4096 -t rsa -P '' -f /home/$1/.ssh/id_rsa"
su -l $1 -c "cat /home/$1/.ssh/id_rsa.pub > /home/$1/.ssh/authorized_keys"
