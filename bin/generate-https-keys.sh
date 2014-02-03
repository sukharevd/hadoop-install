#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [ -z $1 ] || [ -z $2 ]; then
    echo "This script requires two parameters (type, keyname)"
    exit 1
fi

if [[ $1 != 'server' ]] && [[ $1 != 'client' ]]; then
    echo "First parameter should be either 'server' or 'client'."
    exit 1
fi

keyname=$2
type=$1

if [ ! -e $SCRIPT_DIR/../openssl/openssl.conf.template ]; then
    echo "Error. No openssl config template. Can't continue"
    exit 1
fi

if [ -z "`dpkg-query -l openssl 2> /dev/null | grep '^ii '`" ]; then
    apt-get install -y openssl
fi

[ ! -e $SCRIPT_DIR/../openssl/$type ] && mkdir -p $SCRIPT_DIR/../openssl/$type

#if [[ type == 'server' ]]; then
#    openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3560 -nodes -subj "/C=$OPENSSL_KEY_COUNTRY/ST=$OPENSSL_KEY_PROVINCE/L=$OPENSSL_KEY_CITY/O=$OPENSSL_KEY_ORG/CN=$OPENSSL_KEY_CN"
#    exit 0
#fi

cd $SCRIPT_DIR/../openssl/$type
cp $SCRIPT_DIR/../openssl/openssl.conf.template openssl.conf
sed -i -e 's,${OPENSSL_KEY_COUNTRY},'$OPENSSL_KEY_COUNTRY',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_PROVINCE},'$OPENSSL_KEY_PROVINCE',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_CITY},'$OPENSSL_KEY_CITY',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_ORG},'$OPENSSL_KEY_ORG',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_EMAIL},'$OPENSSL_KEY_EMAIL',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_SIZE},'$OPENSSL_KEY_SIZE',g' openssl.conf
sed -i -e 's,${OPENSSL_CA_EXPIRE},'$OPENSSL_CA_EXPIRE',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_EXPIRE},'$OPENSSL_KEY_EXPIRE',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_NAME},'$OPENSSL_KEY_NAME',g' openssl.conf
sed -i -e 's,${OPENSSL_KEY_CN},'$OPENSSL_KEY_CN',g' openssl.conf

[ ! -e private ] && mkdir private
[ ! -e certs   ] && mkdir certs
[ ! -e csr     ] && mkdir csr
[ ! -e serial  ] && echo '100001' > serial
[ ! -e certindex.txt ] && touch certindex.txt

if [ ! -e private/ca-$type.key ]; then
    openssl req -new -x509 -extensions v3_ca -keyout private/ca-$type.key \
        -out certs/ca-$type.crt -days $OPENSSL_CA_EXPIRE -config ./openssl.conf -batch -nodes
    # -nodes cancelled asking ca's passphase. Remove it if you want type passphase for signing certs.
fi

if [[ -e certs/$keyname.crt || -e private/$keyname.key ]]; then
    echo 'Keypair already exist.'
    exit 1
fi

sed -i -e 's,^commonName_default[[:space:]]*=.*$,commonName_default          = '$keyname',g' openssl.conf
openssl req -new -nodes -out csr/$keyname.csr -keyout private/$keyname.key \
            -config ./openssl.conf -batch
openssl ca -keyfile private/ca-$type.key -out certs/$keyname.crt -cert certs/ca-$type.crt \
           -config ./openssl.conf -batch -infiles csr/$keyname.csr

chmod 700 private csr
