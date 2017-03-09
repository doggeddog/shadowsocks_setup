#!/bin/sh
#
# Script for automatic setup of an IPsec VPN server on CentOS/RHEL 6 and 7.
# Works on any dedicated server or Virtual Private Server (VPS) except OpenVZ.
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC!
#
# The latest version of this script is available at:
# https://github.com/hwdsl2/setup-ipsec-vpn
#
# Copyright (C) 2015-2017 Lin Song <linsongui@gmail.com>
# Based on the work of Thomas Sarlandie (Copyright 2012)
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 3.0
# Unported License: http://creativecommons.org/licenses/by-sa/3.0/
#
# Attribution required: please include my name in any derivative and let me
# know how you have improved it!

# =====================================================

# Define your own values for these variables
SS_CONF='{
    "server":"0.0.0.0",
    "server_port":8802,
    "local_port":8803,
    "password":"passwd",
    "timeout":600,
    "method":"aes-256-cfb"
}'

# Important notes:   https://git.io/vpnnotes
# Setup VPN clients: https://git.io/vpnclients

# =====================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
SYS_DT="$(date +%Y-%m-%d-%H:%M:%S)"; export SYS_DT

exiterr()  { echo "Error: $1" >&2; exit 1; }
exiterr2() { echo "Error: 'yum install' failed." >&2; exit 1; }
conf_bk() { /bin/cp -f "$1" "$1.old-$SYS_DT" 2>/dev/null; }
bigecho() { echo; echo "## $1"; echo; }

check_ip() {
  IP_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
  printf %s "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

if ! grep -qs -e "release 6" -e "release 7" /etc/redhat-release; then
  exiterr "This script only supports CentOS/RHEL 6 and 7."
fi


if [ "$(id -u)" != 0 ]; then
  exiterr "Script must be run as root. Try 'sudo sh $0'"
fi

NET_IF0=${VPN_IFACE:-'eth0'}
NET_IFS=${VPN_IFACE:-'eth+'}
if_state=$(cat "/sys/class/net/$NET_IF0/operstate" 2>/dev/null)
if [ -z "$if_state" ] || [ "$if_state" = "down" ] || [ "$NET_IF0" = "lo" ]; then
  echo "Error: Network interface '$NET_IF0' is not available." >&2
cat 1>&2 <<'EOF'

DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC!

If running on a server, try this workaround:

VPN_IFACE="$(route | grep '^default' | grep -o '[^ ]*$')"
EOF
cat 1>&2 <<EOF
sudo VPN_IFACE="\$VPN_IFACE" sh "$0"
EOF
  exit 1
fi

bigecho "Shadowsocks setup in progress... Please be patient."

# Create and change to working dir
mkdir -p /opt/src
cd /opt/src || exiterr "Cannot enter /opt/src."

bigecho "Installing packages required for setup..."

yum -y install wget python-pip || exiterr2
pip install shadowsocks || exiterr

bigecho "Trying to auto discover IP of this server..."

cat <<'EOF'
In case the script hangs here for more than a few minutes,
use Ctrl-C to interrupt. Then edit it and manually enter IP.
EOF

# In case auto IP discovery fails, enter server's public IP here.
PUBLIC_IP=${VPN_PUBLIC_IP:-''}

# Try to auto discover IP of this server
[ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(dig @resolver1.opendns.com -t A -4 myip.opendns.com +short)

# Check IP for correct format
check_ip "$PUBLIC_IP" || PUBLIC_IP=$(wget -t 3 -T 15 -qO- http://ipv4.icanhazip.com)
check_ip "$PUBLIC_IP" || exiterr "Cannot find valid public IP. Edit the script and manually enter it."

# Create Shadowsocks config
echo $SS_CONF > /etc/shadowsocks.conf 

bigecho "Enabling services on boot..."

cat >> /etc/rc.local <<'EOF'

# Added by Shadowsocks script
ssserver -c /etc/shadowsocks.conf -d start

EOF


bigecho "Starting services..."

ssserver -c /etc/shadowsocks.conf -d start

cat <<EOF

================================================

IPsec Shadowsocks server is now ready for use!

Connect to your new Shadowsocks with these details:

Server IP: $PUBLIC_IP
Server Conf: $SS_CONF

Write these down. You'll need them to connect!

Important notes:   https://git.io/vpnnotes
Setup VPN clients: https://git.io/vpnclients

================================================

EOF

exit 0
