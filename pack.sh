#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/bin/hadoop-install.conf

echo 'Generating keys for client authentication, putting them to openssl directory...'
bash $SCRIPT_DIR/bin/generate-https-keys.sh client client

tar -czf - -C $SCRIPT_DIR/.. hadoop-install/ > hadoop-install.min.tar.gz

echo 'Generating ssh keys, adding to authorized_keys, putting to ssh directory...'
[ -e $SCRIPT_DIR/ssh ] && rm -rf $SCRIPT_DIR/ssh
mkdir -p $SCRIPT_DIR/ssh/$YARN_USER/.ssh
mkdir -p $SCRIPT_DIR/ssh/$HDFS_USER/.ssh
mkdir -p $SCRIPT_DIR/ssh/$MAPRED_USER/.ssh
mkdir -p $SCRIPT_DIR/ssh/$HADOOP_USER/.ssh
bash $SCRIPT_DIR/bin/generate-ssh-keys.sh $YARN_USER $SCRIPT_DIR/ssh/$YARN_USER/.ssh
bash $SCRIPT_DIR/bin/generate-ssh-keys.sh $HDFS_USER $SCRIPT_DIR/ssh/$HDFS_USER/.ssh
bash $SCRIPT_DIR/bin/generate-ssh-keys.sh $MAPRED_USER $SCRIPT_DIR/ssh/$MAPRED_USER/.ssh
bash $SCRIPT_DIR/bin/generate-ssh-keys.sh $HADOOP_USER $SCRIPT_DIR/ssh/$HADOOP_USER/.ssh

echo 'Downloading Hadoop, putting it to dist directory...'
if [ ! -e "$SCRIPT_DIR/../dist/$HADOOP_FILENAME" ]; then
    echo "Downloading: $HADOOP_ADDRESS..."
    [ ! -e $SCRIPT_DIR/dist ] && mkdir $SCRIPT_DIR/dist
    wget -q $HADOOP_ADDRESS -O $SCRIPT_DIR/dist/$HADOOP_FILENAME
    if [ $? -ne 0 ]; then
        echo "Not possible to download Hadoop."
        exit 1
    fi
else
    echo 'No need to download Apache Hadoop archive.'
fi

tar -czf - -C $SCRIPT_DIR/.. hadoop-install/ > hadoop-install.full.tar.gz
