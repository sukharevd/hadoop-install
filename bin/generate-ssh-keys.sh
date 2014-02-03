#!/bin/bash

if [ -z $1 ]; then
  echo "This script requires parameter: username"
  exit 1
fi


if [ -z $2 ]; then
    if [ -z $1 ] || [ -z `grep "^$1:" /etc/passwd` ] || [ ! -d /home/$1 ]; then
      echo "This script requires parameter: username"
      exit 1
    fi

    output_dir=/home/$1/.ssh
    su -l $1 -c "rm -rf $output_dir/*"
    su -l $1 -c "ssh-keygen -b 4096 -t rsa -P '' -f $output_dir/id_rsa"
    su -l $1 -c "cat $output_dir/id_rsa.pub > $output_dir/authorized_keys"
else
    if [ -d $2 ]; then
        output_dir=$2
    else
        echo 'Wrong optional parameter: output directory'
        exit 1
    fi
    rm -rf $output_dir/*
    ssh-keygen -b 4096 -t rsa -P '' -f $output_dir/id_rsa -C $1
    cat $output_dir/id_rsa.pub > $output_dir/authorized_keys
fi
