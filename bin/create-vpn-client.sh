#!/bin/bash

# TODO what about existing openvpn keys and configs
# TODO what if there's already user with the specified client-name/ip?

if [ -z $1 ] || [ -z $2 ]; then
  echo "This script requires two parameter (client name,vpn-ip)"
  exit 1
fi

CLIENT_NAME=$1
VPN_IP=$2

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf


function check_ipv4 {
    if [ -z $1 ]; then
      echo "This should never happen"
      exit 1
    fi
    if [ -z `echo $1 | awk "/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/"` ]; then
      echo "IP should contain four integers separated by dot signs"
      exit 1
    fi
    for p in `seq 1 4`; do
      if [ "0" == `echo $1 | awk -F '.' "{print ($"$p"<256)}"` ]; then
        echo "Wrong IP address: wrong part $p"
        exit 1
      fi
    done
    echo "Verified IP address: $1"
}

check_ipv4 $VPN_IP

sed -i -e 's, --interact , ,g' /etc/openvpn/easy-rsa/2.0/build-key

cd /etc/openvpn/easy-rsa/2.0/
echo "Initializing variables..."
. /etc/openvpn/easy-rsa/2.0/vars
echo "Building client's private key..."
KEY_CN="$CLIENT_NAME" KEY_NAME="$CLIENT_NAME" . /etc/openvpn/easy-rsa/2.0/build-key $CLIENT_NAME
cd $SCRIPT_DIR

chmod 600 -R /etc/openvpn/easy-rsa/2.0/keys


cat > /etc/openvpn/easy-rsa/2.0/keys/$CLIENT_NAME.conf << "EOF"
##############################################
# Sample client-side OpenVPN 2.0 config file #
# for connecting to multi-client server.     #
#                                            #
# This configuration can be used by multiple #
# clients, however each client should have   #
# its own cert and key files.                #
#                                            #
# On Windows, you might want to rename this  #
# file so it has a .ovpn extension           #
##############################################

# Specify that we are a client and that we
# will be pulling certain config file directives
# from the server.
client

# Use the same setting as you are using on
# the server.
# On most systems, the VPN will not function
# unless you partially or fully disable
# the firewall for the TUN/TAP interface.
;dev tap
dev tun
topology subnet

# Windows needs the TAP-Win32 adapter name
# from the Network Connections panel
# if you have more than one.  On XP SP2,
# you may need to disable the firewall
# for the TAP adapter.
;dev-node MyTap

# Are we connecting to a TCP or
# UDP server?  Use the same setting as
# on the server.
proto ${OPENVPN_PROTOCOL}
;proto udp

# The hostname/IP and port of the server.
# You can have multiple remote entries
# to load balance between the servers.
remote ${PRIMARY_OPENVPN_IP} ${OPENVPN_PORT}
;remote my-server-2 1194

# Choose a random host from the remote
# list for load-balancing.  Otherwise
# try hosts in the order specified.
;remote-random

# Keep trying indefinitely to resolve the
# host name of the OpenVPN server.  Very useful
# on machines which are not permanently connected
# to the internet such as laptops.
resolv-retry infinite

# Most clients don't need to bind to
# a specific local port number.
nobind

# Downgrade privileges after initialization (non-Windows only)
;user nobody
;group nogroup

# Try to preserve some state across restarts.
persist-key
persist-tun

# If you are connecting through an
# HTTP proxy to reach the actual OpenVPN
# server, put the proxy server/IP and
# port number here.  See the man page
# if your proxy server requires
# authentication.
;http-proxy-retry # retry on connection failures
;http-proxy [proxy server] [proxy port #]

# Wireless networks often produce a lot
# of duplicate packets.  Set this flag
# to silence duplicate packet warnings.
;mute-replay-warnings

# SSL/TLS parms.
# See the server config file for more
# description.  It's best to use
# a separate .crt/.key file pair
# for each client.  A single ca
# file can be used for all clients.
ca ca.crt
cert ${CLIENT_NAME}.crt
key ${CLIENT_NAME}.key

# Verify server certificate by checking
# that the certicate has the nsCertType
# field set to "server".  This is an
# important precaution to protect against
# a potential attack discussed here:
#  http://openvpn.net/howto.html#mitm
#
# To use this feature, you will need to generate
# your server certificates with the nsCertType
# field set to "server".  The build-key-server
# script in the easy-rsa folder will do this.
ns-cert-type server

# If a tls-auth key is used on the server
# then every client must also have the key.
;tls-auth ta.key 1

# Select a cryptographic cipher.
# If the cipher option is used on the server
# then you must also specify it here.
cipher AES-128-CBC    # AES

# Enable compression on the VPN link.
# Don't enable this unless it is also
# enabled in the server config file.
comp-lzo

# Set log file verbosity.
verb 3

# Silence repeating messages
;mute 20

# Update resolv.conf automatically when
# connecting to VPN. Don't forget to
# install resolvconf to make it work.
script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf
EOF
sed -i -e 's,${CLIENT_NAME},'$CLIENT_NAME',g' /etc/openvpn/easy-rsa/2.0/keys/$CLIENT_NAME.conf
sed -i -e 's,${OPENVPN_PORT},'$OPENVPN_PORT',g' /etc/openvpn/easy-rsa/2.0/keys/$CLIENT_NAME.conf
sed -i -e 's,${OPENVPN_PROTOCOL},'$OPENVPN_PROTOCOL',g' /etc/openvpn/easy-rsa/2.0/keys/$CLIENT_NAME.conf
sed -i -e 's,${PRIMARY_OPENVPN_IP},'$PRIMARY_OPENVPN_IP',g' /etc/openvpn/easy-rsa/2.0/keys/$CLIENT_NAME.conf

echo "ifconfig-push $VPN_IP $OPENVPN_NETWORK_MASK" > /etc/openvpn/ccd/$CLIENT_NAME

tar -cf - -C /etc/openvpn/easy-rsa/2.0/keys $CLIENT_NAME.{crt,key,conf} ca.crt > /etc/openvpn/easy-rsa/2.0/keys/$CLIENT_NAME.tar
chmod 600 -R /etc/openvpn/easy-rsa/2.0/keys
