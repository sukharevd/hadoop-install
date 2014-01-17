#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

# reverse_ip_against_prefix 10.8.9.1 10.8 myVar => myVar=1.9
function reverse_ip_against_prefix {
    local ip=$1
    local prefix=$2
    local direct_ip_sufix=`echo "$ip" | awk -F "$prefix" '{print $2}'`
    local num=`echo "$direct_ip_sufix" | awk -F . '{print NF}'`
    eval "$3=`for i in $(seq $num -1 1); do echo "$direct_ip_sufix" | awk -F . '{printf $'$i'}'; if [ $i -ne 1 ]; then printf '.'; fi; done`"
}

apt-get update && apt-get -y install bind9 dnsutils

case "$1" in
  master)

cat > /etc/bind/named.conf.local << "EOF"
/* A master reverse zone */
zone "${DNS_REVERSE_ZONE}" {
  type master;
  file "/etc/bind/${DNS_REVERSE_ZONE}";
  allow-update { none; };
  allow-transfer { ${SECONDARY_DNS}; };
};

/* A master zone */
zone "${DNS_ZONE}" {
  type master;
  file "/etc/bind/${DNS_ZONE}";
  allow-update { none; };
  allow-transfer { ${SECONDARY_DNS}; };
};

include "/etc/bind/zones.rfc1918";
EOF
sed -i -e 's,${SECONDARY_DNS},'$SECONDARY_DNS',g' /etc/bind/named.conf.local
sed -i -e 's,${DNS_REVERSE_ZONE},'$DNS_REVERSE_ZONE',g' /etc/bind/named.conf.local
sed -i -e 's,${DNS_ZONE},'$DNS_ZONE',g' /etc/bind/named.conf.local


cat > /etc/bind/named.conf.options << "EOF"
options {
	directory "/var/cache/bind";

	// If there is a firewall between you and nameservers you want
	// to talk to, you may need to fix the firewall to allow multiple
	// ports to talk.  See http://www.kb.cert.org/vuls/id/800113

	// If your ISP provided one or more IP addresses for stable 
	// nameservers, you probably want to use them as forwarders.  
	// Uncomment the following block, and insert the addresses replacing 
	// the all-0's placeholder.

	forwarders {
		${DNS_GATEWAY_IP};
	};
	// allow-notify { 10.8.0.2; };


	//========================================================================
	// If BIND logs error messages about the root key being expired,
	// you will need to update your keys.  See https://www.isc.org/bind-keys
	//========================================================================
	dnssec-validation auto;

	auth-nxdomain no;    # conform to RFC1035
	listen-on-v6 { any; };
};
EOF
sed -i -e 's,${DNS_GATEWAY_IP},'$DNS_GATEWAY_IP',g' /etc/bind/named.conf.options

cat > /etc/bind/$DNS_REVERSE_ZONE << "EOF"
$TTL 3600

${DNS_REVERSE_ZONE}. IN SOA ns1.${DNS_ZONE}. admin.${DNS_ZONE}. (
     2014011101   ; Serial
     300          ; Refresh
     60           ; Retry
     604800       ; Expire
     3600         ; Minimum
)

     IN    NS     ns1.${DNS_ZONE}.
     IN    NS     ns2.${DNS_ZONE}.

${HADOOP_NAMENODE_IP}  IN    PTR    ${HADOOP_NAMENODE}.${DNS_ZONE}.
${HADOOP_SECONDARY_NAMENODE_IP}  IN    PTR    ${HADOOP_SECONDARY_NAMENODE}.${DNS_ZONE}.
${HADOOP_RESOURCEMANAGER_IP}  IN    PTR    ${HADOOP_SECONDARY_NAMENODE}.${DNS_ZONE}.

EOF
sed -i -e 's,${DNS_REVERSE_ZONE},'$DNS_REVERSE_ZONE',g' /etc/bind/$DNS_REVERSE_ZONE
sed -i -e 's,${DNS_ZONE},'$DNS_ZONE',g' /etc/bind/$DNS_REVERSE_ZONE
sed -i -e 's,${HADOOP_NAMENODE},'$HADOOP_NAMENODE',g' /etc/bind/$DNS_REVERSE_ZONE
sed -i -e 's,${HADOOP_SECONDARY_NAMENODE},'$HADOOP_SECONDARY_NAMENODE',g' /etc/bind/$DNS_REVERSE_ZONE
reverse_ip_against_prefix $HADOOP_NAMENODE_IP $DNS_NEW_CLIENT_IP_PREFIX rev_namenode_ip
reverse_ip_against_prefix $HADOOP_SECONDARY_NAMENODE_IP $DNS_NEW_CLIENT_IP_PREFIX rev_secondary_ip
reverse_ip_against_prefix $HADOOP_RESOURCEMANAGER_IP $DNS_NEW_CLIENT_IP_PREFIX rev_rman_ip
sed -i -e 's,${HADOOP_NAMENODE_IP},'$rev_namenode_ip',g' /etc/bind/$DNS_REVERSE_ZONE
sed -i -e 's,${HADOOP_SECONDARY_NAMENODE_IP},'$rev_secondary_ip',g' /etc/bind/$DNS_REVERSE_ZONE
sed -i -e 's,${HADOOP_RESOURCEMANAGER_IP},'$rev_rman_ip',g' /etc/bind/$DNS_REVERSE_ZONE

