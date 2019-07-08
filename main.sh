#!/bin/bash
umask 000
clear

cwd=`dirname $0`
cd $cwd
if [ -e "function.sh" ]; then
    source "function.sh"
else
    echo "function.sh does not exist."
    exit
fi

if [ $# -eq 1 ]; then
    memo=$1
    configfile="config.sh"
elif [ $# -eq 2 ]; then
    memo=$1
    configfile=$2
else
    usage_exit 
fi

if [ -e "${configfile}" ]; then
    source "${configfile}"
else
    echo "${configfile} does not exist."
    exit
fi

kernel=$(uname -r)
mptcp_ver=$(get_mptcp_version)
configure_ip_address $mptcp_ver
check_network_available

rcvkernel=$(ssh root@${receiver_ip} 'uname -r')

today=$(date "+%Y%m%d_%H-%M-%S")
nowdir=$today
mkdir ${today}
cp -f ${configfile} ${today}/config.sh
cd ${today}
mkdir -p tex/img

ip link set dev ${eth0} multipath on
ip link set dev ${eth1} multipath on

ethtool -s ${eth0} speed ${band1} duplex full
ethtool -s ${eth1} speed ${band2} duplex full

set_default_kernel_parameter
set_user_kernel_parameter

time=`echo "scale=5; ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * ($duration+60) * $repeat " | bc`
echo "終了予想時刻 `date --date "$time seconds"`"

for cgn_ctrl_var in "${cgn_ctrl[@]}" 
do
	sysctl net.ipv4.tcp_congestion_control=${cgn_ctrl_var}
    for rtt1_var in "${rtt1[@]}"
	do
        for rtt2_var in "${rtt2[@]}"
		do
            for loss_var in "${loss[@]}"
			do
                set_netem_rtt_and_loss
				if [ $rtt1_var != $rtt2_var ]; then
					break
					
				fi	
                for queue_var in "${queue[@]}"
				do
					
                    set_txqueuelen
					nowdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
					mkdir ${nowdir}
						
                    for repeat_i in `seq ${repeat}` 
					do
						mkdir ${nowdir}/${repeat_i}th
						mkdir ${nowdir}/${repeat_i}th/log
						mkdir ${nowdir}/${repeat_i}th/throughput

						echo -n "${cgn_ctrl_var}_RTT1=${rtt1_var}ms, RTT2=${rtt2_var}ms, LOSS=${loss_var}, queue=${queue_var}pkt, ${repeat_i}回目 ..."

                        clean_log_sender_and_receiver
                        run_iperf
						format_and_copy_log
                        echo "done"
					done
				done
			done
		done
	done
done

process_log_data
join_header_and_tex_file
build_tex_to_pdf


sysctl net.mptcp.mptcp_debug=0
umask 022

date
