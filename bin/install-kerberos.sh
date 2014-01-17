#!/bin/bash

#https://help.ubuntu.com/12.04/serverguide/openldap-server.html
#https://help.ubuntu.com/12.04/serverguide/kerberos-ldap.html

dns_record="127.0.0.1 $KERBEROS_FQDN"
[ `grep "$dns_record" /etc/hosts | wc -l` -eq 0 ] && echo $dns_record >> /etc/hosts

REALM=$(echo "$DNS_ZONE" | tr '[:lower:]' '[:upper:]')
LDAPROOT=""; IFS="."; for DC in $DNS_ZONE ; do LDAPROOT="${LDAPROOT},dc=$DC"; done;
LDAPROOT="${LDAPROOT#,}"

DEBIAN_FRONTEND=noninteractive apt-get install ntp krb5-{admin-server,kdc}
#  ldap-utils slapd  krb5-kdc-ldap krb5-doc libnss-ldap nscd libpam-ldap \
#  gnutls-bin ssl-cert ntp pwgen rpl

cat > /etc/krb5.conf << "EOF"
[realms]
    ${REALM} = {
        kdc = ${KERBEROS_FQDN}:88
        admin_server = ${KERBEROS_FQDN}:749
        default_domain = ${DNS_ZONE}
    }

[domain_realm]
    .${DNS_ZONE} = ${REALM}
    ${DNS_ZONE} = ${REALM}

[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = false

[kdc]
    profile = /etc/krb5kdc/kdc.conf

[logging]
    default = FILE:/var/log/kerberos/krb5libs.log
    kdc = FILE:/var/log/kerberos/krb5kdc.log
    admin_server = FILE:/var/log/kerberos/kadmind.log
EOF
sed -i -e 's,${KERBEROS_FQDN},'$KERBEROS_FQDN',g' /etc/krb5.conf
sed -i -e 's,${DNS_ZONE},'$DNS_ZONE',g' /etc/krb5.conf
sed -i -e 's,${REALM},'$REALM',g' /etc/krb5.conf

mkdir /var/log/kerberos
touch /var/log/kerberos/krb5libs.log
touch /var/log/kerberos/krb5kdc.log
touch /var/log/kerberos/kadmind.log

sed -i -e 's,EXAMPLE.COM,'$REALM',g' /etc/krb5kdc/kdc.conf



# LDAP
DEBIAN_FRONTEND=noninteractive apt-get install slapd ldap-utils

cat <<EOF >/tmp/ldappwd
dn: olcDatabase={1}hdb,cn=config
replace: olcRootPW
EOF
slappasswd -s secret >> /tmp/ldappwd # http://ubuntuforums.org/showthread.php?t=1054966  # not secure, maybe clear history
ldapmodify -v -Y EXTERNAL -H ldapi:/// -f /tmp/ldappwd
