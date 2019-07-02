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

# User Setting 

cgn_ctrl=(lia)          # congestion control e.g. lia olia balia wvegas cubic reno
rtt1=(50)               # delay of netem [ms]
rtt2=(50)               
loss=(0)                # Packet drop rate of netem [%]
queue=(100 1000)  # The number of IFQ size [packet]
duration=1            # Communication Time [s]
app_delay=0.5           # Time of start time difference [s]
repeat=2             # The number of repeat
app=3                   # The number of Application (iperf)
qdisc=pfifo_fast        # AQM (Active queue management) e.g. pfifo_fast red fq_codel
memo=$1

author="Izumi Daichi"
item_to_create_graph=(cwnd)
# Kernel variable

no_small_queue=1 #0:default 1:original
change_small_queue=10 #default:10



kernel=$(uname -r)
mptcp_ver=$(get_mptcp_version)
configure_ip_address $mptcp_ver
check_network_available

#fixed

interval=1
temp=0


band1=100
band2=100

subflownum=2

timeflag=1
clearpage=0



#reciver setting
receiver_dir="/home/yokolabo/experiment"



today=$(date "+%Y%m%d_%H-%M-%S")
rcvkernel=$(ssh root@${receiver_ip} 'uname -r')
nowdir=$today
mkdir ${today}
cd ${today}

time=`echo "scale=5; ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * $duration * $repeat " | bc`

date
date --date "$time seconds"

create_setting_file


echo "------SETTING---------------------------------"
cat setting.txt
tc qdisc show
echo "----------------------------------------------"



ip link set dev ${eth0} multipath on
ip link set dev ${eth1} multipath on

#ethtool -s ${eth0} speed ${band1} duplex full
#ethtool -s ${eth1} speed ${band2} duplex full

set_kernel_variable


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

						echo "${cgn_ctrl_var}_RTT1=${rtt1_var}ms, RTT2=${rtt2_var}ms, LOSS=${loss_var}, queue=${queue_var}pkt, ${repeat_i}回目"

                        clean_log_sender_and_receiver
                        						
                        sleep 0.5
                        run_iperf
												
						sleep 10
						killall iperf &> /dev/null
						sleep 10
						
						format_and_copy_log
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
sysctl net.mptcp.mptcp_enabled=1
umask 022

date
