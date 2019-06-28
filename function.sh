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

function create_setting_file {
    
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

function set_kernel_variable {
    sysctl net.mptcp.mptcp_debug=1
    sysctl net.mptcp.mptcp_enabled=1
    #sysctl net.core.default_qdisc=${qdisc}
    sysctl net.mptcp.mptcp_no_small_queue=${no_small_queue}
    sysctl net.mptcp.mptcp_change_small_queue=${change_small_queue}
    sysctl net.mptcp.mptcp_no_cwr=${no_cwr}
    if [ $mptcp_ver = 0.86 ]; then
        sysctl net.mptcp.mptcp_no_recvbuf_auto=$no_rcv
        sysctl net.core.netdev_debug=0
        sysctl net.mptcp.mptcp_cwnd_log=1
    fi

    
}
    
function set_netem_rtt_and_loss {
    
    ssh root@${D1_ip} "./tc.sh 0 `expr ${rtt1[$j]} / 2` 0 && ./tc.sh 1 `expr ${rtt1[$j]} / 2` ${loss[$l]}" > /dev/null
    ssh root@${D2_ip} "./tc.sh 0 `expr ${rtt2[$m]} / 2` 0 && ./tc.sh 1 `expr ${rtt2[$m]} / 2` ${loss[$l]}" > /dev/null
    
}

function clean_log_sender_and_receiver {
    ssh root@${receiver_ip} "echo > /var/log/kern.log" > /dev/null
    echo > /var/log/kern.log
	find /var/log/ -type f -name \* -exec cp -f /dev/null {} \;
}

function set_txqueuelen {
    
    ifconfig ${eth0} txqueuelen ${queue[$k]}
    ifconfig ${eth1} txqueuelen ${queue[$k]}
}

function run_iperf {
    local app_i 
    local delay
    for app_i in `seq ${app}` 
    do
		delay=`echo "scale=5; $duration + ($app - $app_i) * $app_delay " | bc`
		if [ $app_i = $app ]; then  # When final app launch
			iperf -c ${receiver_ip} -t $delay -i $interval > ./${nowdir}/${i}th/throughput/app${app_i}.dat
		else
			iperf -c ${receiver_ip} -t $delay -i $interval > ./${nowdir}/${i}th/throughput/app${app_i}.dat &
			sleep $app_delay
		fi
	done
}

function format_and_copy_log {
    
    awk '{
        if(NR==1){
            if(NF==0){
                start=2;     
            }else{
                start=1;     
            } 
        }
        if(NF<1){
            next;
        }
        if(length($6)!=1){
            time=substr($6, 2, length($6)-1);
            flg=0
        }else{
            time=substr($7, 1, length($7)-1);
            flg=1
        };
        if(NR==start){
            f_time=time;
        }
        
        printf time-f_time" ";
        for(i=7+flg; i<=NF; i++){
            printf $i" "
        }
        print ""
    }' /var/log/kern.log > ./${nowdir}/${i}th/log/kern.dat
    
}

function separate_cwnd {
     awk '{
    if($11 ~ "cwnd="){
        if(NF == 18){
            printf("%s %s %s %s %s %s %s %s %s",$1,$5,$6,$8,$9,$11,$12,$17,$18)
        }else if(NF == 13){
            printf("%s %s %s %s %s %s %s %s",$1,$5,$6,$8,$9,$11,$12,$13)
        }else{
            printf("%s %s %s %s %s %s %s %s %s %s",$1,$5,$6,$8,$9,$11,$12,$17,$18,$19)
        }
        
    }else if($10 ~ "cwnd="){
	    if(NF == 18){
            printf("%s %s %s %s %s %s %s %s %s %s",$1,$4,$5,$7,$8,$10,$11,$16,$17,$18)
        }

    }else{
        next
    }
    print ""
    }' ./log/kern.dat > ./log/cwnd.dat
}

function get_app_meta {
    local app_i
    awk '{
        if($5 ~ "meta="){
            array[$6]++   
        }
    }END{
        for(i in array){
            printf("%s %d\n",i,array[i])
        }    
    }' ./log/kern.dat > ./log/app.dat

    sort -k2nr ./log/app.dat > ./log/app_sort.dat
    mv ./log/app_sort.dat ./log/app.dat

    #上からappの数だけ取り出す
    awk -v app=${app} '{
        if(FNR <= app){
            print $0
        }
    }' ./log/app.dat > ./log/app_num_order.dat


    for app_i in `seq ${app}` 
    do
        app[$app_i]=$(awk -v n=${app_i} '{
            if(NR==n){
                print $1
            }    
        }' ./log/app_num_order.dat)

    done

    # 時間順に並べ替える
    echo -n > ./log/app_time_order.dat
    for app_i in `seq ${app}` 
    do
        awk -v meta=${app[$app_i]} '{
            if($3 == meta){
                printf("%s %s\n",$3,$1);
                exit;
             }
        }' ./log/cwnd.dat >> ./log/app_time_order.dat
    done

    sort -k2g ./log/app_time_order.dat > ./log/app_sort.dat
    mv ./log/app_sort.dat ./log/app_time_order.dat

    awk -v app=${app} '{
        if(FNR <= app){
            print $1
        }
    }' ./log/app_time_order.dat > ./log/app_exp.dat

    for app_i in `seq ${app}` 
    do
        app_meta[$app_i]=$(awk -v n=${app_i} '{
            if(NR==n){
                print $1
            }    
        }' ./log/app_exp.dat)

    done

}

function extract_cwnd_each_flow {
    local app_i 
    for app_i in `seq ${app}` 
    do
        awk -v meta=${app_meta[$app_i]} '{
            if(meta==$3){
                print $0
            }
        }' ./log/cwnd.dat > ./log/cwnd${app_i}.dat
        

        awk '{
            if($4 ~ "pi="){
                array[$5]++   
            }
            }END{
            for(i in array){
                printf("%s %d\n",i,array[i])
            }    
        }' ./log/cwnd${app_i}.dat > ./log/app${app_i}_subflow.dat

        sort -k2nr ./log/app${app_i}_subflow.dat > ./log/app${app_i}_subflow_sort.dat
        mv ./log/app${app_i}_subflow_sort.dat ./log/app${app_i}_subflow.dat

    done


    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            subflowid=$(awk -v n=${subflow_i} '{
                if(NR==n){
                    print $1
                }    
            }' ./log/app${app_i}_subflow.dat)

            awk -v subf=${subflowid} '{
                if(subf==$5){
                    print $0
                }
            }' ./log/cwnd${app_i}.dat > ./log/cwnd${app_i}_subflow${subflow_i}.dat
        done
    done

   
}

function split_log {
    local cgn_ctrl_var  
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local app_meta=()
    cd $today
    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for rtt1_var in "${rtt1[@]}"
        do
            for rtt2_var in "${rtt2[@]}"
            do
                for loss_var in "${loss[@]}"
                do
                    for queue_var in "${queue[@]}"
                    do
                        for repeat_i in `seq ${repeat}` 
                        do
                            targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                            echo $targetdir
                            cd $targetdir
                            separate_cwnd
                            get_app_meta
                            extract_cwnd_each_flow
                        done 
                    done    
                done
            done
        done
    done



}
