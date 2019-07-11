#!/bin/bash -u

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


echo "add ip address"
ip addr add 192.168.3.1/24 dev enp0s31f6
ip addr add 192.168.4.1/24 dev enp2s0 

echo "interface settings"

ethtool -s enp0s31f6 speed 100 duplex full
ethtool -s enp2s0 speed 100 duplex full

ethtool -K enp0s31f6 rx off tso off tx off
ethtool -K enp2s0 rx off tso off tx off

echo "routing settings"

ip rule add from 192.168.3.1 table 1
ip rule add to 192.168.13.0/24 table 1
ip rule add from 192.168.4.1 table 2
ip rule add to 192.168.14.0/24 table 2

ip route add 192.168.3.0/24 dev enp0s31f6 scope link table 1
ip route add default via 192.168.3.2 dev enp0s31f6 table 1

ip route add 192.168.4.0/24 dev enp2s0 scope link table 2
ip route add default via 192.168.4.2 dev enp2s0 table 2

ip route add 192.168.15.0/24 dev enp0s31f6

ip route add default scope global nexthop via 192.168.13.1 dev enp0s31f6
ip route add default scope global nexthop via 192.168.14.1 dev enp2s0

service network-manager stop
service networking start

