#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

#if [ -z "`dpkg-query -l openssh 2> /dev/null | grep '^ii '`" ]; then
#    apt-get install openssh
#fi

apt-get -y install openvpn openssl ssh vim sudo resolvconf ntp

#init-known-hosts.sh

bash $SCRIPT_DIR/install-hadoop.sh

mkdir -p /home/$YARN_USER/.ssh
mkdir -p /home/$HDFS_USER/.ssh
mkdir -p /home/$MAPRED_USER/.ssh
mkdir -p /home/$HADOOP_USER/.ssh
cp -r $SCRIPT_DIR/../ssh/$YARN_USER/.ssh /home/$YARN_USER
cp -r $SCRIPT_DIR/../ssh/$HDFS_USER/.ssh /home/$HDFS_USER
cp -r $SCRIPT_DIR/../ssh/$MAPRED_USER/.ssh /home/$MAPRED_USER
cp -r $SCRIPT_DIR/../ssh/$HADOOP_USER/.ssh /home/$HADOOP_USER
chmod -R 700 /home/$YARN_USER/.ssh
chmod -R 700 /home/$HDFS_USER/.ssh
chmod -R 700 /home/$MAPRED_USER/.ssh
chmod -R 700 /home/$HADOOP_USER/.ssh
chown -R $YARN_USER /home/$YARN_USER/.ssh
chown -R $HDFS_USER /home/$HDFS_USER/.ssh
chown -R $MAPRED_USER /home/$MAPRED_USER/.ssh
chown -R $HADOOP_USER /home/$HADOOP_USER/.ssh

my_dns_record=`wget --no-check-certificate --private-key $SCRIPT_DIR/../openssl/client/client.key --certificate $SCRIPT_DIR/../openssl/client/client.crt "https://$PRIMARY_DNS:$PRIMARY_DNS_PORT/domain-names/add?hostname=$1" -O - | tail -n1`
if [ $? -ne 0 ]; then
    echo 'Error'
    exit 1
fi
hostname=`echo "$my_dns_record" | awk '{print $1}'`
ip=`echo "$my_dns_record" | awk '{print $2}'`
if [ -z "$hostname" ]; then hostname=$1; fi
echo "Obtained hostname: $hostname"
echo "Obtained IP: $ip"

#if [ -z `grep ".*127.0.1.1.*$DNS_ZONE" /etc/hosts` ]; then
    sed -i -e 's/^.*127.0.1.1.*$/127.0.1.1    '$hostname'.'$DNS_ZONE' '$hostname'/g' /etc/hosts
    echo "$hostname" > /etc/hostname
    invoke-rc.d hostname.sh start
#fi

wget --no-check-certificate --private-key $SCRIPT_DIR/../openssl/client/client.key --certificate $SCRIPT_DIR/../openssl/client/client.crt "https://$PRIMARY_OPENVPN_IP:$PRIMARY_OPENVPN_PORT/vpn-clients/add?hostname=$hostname&ip=$ip" -O $hostname.tar.gz
if [ $? -ne 0 ]; then
    echo 'Error'
    exit 1
fi
tar -xzf $hostname.tar.gz
mv ca.crt $hostname.{key,crt,conf} /etc/openvpn
service openvpn restart

sleep 15

bash $SCRIPT_DIR/share-ssh-keys.sh $YARN_USER  $hostname.$DNS_ZONE
bash $SCRIPT_DIR/share-ssh-keys.sh $HDFS_USER  $hostname.$DNS_ZONE
bash $SCRIPT_DIR/share-ssh-keys.sh $MAPRED_USER $hostname.$DNS_ZONE
bash $SCRIPT_DIR/share-ssh-keys.sh $HADOOP_USER $hostname.$DNS_ZONE

if [[ $1 == 'namenode' ]]; then
    service hadoop format
    bash $SCRIPT_DIR/install-cherrypy-service.sh $SCRIPT_DIR/cherrypy-namenode.py
    bash $SCRIPT_DIR/install-nginx.sh $HADOOP_NAMENODE_FQDN $HADOOP_NAMENODE_PORT `$SCRIPT_DIR/cherrypy-namenode.py port`
else
    [[ $1 != "HADOOP_SECONDARY_NAMENODE" ]] && [[ $1 != "$HADOOP_RESOURCEMANAGER" ]] &&
    wget --no-check-certificate --private-key $SCRIPT_DIR/../openssl/client/client.key --certificate $SCRIPT_DIR/../openssl/client/client.crt "https://$HADOOP_NAMENODE_FQDN:$HADOOP_NAMENODE_PORT/hadoop_slaves/add?host=$hostname.$DNS_ZONE" -O -
    #echo "$hostname" > $HADOOP_CONF_DIR/slaves
fi
service hadoop start
