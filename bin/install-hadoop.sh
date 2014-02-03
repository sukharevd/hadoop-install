#!/bin/bash

# TODO: In most cases you should also specify HADOOP_PID_DIR and HADOOP_SECURE_DN_PID_DIR to point to directories that can only be written to by the users that are going to run the hadoop daemons. Otherwise there is the potential for a symlink attack.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

if [ -z $JAVA_HOME ]; then
    echo "JAVA_HOME wasn't found, installing OpenJDK7..."
    apt-get install -y openssh-server openjdk-7-jdk
    JAVA_HOME=/usr/lib/jvm/default-java
    ln -s /usr/lib/jvm/java-7-openjdk-amd64 $JAVA_HOME
    echo "export JAVA_HOME=$JAVA_HOME" > /etc/profile.d/java-home.sh
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile.d/java-home.sh
fi

echo "Adding users..."
[ -z `grep "^$HADOOP_USER:" /etc/passwd` ] && useradd -m -s /bin/bash $HADOOP_USER                  # TODO add function to check if user has valid homedir,shell,group,etc
[ -z `grep "^$MAPRED_USER:" /etc/passwd` ] && useradd -m -s /bin/bash -G $HADOOP_USER $MAPRED_USER
[ -z `grep "^$YARN_USER:" /etc/passwd`   ] && useradd -m -s /bin/bash -G $HADOOP_USER $YARN_USER
[ -z `grep "^$HDFS_USER:" /etc/passwd`   ] && useradd -m -s /bin/bash -G $HADOOP_USER $HDFS_USER

cd $INSTALL_DIR
echo "Cleaning up..."
[ -e $HADOOP_FULL_DIR ] && rm -r "$HADOOP_FULL_DIR"
[ -e $HADOOP_DIR      ] && rm -r "$HADOOP_DIR"

if [ -e "$SCRIPT_DIR/../dist/$HADOOP_FILENAME" ]; then
    cp $SCRIPT_DIR/../dist/$HADOOP_FILENAME $INSTALL_DIR/$HADOOP_FILENAME
fi

if [ ! -e "$HADOOP_FILENAME" ]; then
    echo "Downloading: $HADOOP_ADDRESS..."
    wget -q $HADOOP_ADDRESS -O $HADOOP_FILENAME
    if [ $? -ne 0 ]; then
        echo "Not possible to download Hadoop."
        exit 1
    fi
else
    echo 'No need to download archive.'
fi

echo "Installing..."
tar -xzf $HADOOP_FILENAME
if [ $? -ne 0 ]; then
    echo "Not possible to extract Hadoop archive."
    exit 1
fi
ln -s $HADOOP_FULL_DIR $HADOOP_DIR
chown -R $HADOOP_USER:$HADOOP_USER $HADOOP_DIR
chown -R $HADOOP_USER:$HADOOP_USER $HADOOP_DIR/

[ -e $HDFS_NAMENODE_DIR ] && rm -r $HDFS_NAMENODE_DIR
[ -e $HDFS_DATANODE_DIR ] && rm -r $HDFS_DATANODE_DIR
mkdir -p $HDFS_NAMENODE_DIR
mkdir -p $HDFS_DATANODE_DIR
chown -R $HDFS_USER:$HADOOP_USER $HDFS_NAMENODE_DIR
chown -R $HDFS_USER:$HADOOP_USER $HDFS_DATANODE_DIR
chown -R $HDFS_USER:$HADOOP_USER $HDFS_NAMENODE_DIR/
chown -R $HDFS_USER:$HADOOP_USER $HDFS_DATANODE_DIR/

[ -e $HADOOP_LOG_DIR   ] && rm -r $HADOOP_LOG_DIR
[ -e $YARN_LOG_DIR     ] && rm -r $YARN_LOG_DIR
[ -e $HADOOP_HOME/logs ] && rm -r $$HADOOP_HOME/logs
mkdir -p $HADOOP_LOG_DIR
mkdir -p $YARN_LOG_DIR
mkdir -p $HADOOP_HOME/logs
chown -R $HDFS_USER:$HADOOP_USER $HADOOP_LOG_DIR
chown -R $HDFS_USER:$HADOOP_USER $HADOOP_LOG_DIR/
chown -R $YARN_USER:$HADOOP_USER $YARN_LOG_DIR
chown -R $YARN_USER:$HADOOP_USER $YARN_LOG_DIR/
chown -R $MAPRED_USER:$HADOOP_USER $HADOOP_HOME/logs
chmod -R 775 $HADOOP_HOME/logs

echo "Configuring..."
# TODO only master should change configs, others should use rsync???
cd $SCRIPT_DIR
sed -e 's/${HADOOP_NAMENODE_FQDN}/'$HADOOP_NAMENODE_FQDN'/g' ../etc/hadoop/core-site.xml > $HADOOP_CONF_DIR/core-site.xml
sed -e 's,${REPLICATION_RATIO},'$REPLICATION_RATIO',g; s,${HDFS_NAMENODE_DIR},'$HDFS_NAMENODE_DIR',g; s,${HDFS_DATANODE_DIR},'$HDFS_DATANODE_DIR',g' ../etc/hadoop/hdfs-site.xml > $HADOOP_CONF_DIR/hdfs-site.xml
cp ../etc/hadoop/mapred-site.xml $HADOOP_CONF_DIR/mapred-site.xml
cp ../etc/hadoop/yarn-env.sh $HADOOP_CONF_DIR/yarn-env.sh # prefere ipv4
sed -e 's,${HADOOP_RESOURCEMANAGER_FQDN},'$HADOOP_RESOURCEMANAGER_FQDN',g' ../etc/hadoop/yarn-site.xml > $HADOOP_CONF_DIR/yarn-site.xml
sed -e 's,${JAVA_HOME},'$JAVA_HOME',g; s,${HADOOP_LOG_DIR},'$HADOOP_LOG_DIR',g; s,${YARN_LOG_DIR},'$YARN_LOG_DIR',g; ' ../etc/hadoop/hadoop-env.sh >  $HADOOP_CONF_DIR/hadoop-env.sh
sed -e 's,${JAVA_HOME},'$JAVA_HOME',g; s,${HADOOP_HOME},'$HADOOP_HOME',g; s,${HADOOP_CONF_DIR},'$HADOOP_CONF_DIR',g' ../etc/profile.d/hadoop.sh > /etc/profile.d/hadoop.sh
sed -i -e 's,${MAPRED_USER},'$MAPRED_USER',g; s,${YARN_USER},'$YARN_USER',g; s,${HDFS_USER},'$HDFS_USER',g' /etc/profile.d/hadoop.sh
sed -e 's,export ,,g' /etc/profile.d/hadoop.sh > /etc/default/hadoop
echo '' > $HADOOP_CONF_DIR/slaves


# TODO: move it somewhere
# sed -e -i '/s/^.*127.0.1.1.*$/127.0.1.1    '$hostname'.'$DNS_ZONE' '$hostname'/g' /etc/hosts
# echo "$hostname" > /etc/hostname
# invoke-rc.d hostname.sh start

## ssh connect to all hosts
## TODO add -oStrictHostKeyChecking=no  to 
## rsync
#
#cp vpn/{ca.crt,$HOSTNAME.crt,$HOSTNAME.key} /etc/openvpn/
#chmod 600 /etc/openvpn/$HOSTNAME.key
#/etc/openvpn/update-resolv-conf
#service openvpn restart
