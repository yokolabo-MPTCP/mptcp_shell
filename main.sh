#!/bin/bash -u
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
check_argument $@
check_root_user
check_exist_config_file

kernel=$(uname -r)
mptcp_ver=$(get_mptcp_version)
check_network_available
set_kernel_parameter

rcvkernel=$(ssh root@${receiver_ip} 'uname -r')

today=$(date "+%Y%m%d_%H-%M-%S")
rootdir=${today}_${memo}

make_directory

cp -f ${configfile} ${rootdir}/default.conf

cd ${rootdir}

get_user_name_and_rewrite_config
set_qdisc

echo_finish_time
echo_data_byte

for cgn_ctrl_var in "${cgn_ctrl[@]}" 
do
	sysctl net.ipv4.tcp_congestion_control=${cgn_ctrl_var}
    for loss_var in "${loss[@]}"
    do
        for rtt1_var in "${rtt1[@]}"
        do
            for rtt2_var in "${rtt2[@]}"
            do
                
                set_netem_rtt_and_loss
				if [ $rtt1_var != $rtt2_var ]; then
					continue
					
				fi	
                for queue_var in "${queue[@]}"
				do
                    set_txqueuelen
                    for repeat_i in `seq ${repeat}` 
					do
					
						echo -n "${cgn_ctrl_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目 ..."

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
