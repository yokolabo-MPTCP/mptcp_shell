#!/bin/bash -u

eth0=enp0s31f6      # NIC name
eth1=enp2s0

eth0_nw=192.168.3.0 # network
eth1_nw=192.168.4.0

eth0_ip=192.168.3.1 # IP address
eth1_ip=192.168.4.1

eth0_gw=192.168.3.2 # Gateway IP address
eth1_gw=192.168.4.2

band1=100           # bandwidth
band2=100

function check_root_user {
	if [ $(whoami) != "root" ]; then
		echo "Permission denied"
		echo "Please run as root user"
		exit	
	fi	
}

check_root_user

echo "sysctl settings"
sysctl -w net.ipv4.tcp_no_metrics_save=1
sysctl -w net.core.wmem_max=21290148
sysctl -w net.core.rmem_max=21290148
sysctl -w net.core.wmem_default=32768
sysctl -w net.core.rmem_default=65536
sysctl -w net.core.optmem_max=28386864
sysctl -w net.ipv4.tcp_mem="8192 98302 42580296"
sysctl -w net.ipv4.tcp_wmem="4094 32768 21290148"
sysctl -w net.ipv4.tcp_rmem="4094 65536 21290148"
sysctl -w net.ipv4.tcp_slow_start_after_idle=0
sysctl -w net.ipv4.tcp_frto=0
sysctl -w net.ipv4.tcp_ecn=0
sysctl net.mptcp.mptcp_debug=0

service network-manager stop
service networking start

echo "add ip address"
ip addr add ${eth0_ip}/24 dev ${eth0}
ip addr add ${eth1_ip}/24 dev ${eth1} 

echo "interface settings"

ethtool -s ${eth0} speed ${band1} duplex full
ethtool -s ${eth1} speed ${band2} duplex full

ethtool -K ${eth0} rx off tso off tx off
ethtool -K ${eth1} rx off tso off tx off

echo "routing settings"

ip rule add from ${eth0_ip} table 1
ip rule add from ${eth1_ip} table 2

ip route add ${eth0_nw}/24 dev ${eth0} scope link table 1
ip route add default via ${eth0_gw} dev ${eth0} table 1

ip route add ${eth1_nw}/24 dev ${eth1} scope link table 2
ip route add default via ${eth1_gw} dev ${eth1} table 2

ip route add default scope global nexthop via ${eth0_gw} dev ${eth0}


