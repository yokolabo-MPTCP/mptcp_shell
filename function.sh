#!/bin/bash

function get_mptcp_version () {

    local kernel=$(uname -r)

    case "$kernel" in
            "3.5.7" ) mptcp_ver=0.86 ;;
            "3.10.17" ) mptcp_ver=0.87 ;;
            "3.11.10" ) mptcp_ver=0.88 ;;
            "3.14.33" ) mptcp_ver=0.89 ;;
            "3.18.43" ) mptcp_ver=0.90 ;;
            "4.1.39" ) mptcp_ver=0.91 ;;
            "4.4.88" ) mptcp_ver=0.92 ;;
            * ) mptcp_ver=unknown ;;
    esac

    echo "$mptcp_ver"

}

function configure_ip_address(){
    local mptcp_ver=$1

    if [ $mptcp_ver = 0.92 ]; then
        receiver_ip=192.168.15.2
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=eth0
        eth1=eth1
        make_tex=1 #true : 1 , false : 0
     elif [ $mptcp_ver = 0.86 ]; then
        receiver_ip=192.168.13.1
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=eth0
        eth1=eth1
        make_tex=1 #true : 1 , false : 0
        no_small_queue=1
    else
        receiver_ip=192.168.13.1
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=eth0
        eth1=eth1
        make_tex=1 #true : 1 , false : 0
    fi

}

function create_setting_file{

    
    echo "Date ${today}" > setting.txt
    echo "sender_kernel ${kernel}" >> setting.txt
    echo "receiver_kernel ${rcvkernel}" >> setting.txt
    echo "mptcp_ver ${mptcp_ver}" >> setting.txt
    echo "conguestion_control ${cgn_ctrl[@]}" >> setting.txt
    echo "qdisc ${qdisc}" >> setting.txt
    echo "app ${app}" >> setting.txt
    echo "rtt1 ${rtt1[@]}" >> setting.txt
    echo "rtt2 ${rtt2[@]}" >> setting.txt
    echo "loss ${loss[@]}" >> setting.txt
    echo "queue ${queue[@]}" >> setting.txt
    echo "duration ${duration}" >> setting.txt
    echo "sleep ${sleep}" >> setting.txt
    echo "repeat ${repeat}" >> setting.txt
    echo "interval ${interval}" >> setting.txt
    echo "no_cwr ${no_cwr}" >> setting.txt
    echo "no_rcv ${no_rcv}" >> setting.txt
    echo "no_small_queue ${no_small_queue}" >> setting.txt
    echo "qdisc ${qdisc}" >> setting.txt
    echo "num_subflow ${num_subflow}" >> setting.txt
    echo "memo ${memo}" >> setting.txt


}
