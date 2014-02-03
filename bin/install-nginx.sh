#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ]; then
  echo "This script requires 3 parameters:"
  echo " * server's fqdn"
  echo " * external ip"
  echo " * internal ip"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

if [ -z "`dpkg-query -l nginx 2> /dev/null | grep '^ii '`" ]; then
    apt-get install -y nginx
fi

SERVER_NAME=$1
EXTERNAL_PORT=$2
INTERNAL_PORT=$3

[ ! -e $SCRIPT_DIR/../openssl/client/certs/ca-client.crt ] ||
[ ! -e $SCRIPT_DIR/../openssl/server/private/$SERVER_NAME.key ] ||
[ ! -e $SCRIPT_DIR/../openssl/server/certs/$SERVER_NAME.crt ] &&
bash $SCRIPT_DIR/generate-https-keys.sh server $SERVER_NAME

[ ! -e /etc/nginx/certs ] && mkdir /etc/nginx/certs
cp $SCRIPT_DIR/../openssl/client/certs/ca-client.crt /etc/nginx/certs/
cp $SCRIPT_DIR/../openssl/server/{private,certs}/$SERVER_NAME.* /etc/nginx/certs/
chmod 700 /etc/nginx/certs/*.key

cat > /etc/nginx/conf.d/${SERVER_NAME}.conf << "EOF"
server {
    listen        ${EXTERNAL_PORT};
    ssl on;
    server_name   ${SERVER_NAME};

    ssl_certificate      /etc/nginx/certs/${SERVER_NAME}.crt;
    ssl_certificate_key  /etc/nginx/certs/${SERVER_NAME}.key;
    ssl_client_certificate /etc/nginx/certs/ca-client.crt;
    ssl_verify_client optional;

    location / {
      proxy_pass        http://localhost:${INTERNAL_PORT};
      proxy_set_header  X-Real-IP  $remote_addr;
    }
}
EOF
sed -i -e 's,${SERVER_NAME},'$SERVER_NAME',g' /etc/nginx/conf.d/${SERVER_NAME}.conf
sed -i -e 's,${EXTERNAL_PORT},'$EXTERNAL_PORT',g' /etc/nginx/conf.d/${SERVER_NAME}.conf
sed -i -e 's,${INTERNAL_PORT},'$INTERNAL_PORT',g' /etc/nginx/conf.d/${SERVER_NAME}.conf

service nginx restart
