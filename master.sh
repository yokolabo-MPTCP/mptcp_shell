#!/bin/bash -u
umask 000
clear

trap "kill 0" SIGINT # Ctrl-Cを押されたときの処理

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
check_exist_extended_parameter

kernel=$(uname -r)
#check_network_available

rcvkernel=$(ssh root@${sender1_ip} "ssh root@${receiver_ip} 'uname -r'")

today=$(date "+%Y%m%d_%H-%M-%S")
rootdir=${today}_${memo}

init_sender
make_directory
send_command "make_directory" "bg"
send_command "get_mptcp_version" "bg"
send_command "set_kernel_parameter" "bg"
send_command "set_qdisc" "bg"

get_sender_and_ne_status_and_scp

mptcp_ver=$(get_mptcp_version_master)

cp -f ${configfile} ${rootdir}/default.conf

cd ${rootdir}

get_user_name_and_rewrite_config

echo_finish_time
echo_data_byte
echo_disk_space

total_time=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * ($duration) * $repeat " | bc`
total_time_i=`echo "scale=1; $total_time + $total_process_time " | bc`
SECONDS=0
for cgn_ctrl_var in "${cgn_ctrl[@]}" 
do
    send_command "set_sysctl net.ipv4.tcp_congestion_control ${cgn_ctrl_var}" "bg"
    for extended_var in "${extended_parameter[@]}" 
    do
        send_command "set_extended_function ${extended_var}" "bg"
        for loss_var in "${loss[@]}"
        do
            for rtt1_var in "${rtt1[@]}"
            do
                for rtt2_var in "${rtt2[@]}"
                do
                    check_rtt_combination || continue 
                    
                    for queue_var in "${queue[@]}"
                    do
                        sender_set_netem_rtt_and_loss
                        send_command "set_txqueuelen ${queue_var}"
                        for repeat_i in `seq ${repeat}` 
                        do
                        
                            echo -ne "${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目 ...\r"

                            write_and_send_now_parameter
                            send_command "clean_log_sender_and_receiver" "bg"
                            #start 1-2-3
                            #run_iperf_multi_sender
                            
                            #start 2-1&3
                            run_iperf_multi_sender_2_13
                            
                            send_command "format_and_copy_log"
                        done
                    done
				done
			done
		done
	done
done
exptime=$SECONDS
echo "通信時間: $exptime"
calc_used_disk_space

SECONDS=0
send_command "process_log_data" "bg"
send_command "create_graph_and_tex" "bg"
send_command "join_header_and_tex_file" "bg"
send_command "build_tex_to_pdf" "bg"

slavetime=$SECONDS
echo "処理時間[Slave]: $slavetime"
if [ $sender_num != 1 ]; then
    process_throughput_master
    process_alldata_master
    create_graph_and_tex_master
    join_header_and_tex_file
    build_tex_to_pdf
fi

receive_all_data_pdf

send_command "delete_and_compress_processed_log_data" "bg"
#delete_and_compress_processed_log_data

exptime=$SECONDS
echo "処理時間[Total]: $exptime"
calc_used_disk_space2

umask 022

date
exit
