cat >>/etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

sysctl -p

sysctl net.ipv4.tcp_available_congestion_control

echo lsmod
lsmod | grep bbr