cat > /etc/bind/${DNS_ZONE} << "EOF"
$TTL 3600
${DNS_ZONE}. IN SOA ns1.${DNS_ZONE} admin.${DNS_ZONE}. (
            2014011101           ; Serial in format YYYYMMDDVV
            300                  ; Refresh
            60                   ; Retry
            604800               ; Expire
            3600                 ; Minimum TTL
)

; DNS servers
            IN NS ns1.${DNS_ZONE}.
            IN NS ns2.${DNS_ZONE}.

; MX records
            IN MX 10 smtp.${DNS_ZONE}.

            IN A ${DNS_NS1}

; Machine Names
ns1         IN A ${DNS_NS1}
ns2         IN A ${DNS_NS2}

smtp        IN A ${SMTP_IP}
${PRIMARY_OPENVPN}     IN A ${PRIMARY_OPENVPN_IP}

${HADOOP_NAMENODE}             IN A ${HADOOP_NAMENODE_IP}
${HADOOP_SECONDARY_NAMENODE}   IN A ${HADOOP_SECONDARY_NAMENODE_IP}
${HADOOP_RESOURCEMANAGER}      IN A ${HADOOP_RESOURCEMANAGER_IP}
EOF
sed -i -e 's,${DNS_ZONE},'$DNS_ZONE',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${DNS_NS1},'$DNS_NS1',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${DNS_NS2},'$DNS_NS2',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${HADOOP_NAMENODE},'$HADOOP_NAMENODE',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${HADOOP_NAMENODE_IP},'$HADOOP_NAMENODE_IP',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${HADOOP_SECONDARY_NAMENODE},'$HADOOP_SECONDARY_NAMENODE',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${HADOOP_SECONDARY_NAMENODE_IP},'$HADOOP_SECONDARY_NAMENODE_IP',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${HADOOP_RESOURCEMANAGER},'$HADOOP_RESOURCEMANAGER',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${HADOOP_RESOURCEMANAGER_IP},'$HADOOP_RESOURCEMANAGER_IP',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${PRIMARY_OPENVPN_IP},'$PRIMARY_OPENVPN_IP',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${PRIMARY_OPENVPN},'`echo $PRIMARY_OPENVPN | awk -F ".${DNS_ZONE}" '{print $1}'`',g' /etc/bind/${DNS_ZONE}
sed -i -e 's,${SMTP_IP},'$SMTP_IP',g' /etc/bind/${DNS_ZONE}
;;

  slave)

cat > /etc/bind/named.conf.local << "EOF"
/* A slave reverse zone */
zone "${DNS_REVERSE_ZONE}" {
    type slave;
    allow-update-forwarding { ${PRIMARY_DNS}; };
    allow-notify { ${PRIMARY_DNS}; };
    masters { ${PRIMARY_DNS}; };
};

/* A slave zone */
zone "${DNS_ZONE}" {
    type slave;
    allow-update-forwarding { ${PRIMARY_DNS}; };
    allow-notify { ${PRIMARY_DNS}; };
    masters { ${PRIMARY_DNS}; };
};

include "/etc/bind/zones.rfc1918";
EOF
sed -i -e 's,${PRIMARY_DNS},'$PRIMARY_DNS',g' /etc/bind/named.conf.local
sed -i -e 's,${DNS_ZONE},'$DNS_ZONE',g' /etc/bind/named.conf.local
sed -i -e 's,${DNS_REVERSE_ZONE},'$DNS_REVERSE_ZONE',g' /etc/bind/named.conf.local

cat > /etc/bind/named.conf.options << "EOF"
options {
	directory "/var/cache/bind";

	// If there is a firewall between you and nameservers you want
	// to talk to, you may need to fix the firewall to allow multiple
	// ports to talk.  See http://www.kb.cert.org/vuls/id/800113

	// If your ISP provided one or more IP addresses for stable 
	// nameservers, you probably want to use them as forwarders.  
	// Uncomment the following block, and insert the addresses replacing 
	// the all-0's placeholder.

	forwarders {
		${DNS_GATEWAY_IP};
	};
	allow-notify { ${PRIMARY_DNS}; };


	//========================================================================
	// If BIND logs error messages about the root key being expired,
	// you will need to update your keys.  See https://www.isc.org/bind-keys
	//========================================================================
	dnssec-validation auto;

	auth-nxdomain no;    # conform to RFC1035
	listen-on-v6 { any; };
};
EOF
sed -i -e 's,${DNS_GATEWAY_IP},'$DNS_GATEWAY_IP',g' /etc/bind/named.conf.options
sed -i -e 's,${PRIMARY_DNS},'$PRIMARY_DNS',g' /etc/bind/named.conf.options
;;

  *)
      echo "Usage: bash install-dns.sh master|slave"
      ;;

esac

service bind9 reload
