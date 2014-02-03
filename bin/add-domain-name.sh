#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [ -z "`dpkg-query -l gawk 2> /dev/null`" ]; then
    apt-get install gawk
fi

# parses each partial IP from $existing as 4 byte integer and finds the greatest one
function max_id {
    if [ -z $2 ]; then
        existing=`egrep "[[:space:]]IN[[:space:]]+PTR[[:space:]]+" /etc/bind/$DNS_REVERSE_ZONE | gawk -F '[[:space:]]IN[[:space:]]+PTR[[:space:]]+' '{print $1}'`
    else
        existing=$2
    fi

    local max=0
    max_n=0
    for i in $existing; do
        local val=0
        local weight=1
        local n=`echo $i | awk -F . '{print NF}'`
        for j in `seq 1 $n`; do
            local dig=`echo $i | awk -F . '{print $'$j'}'`
            val=$((val+dig*weight))
            weight=$((weight*256))
        done
        if [ $max -lt $val ]; then
            max=$val
        fi
        if [ $max_n -lt $n ]; then
            max_n=$n
        fi
    done

    #local max_id=1
    #for i in `seq $max_n -1 1`
    #    max_id=$((max_id*256))
    #max_id=$((max_id-1))

    #if [[ ( $((next/256)) -eq $((n-1)) && $((next%256)) -eq 255 ) || ( $((next/256)) -gt $((n-1)) ) ]]; then
    #    echo "You reached the last IP of network (broadcast IP)."
    #    exit 1
    #fi
    
    eval "$1=$max"
}

function id_to_ip {
    # converts 4 byte integer of $max to IP representation.
    res=''
    var=$1
    n=0
    while [ $var -gt 0 ] || [ $n -lt $max_n ]; do
        if [ -z $res ]; then
            res=$((var%256))
        else
            res=$((var%256))"."$res
        fi
        var=$((var/256))
        n=$((n+1))
    done
    eval "$2=$DNS_NEW_CLIENT_IP_PREFIX$res"
}

# reverse_ip_against_prefix 10.8.9.1 10.8 myVar => myVar=1.9
function reverse_ip_against_prefix {
    local ip=$1
    local prefix=$2
    local direct_ip_sufix=`echo "$ip" | awk -F "$prefix" '{print $2}'`
    local num=`echo "$direct_ip_sufix" | awk -F . '{print NF}'`
    eval "$3=`for i in $(seq $num -1 1); do echo "$direct_ip_sufix" | awk -F . '{printf $'$i'}'; if [ $i -ne 1 ]; then printf '.'; fi; done`"
}

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

hostname=$1
ip=$2

if [ ! -z $ip ] && [[ $ip != $DNS_NEW_CLIENT_IP_PREFIX* ]]; then
    # TODO in general I can handle this situation creating new rev zone...
    #      let's left it for future
    echo "Your IP doesn't belong to this DNS server. Consider changing DNS_NEW_CLIENT_IP_PREFIX"
    exit 400
fi

if [ ! -z $ip ] && [ -z $hostname ]; then
    # works only for IP that starts with $DNS_NEW_CLIENT_IP_PREFIX
    reverse_ip_against_prefix $ip $DNS_NEW_CLIENT_IP_PREFIX rev
    max_id id $rev
    hostname=`printf "host%04d" "$id"`
fi

if [ -z $ip ]; then
    max_id id
    id=$((id+1))
    id_to_ip $id ip
    if [ -z $hostname ]; then
        hostname=`printf "host%04d" "$id"`
    fi
fi

reverse_ip_against_prefix $ip $DNS_NEW_CLIENT_IP_PREFIX rev

if [ ! -z "`egrep "^$hostname[[:space:]]+IN" /etc/bind/$DNS_ZONE`" ]; then
    echo "$hostname already exists"
    exit 400
fi

if [ ! -z "`egrep "^$rev[[:space:]]+IN" /etc/bind/$DNS_REVERSE_ZONE`" ]; then
    echo "$rev already exists in rev zone $DNS_REVERSE_ZONE"
    exit 400
fi

update_serial /etc/bind/$DNS_ZONE
update_serial /etc/bind/$DNS_REVERSE_ZONE

service bind9 reload
status=$?

echo "$hostname    IN A $ip" >> /etc/bind/$DNS_ZONE
echo "$rev  IN    PTR    $hostname.$DNS_ZONE." >> /etc/bind/$DNS_REVERSE_ZONE

echo "Added host:"
echo "$hostname $ip"
exit $status
