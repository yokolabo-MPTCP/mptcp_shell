#!/bin/bash -u

umask 000

cwd=`dirname $0`
cd $cwd

if [ -e "function.sh" ]; then
    source "function.sh"
else
    echo "function.sh does not exist."
    exit
fi

source rootdir.txt
if [ -e "default.conf" ]; then
    source default.conf
    check_exist_extended_parameter 
fi
kernel=$(uname -r)

rcv_command=$1

if [ "${rcv_command}" = "make_directory" ]; then
    make_directory
    cp default.conf ${rootdir}/default.conf

elif [ "${rcv_command}" = "get_mptcp_version" ]; then
    mptcp_ver=$(get_mptcp_version)
    echo "mptcp_ver=${mptcp_ver}" >> default.conf
elif [ "${rcv_command}" = "set_sysctl" ]; then
    sysctl_name=$2
    parameter=$3

    sysctl ${sysctl_name}=${parameter}
elif [ "${rcv_command}" = "set_kernel_parameter" ]; then
    set_kernel_parameter

elif [ "${rcv_command}" = "set_qdisc" ]; then
    set_qdisc
elif [ "${rcv_command}" = "set_extended_function" ]; then
    extended_var=$2
    extended_function ${extended_var}
elif [ "${rcv_command}" = "set_netem_rtt_and_loss" ]; then
    rtt1_var=$2
    rtt2_var=$3
    loss_var=$4
    set_netem_rtt_and_loss
elif [ "${rcv_command}" = "set_txqueuelen" ]; then
    queue_var=$2
    set_txqueuelen
elif [ "${rcv_command}" = "clean_log_sender_and_receiver" ]; then
    clean_log_sender_and_receiver
elif [ "${rcv_command}" = "run_iperf" ]; then
    duration=$2
    source now_parameter.txt
    
    cd ${rootdir}
    
    run_iperf 

elif [ "${rcv_command}" = "format_and_copy_log" ]; then
    source now_parameter.txt
    cd ${rootdir}
    format_and_copy_log
elif [ "${rcv_command}" = "process_log_data" ]; then
    cd ${rootdir}
    process_log_data
elif [ "${rcv_command}" = "create_graph_and_tex" ]; then
    cd ${rootdir}
    create_graph_and_tex
elif [ "${rcv_command}" = "join_header_and_tex_file" ]; then
    cd ${rootdir}
    join_header_and_tex_file
elif [ "${rcv_command}" = "build_tex_to_pdf" ]; then
    cd ${rootdir}
    build_tex_to_pdf
elif [ "${rcv_command}" = "delete_and_compress_processed_log_data" ]; then
    cd ${rootdir}
    delete_and_compress_processed_log_data
fi

umask 022

exit
