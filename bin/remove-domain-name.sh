#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

# TODO duplication
function update_serial {
    file=$1
    if [ `egrep "^[[:space:]]*[0-9]+[[:space:]]*;[[:space:]]*Serial" $file | wc -l` -gt 1 ]; then
        echo "$file has more than 1 Serial"
        exit 500
    fi
    
    before=`egrep "^[[:space:]]*[0-9]+[[:space:]]*;[[:space:]]*Serial" $file | awk -F "[0-9]+" '{print $1}'`
    after=`egrep "^[[:space:]]*[0-9]+[[:space:]]*;[[:space:]]*Serial" $file | awk -F "[0-9]+" '{print $2}'`
    # I'm not gonna have numbers in comments
    serial=`egrep "^[[:space:]]*[0-9]+[[:space:]]*;[[:space:]]*Serial" $file | awk -F "$after" '{print $1}' | awk -F "$before" '{print $2}'`
    today=`date +%Y%m%d`

    if [[ $serial == $today* ]]; then
        new_serial=$((serial+1))
    else
        new_serial=$today"01"
    fi
    sed -i -e 's,'$serial','$new_serial',g' $file
}

if [ -z $1 ] || [ -z $2 ]; then
  echo "This script requires two parameters (hostname,ip)"
  exit 400
fi

hostname=$1
ip=$2

if [ ! -z $ip ]; then
    grep -v "IN A ${ip//\./\\.}$" /etc/bind/$DNS_ZONE > /tmp/$DNS_ZONE;
    mv /tmp/$DNS_ZONE /etc/bind/$DNS_ZONE
fi

if [ ! -z $hostname ]; then
    grep -v "  IN    PTR    ${hostname//\./\\.}.${DNS_ZONE//\./\\.}$" /etc/bind/$DNS_REVERSE_ZONE > /tmp/$DNS_REVERSE_ZONE;
    mv /tmp/$DNS_REVERSE_ZONE /etc/bind/$DNS_REVERSE_ZONE
fi

update_serial /etc/bind/$DNS_ZONE
update_serial /etc/bind/$DNS_REVERSE_ZONE

service bind9 reload
