#!/bin/bash

function usage_exit() {

    echo "Usage: $0 \"[memo of this exp.]\""
    echo "Usage: $0 [memo of this exp.] [name of configfile(default:default.conf)]"
    exit

}

function check_argument {
    local args=$#
    if [ $args -eq 1 ]; then
        memo=$1
        configfile="default.conf"
        elif [ $args -eq 2 ]; then
        memo=$1
        configfile=$2
    else
        usage_exit 
    fi
}

function check_exist_config_file {
	if [ -e "${configfile}" ]; then
		source "${configfile}"
	else
		echo "${configfile} does not exist."
		exit
	fi
}

function check_root_user {
	if [ $(whoami) != "root" ]; then
		echo "Permission denied"
		echo "Please run as root user"
		exit	
	fi	
}

function get_mptcp_version () {

    local kernel=$(uname -r)

    if [[ $kernel == *3.5.7* ]]; then
        mptcp_ver=0.86
    elif [[ $kernel == *4.4.88* ]]; then
        mptcp_ver=0.92
    elif [[ $kernel == *4.4.110* ]]; then
        mptcp_ver=0.92
    elif [[ $kernel == *vbox* ]]; then
        mptcp_ver=vbox
    else
        mptcp_ver=unknown
        echo "$kernel"
        echo "error: mptcp_ver is unkown"
        exit
    fi

    echo "$mptcp_ver"

}

function configure_ip_address(){
    local mptcp_ver=$1

    if [ $mptcp_ver = "0.92" ]; then
        receiver_ip=192.168.15.2
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=enp0s31f6
        eth1=enp2s0
     elif [ $mptcp_ver = "0.86" ]; then
        receiver_ip=192.168.13.1
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=eth0
        eth1=eth1
     elif [ $mptcp_ver = "vbox" ]; then
        receiver_ip=192.168.11.1
        D1_ip=192.168.1.2
        D2_ip=192.168.2.2
        eth0=enp0s3
        eth1=enp0s8
    else
        receiver_ip=192.168.13.1
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=eth0
        eth1=eth1
    fi
    

}

function check_network_available {
   echo -n "checking network is available ..."
   ping $receiver_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "ng"
        echo "error: can't access to receiver [$receiver_ip]"
        exit
   fi
   ping $D1_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "ng"
        echo "error: can't access to D1 [$D1_ip]"
        exit
   fi
    ping $D2_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "ng"
        echo "error: can't access to D2 [$D2_ip]"
        exit
   fi

    echo " ok."
}

function make_directory {
    local cgn_ctrl_var  
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir

    echo -n "making directory ..."
    mkdir ${today}
    mkdir ${today}/tex
    mkdir ${today}/tex/img

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for rtt1_var in "${rtt1[@]}"
        do
            for rtt2_var in "${rtt2[@]}"
            do
                if [ ${rtt1_var} != ${rtt2_var} ] ; then
                    continue
                fi
                for loss_var in "${loss[@]}"
                do
                    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
                    mkdir ${today}/${targetdir}
                    mkdir ${today}/${targetdir}/ave
                    for repeat_i in `seq ${repeat}` 
                    do
                        mkdir ${today}/${targetdir}/${repeat_i}th
                    done

                    for queue_var in "${queue[@]}"
                    do
                        targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                        mkdir ${today}/${targetdir}
                        mkdir ${today}/${targetdir}/ave
                        mkdir ${today}/${targetdir}/ave/throughput
                        for repeat_i in `seq ${repeat}` 
                        do
                            mkdir ${today}/${targetdir}/${repeat_i}th
                            mkdir ${today}/${targetdir}/${repeat_i}th/log
                            mkdir ${today}/${targetdir}/${repeat_i}th/throughput

                        done
                    done    
                done
            done
        done
    done
    echo "done"
}

function set_default_kernel_parameter {
    sysctl net.mptcp.mptcp_debug=${mptcp_debug}
    sysctl net.mptcp.mptcp_enabled=${mptcp_enabled}
    sysctl net.ipv4.tcp_limit_output_bytes=${tcp_limit_output_bytes}
    sysctl net.ipv4.tcp_pacing_ca_ratio=${tcp_pacing_ca_ratio}
    sysctl net.ipv4.tcp_pacing_ss_ratio=${tcp_pacing_ss_ratio}

    if [ $mptcp_ver = 0.86 ]; then
        sysctl net.mptcp.mptcp_no_recvbuf_auto=$no_rcv
        sysctl net.core.netdev_debug=0
        sysctl net.mptcp.mptcp_cwnd_log=1
    fi

    
}

function echo_finish_time {
    local process_time=180 
    local timestamp
    local time
     
    time=`echo "scale=5; ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * ($duration+${process_time}) * $repeat " | bc`
    ((sec=time%60, min=(time%3600)/60, hrs=time/3600))
    timestamp=$(printf "%d時間%02d分%02d秒" $hrs $min $sec)
    echo "終了予想時刻 `date --date "$time seconds"` ${timestamp} "
}
    
function set_netem_rtt_and_loss {
    local D1_eth0=eth0
    local D1_eth1=eth1
    local D2_eth0=eth0    
    local D2_eth1=eth1   

    local delay_harf1=`echo "scale=3; $rtt1_var / 2 " | bc`
    local delay_harf2=`echo "scale=3; $rtt2_var / 2 " | bc`

    ssh -n root@${D1_ip} "tc qdisc change dev ${D1_eth0} root netem delay ${delay_harf1}ms loss 0% &&
                         tc qdisc change dev ${D1_eth1} root netem delay ${delay_harf1}ms loss ${loss_var}%" 
    ssh -n root@${D2_ip} "tc qdisc change dev ${D2_eth0} root netem delay ${delay_harf2}ms loss 0% &&
                         tc qdisc change dev ${D2_eth1} root netem delay ${delay_harf2}ms loss ${loss_var}%"
    
}

function clean_log_sender_and_receiver {
    ssh root@${receiver_ip} "echo > /var/log/kern.log" > /dev/null
    echo > /var/log/kern.log
	find /var/log/ -type f -name \* -exec cp -f /dev/null {} \;
}

function set_txqueuelen {
    
    ip link set dev ${eth0} txqueuelen ${queue_var}
    ip link set dev ${eth1} txqueuelen ${queue_var}
}

function set_qdisc {
    tc qdisc replace dev ${eth0} root ${qdisc}
    tc qdisc replace dev ${eth1} root ${qdisc}
}

function set_bandwidth {
    echo -n "setting bandwidth ..." 
    ethtool -s ${eth0} speed ${band1} duplex full
    ethtool -s ${eth1} speed ${band2} duplex full
    sleep 5
    echo "done" 
}

function run_iperf {
    local app_i 
    local delay
    local nowdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    for app_i in `seq ${app}` 
    do
		delay=`echo "scale=5; $duration + ($app - $app_i) * $app_delay " | bc`
		if [ $app_i = $app ]; then  # When final app launch
			iperf -c ${receiver_ip} -t $delay -i $interval -yc > ./${nowdir}/${repeat_i}th/throughput/app${app_i}.dat
		else
			iperf -c ${receiver_ip} -t $delay -i $interval -yc > ./${nowdir}/${repeat_i}th/throughput/app${app_i}.dat &
			sleep $app_delay
		fi
	done
}

function format_and_copy_log {
     
    local nowdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
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
    }' /var/log/kern.log > ./${nowdir}/${repeat_i}th/log/kern.dat
    
}

function separate_cwnd {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
     awk '{
     target="cwnd*"
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

    }else if(match ($9, target)==1){
        printf("%s ",$1)
        for(i=5;i<=NF;i++){
            printf("%s ",$i)
        }
    
    }else{
        next
    }
    print ""
    }' ./${targetdir}/log/kern.dat > ./${targetdir}/log/cwnd.dat
}

function get_app_meta {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local app_i
    awk '{
        if($5 ~ "meta="){
            array[$6]++   
        }
    }END{
        for(i in array){
            printf("%s %d\n",i,array[i])
        }    
    }' ./${targetdir}/log/kern.dat > ./${targetdir}/log/app.dat

    sort -k2nr ./${targetdir}/log/app.dat > ./${targetdir}/log/app_sort.dat
    mv ./${targetdir}/log/app_sort.dat ./${targetdir}/log/app.dat

    #上からappの数だけ取り出す
    awk -v app=${app} '{
        if(FNR <= app){
            print $0
        }
    }' ./${targetdir}/log/app.dat > ./${targetdir}/log/app_num_order.dat


    for app_i in `seq ${app}` 
    do
        app[$app_i]=$(awk -v n=${app_i} '{
            if(NR==n){
                print $1
            }    
        }' ./${targetdir}/log/app_num_order.dat)

    done

    # 時間順に並べ替える
    echo -n > ./${targetdir}/log/app_time_order.dat
    for app_i in `seq ${app}` 
    do
        awk -v meta=${app[$app_i]} '{
            if($3 == meta){
                printf("%s %s\n",$3,$1);
                exit;
             }
        }' ./${targetdir}/log/cwnd.dat >> ./${targetdir}/log/app_time_order.dat
    done

    sort -k2g ./${targetdir}/log/app_time_order.dat > ./${targetdir}/log/app_sort.dat
    mv ./${targetdir}/log/app_sort.dat ./${targetdir}/log/app_time_order.dat

    awk -v app=${app} '{
        if(FNR <= app){
            print $1
        }
    }' ./${targetdir}/log/app_time_order.dat > ./${targetdir}/log/app_exp.dat

    for app_i in `seq ${app}` 
    do
        app_meta[$app_i]=$(awk -v n=${app_i} '{
            if(NR==n){
                print $1
            }    
        }' ./${targetdir}/log/app_exp.dat)

    done

}

function extract_cwnd_each_flow {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local app_i 
    for app_i in `seq ${app}` 
    do
        awk -v meta=${app_meta[$app_i]} '{
            if(meta==$3){
                print $0
            }
        }' ./${targetdir}/log/cwnd.dat > ./${targetdir}/log/cwnd${app_i}.dat
        

        awk '{
            if($4 ~ "pi="){
                array[$5]++   
            }
            }END{
            for(i in array){
                printf("%s %d\n",i,array[i])
            }    
        }' ./${targetdir}/log/cwnd${app_i}.dat > ./${targetdir}/log/app${app_i}_subflow.dat

        sort -k2nr ./${targetdir}/log/app${app_i}_subflow.dat > ./${targetdir}/log/app${app_i}_subflow_sort.dat
        mv ./${targetdir}/log/app${app_i}_subflow_sort.dat ./${targetdir}/log/app${app_i}_subflow.dat

    done

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            subflowid=$(awk -v n=${subflow_i} '{
                if(NR==n){
                    print $1
                }    
            }' ./${targetdir}/log/app${app_i}_subflow.dat)

            awk -v subf=${subflowid} '{
                if(subf==$5){
                    print $0
                }
            }' ./${targetdir}/log/cwnd${app_i}.dat > ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}.dat
        done
    done

   
}

function count_mptcp_state {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local app_i
    local subflow_i
    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            grep -ic "send_stall" ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}.dat > ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_sendstall.dat

        done
    done

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            grep -ic "cwnd_reduced" ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}.dat > ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_cwndreduced.dat
        done
    done

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            grep -ic "rcv_buf" ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}.dat > ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_rcv_buf.dat
        done
    done
}

function create_plt_file {
    local app_i
    local subflow_i
    local targetname=$1
    local targetpos
    local scale=`echo "scale=1; $duration / 5.0" | bc`
    
    if [ $# -ne 1 ]; then
        echo "create_plt_file:argument error"
        exit 1
    fi
    
    targetpos=$(awk -v targetname=${targetname} '{
        targetname2=targetname"*" 
        for(i=1;i<=NF;i++){
            if( match ($i, targetname2) == 1){
                print i+1;
		exit
            }
        }
	if(NR>100){
            exit
        }
    }' ./${targetdir}/log/cwnd1_subflow1.dat)
    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set key outside
    set key spacing 3
    set size ratio 0.5
    set xlabel "time[s]"
    set datafile separator " " ' > ${targetdir}/${targetname}.plt
    echo "set ylabel \"${targetname}\"" >> ${targetdir}/${targetname}.plt
    echo "set xtics $scale" >> ${targetdir}/${targetname}.plt
    echo "set xrange [0:${duration}]" >> ${targetdir}/${targetname}.plt
    echo "set output \"${targetname}_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png\"" >> ${targetdir}/${targetname}.plt

    echo -n "plot " >> ${targetdir}/${targetname}.plt

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            cwndreduced=$(awk 'NR==1' ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_cwndreduced.dat)
            sendstall=$(awk 'NR==1' ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_sendstall.dat)
            rcv_buf=$(awk 'NR==1' ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_rcv_buf.dat)
            echo -n "\"./log/cwnd${app_i}_subflow${subflow_i}.dat\" using 1:${targetpos} with lines linewidth 2 title \"APP${app_i} : subflow${subflow_i}   \n sendstall=${sendstall}\nrcvbuf=${rcv_buf}\" " >> ${targetdir}/${targetname}.plt
            if [ $app_i != $app ] || [ $subflow_i != $subflownum ];then

               echo -n " , " >> ${targetdir}/${targetname}.plt
                
            fi
        done
    done
}

function create_graph_img {
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local img_file
    local var

    for var in "${item_to_create_graph[@]}" 
    do
        create_plt_file $var
        cd ${targetdir}
        gnuplot $var.plt 
        img_file=${var}_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png 
        ln -s  ../../${targetdir}/${img_file} ../../tex/img/

        cd ../../
    done

}

function create_each_tex_file {
    local targetname=$1
    local tex_name=tex/${cgn_ctrl_var}_${targetname}_${today}.tex
    local img_name=${targetname}_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png

    if [ $# -ne 1 ]; then
        echo "create_plt_file:argument error"
        exit 1
    fi

    
    echo "\begin{figure}[htbp]" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=95mm]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{${targetname} ${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_name} 
    echo '\end{center}
    \end{figure}' >>${tex_name} 
}

function create_tex_file {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th

    local var

    for var in "${item_to_create_graph[@]}" 
    do
        create_each_tex_file $var
    done


}

function create_throughput_time_graph_plt {
    local app_i
    local yrangemax=$(( band1 + band2 ))
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local pltfile=${targetdir}/${repeat_i}th/throughput/plot.plt
    
    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set xlabel "time[s]"
    set ylabel "throughput"
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set datafile separator " " ' > ${pltfile}
    echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ${pltfile}
    echo "set yrange [0:${yrangemax}]" >> ${pltfile}
    echo "set output \"throughput_${targetdir}_${repeat_i}th.png\"" >> ${pltfile}

    echo -n "plot " >> ${pltfile}

    for app_i in `seq ${app}` 
    do
        echo -n "\"./app${app_i}_graph.dat\" using 1:2 with lines linewidth 2 title \"APP${app_i}\"" >> ${pltfile}
        if [ $app_i != $app ]; then
           echo -n " , " >> ${pltfile}
        fi
    done
}

function create_throughput_time_tex {
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local tex_name=tex/${cgn_ctrl_var}_throughput_time_${today}.tex
    local img_name=throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png

    echo "\begin{figure}[htbp]" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=95mm]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{throguhput ${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_name} 
    echo '\end{center}
    \end{figure}' >>${tex_name} 

}

function create_throughput_time_graph {
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local img_file

    create_throughput_time_graph_plt

    cd ${targetdir}/${repeat_i}th/throughput
    gnuplot plot.plt
    img_file=throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png
    ln -s  ../../${targetdir}/${repeat_i}th/throughput/${img_file} ../../../tex/img/
    cd ../../../

}

function convert_unix_time {
    # dateformat is "YYMMDDhhmmss"
    local times=$1

    local year=$(echo "$times" | cut -c 1-4)
    local month=$(echo "$times" | cut -c 5-6)
    local day=$(echo "$times" | cut -c 7-8)
    local hour=$(echo "$times" | cut -c 9-10)
    local minute=$(echo "$times" | cut -c 11-12)
    local second=$(echo "$times" | cut -c 13-)

    times=$(echo "${year}-${month}-${day} ${hour}:${minute}:${second}")
    times=$(date -d "${times}" +%s.%6N) 
    echo "${times}"
}

function process_throughput_data_interval {
    local time_adjust=`echo "scale=3; (${app_i} - 1) * ${app_delay} " | bc`
    while read line
    do
        local times=$(echo "$line" | cut -f 1 -d ",")
        local throughput=$(echo "$line" | cut -f 9 -d ",")
        local unix_time=$(convert_unix_time ${times})
        throughput=`echo "scale=3; ${throughput} / 1000000" | bc ` 
        
        echo "${unix_time} ${throughput}" >> ./${targetdir}/${repeat_i}th/throughput/app${app_i}_tmp.dat 
    done < ./${targetdir}/${repeat_i}th/throughput/app${app_i}.dat 
    
    # 経過時間の計算
    awk -v delay=${time_adjust} '{
       if (NR==1){
           f_time=$1
       }
       printf ("%f %s\n",$1 - f_time + delay,$2);

    }' ./${targetdir}/${repeat_i}th/throughput/app${app_i}_tmp.dat > ./${targetdir}/${repeat_i}th/throughput/app${app_i}_graph_tmp.dat

    # データの最終行を除外する
    sed '$d' ./${targetdir}/${repeat_i}th/throughput/app${app_i}_graph_tmp.dat > ./${targetdir}/${repeat_i}th/throughput/app${app_i}_graph.dat

    rm -f ./${targetdir}/${repeat_i}th/throughput/app${app_i}_tmp.dat 
    rm -f ./${targetdir}/${repeat_i}th/throughput/app${app_i}_graph_tmp.dat 
}

function process_throughput_data {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local app_i

    for app_i in `seq ${app}` 
    do
        awk -F "," 'END{
           printf("%s\n",$9 / 1000000); 
        }' ./${targetdir}/${repeat_i}th/throughput/app${app_i}.dat >> ./${targetdir}/${repeat_i}th/throughput/app${app_i}_.dat

        awk -F "," 'END{
           printf("%s\n",$9 / 1000000); 
        }' ./${targetdir}/${repeat_i}th/throughput/app${app_i}.dat >> ./${targetdir}/ave/throughput/app${app_i}.dat
       
        process_throughput_data_interval
    done
}

function process_throughput_data_ave {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local app_i
    local repeat_i

    for app_i in `seq ${app}` 
    do
        awk -v repeat=${repeat} 'BEGIN{
                total=0
            }{
                total = total + $1
            }END{
            total = total / repeat
            printf("%s\n",total);
        }' ./${targetdir}/ave/throughput/app${app_i}.dat >> ./${targetdir}/ave/throughput/app${app_i}_ave.dat
    done
}


function create_throughput_queue_graph_plt {
    local repeat_i 
    local app_i
    local queue_var
    local throughput
    local yrangemax=$(( band1 + band2 ))
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    
    for repeat_i in `seq ${repeat}` 
    do
        for queue_var in "${queue[@]}"
        do
            for app_i in `seq ${app}` 
            do
                throughput=$(cat ${targetdir}_queue=${queue_var}/${repeat_i}th/throughput/app${app_i}_.dat)
                echo "${queue_var} ${throughput}" >> ./${targetdir}/${repeat_i}th/app${app_i}.dat
            done
        done

        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 ]; then
                cp ./${targetdir}/${repeat_i}th/app${app_i}.dat ./${targetdir}/${repeat_i}th/graphdata.dat
            else
                join ./${targetdir}/${repeat_i}th/graphdata.dat ./${targetdir}/${repeat_i}th/app${app_i}.dat > ${targetdir}/${repeat_i}th/tmp.dat
                mv ${targetdir}/${repeat_i}th/tmp.dat ./${targetdir}/${repeat_i}th/graphdata.dat
            fi
        done

        awk '{
            total=0
            for (i = 2;i <= NF;i++){
                total += $i;
            }
            printf("%s %f\n",$0,total)

        }' ./${targetdir}/${repeat_i}th/graphdata.dat > ./${targetdir}/${repeat_i}th/graphdata_total.dat

        echo 'set terminal emf enhanced "Arial, 24"
        set terminal png size 960,720
        set xlabel "queue"
        set ylabel "throughput"
        set key outside
        set size ratio 0.5
        set boxwidth 0.5 relative 
        set datafile separator " " ' > ./${targetdir}/${repeat_i}th/plot.plt
        echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/${repeat_i}th/plot.plt 
        echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/${repeat_i}th/plot.plt
        echo "set output \"throughput_${targetdir}_${repeat_i}th.png\"" >> ./${targetdir}/${repeat_i}th/plot.plt

        echo -n "plot " >> ./${targetdir}/${repeat_i}th/plot.plt

        for app_i in `seq ${app}` 
        do
            n=`expr $app_i + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${app_i}\" " >> ./${targetdir}/${repeat_i}th/plot.plt
            if [ $app_i != $app ];then

                echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/${repeat_i}th/plot.plt
            fi
        done
    done 

    for queue_var in "${queue[@]}"
    do
        for app_i in `seq ${app}` 
        do
            throughput=$(cat ${targetdir}_queue=${queue_var}/ave/throughput/app${app_i}_ave.dat)
            echo "${queue_var} ${throughput}" >> ./${targetdir}/ave/app${app_i}.dat
        done
    done

    for app_i in `seq ${app}` 
    do
        if [ $app_i -eq 1 ]; then
            cp ./${targetdir}/ave/app${app_i}.dat ./${targetdir}/ave/graphdata.dat
        else
            join ./${targetdir}/ave/graphdata.dat ./${targetdir}/ave/app${app_i}.dat > ${targetdir}/ave/tmp.dat
            mv ${targetdir}/ave/tmp.dat ./${targetdir}/ave/graphdata.dat
        fi
    done

    awk '{
    total=0
    for (i = 2;i <= NF;i++){
        total += $i;
    }
    printf("%s %f\n",$0,total)

    }' ./${targetdir}/ave/graphdata.dat > ./${targetdir}/ave/graphdata_total.dat

    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set xlabel "queue"
    set ylabel "throughput"
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set datafile separator " " ' > ./${targetdir}/ave/plot.plt
    echo "set title \"throughput ${targetdir} ${repeat_i} times average \"" >> ./${targetdir}/ave/plot.plt 
    echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/ave/plot.plt
    echo "set output \"throughput_${targetdir}_ave.png\"" >> ./${targetdir}/ave/plot.plt

    echo -n "plot " >> ./${targetdir}/ave/plot.plt

    for app_i in `seq ${app}` 
    do
        n=`expr $app_i + 1`
        echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${app_i}\" " >> ./${targetdir}/ave/plot.plt
        if [ $app_i != $app ];then

        echo -n " , " >> ./${targetdir}/ave/plot.plt
        else
         n=`expr $n + 1`
         echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/ave/plot.plt
        fi

    done
}

function create_throughput_queue_graph {
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    local img_file
    create_throughput_queue_graph_plt

    for repeat_i in `seq ${repeat}` 
    do
        cd ${targetdir}/${repeat_i}th
        gnuplot plot.plt
        img_file=throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_${repeat_i}th.png
        ln -s  ../../${targetdir}/${repeat_i}th/${img_file} ../../tex/img/
        cd ../..
    done

    cd ${targetdir}/ave
    gnuplot plot.plt
    img_file=throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_ave.png
    ln -s  ../../${targetdir}/ave/${img_file} ../../tex/img/

    cd ../..
}

function create_throughput_queue_tex {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    local repeat_i
    local tex_file_name=${cgn_ctrl_var}_throughput_${today}
    
    cd tex


    for repeat_i in `seq ${repeat}` 
    do
        echo "\begin{figure}[htbp]" >> ${tex_file_name}.tex
        echo "\begin{center}" >> ${tex_file_name}.tex
        echo '\includegraphics[width=95mm]' >> ${tex_file_name}.tex
        echo "{img/throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_${repeat_i}th.png}" >> ${tex_file_name}.tex
        echo "\caption{${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% ${repeat_i}回目}" >> ${tex_file_name}.tex
        echo '\end{center}
        \end{figure}' >> ${tex_file_name}.tex
    done

#---------------------ave-------------------------

    echo "\begin{figure}[htbp]" >> ${tex_file_name}_ave.tex
    echo "\begin{center}" >> ${tex_file_name}_ave.tex
    echo '\includegraphics[width=95mm]' >> ${tex_file_name}_ave.tex
    echo "{img/throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_ave.png}" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo "\caption{${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% ${repeat_i}回平均}" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo '\end{center}
    \end{figure}' >> ${tex_file_name}_ave.tex

    cd ..
}

function create_all_each_graph_tex {
    local targetname=$1
    local img_name=${targetname}_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png

    echo "\begin{figurehere}" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=90mm]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{${targetname}}" >> ${tex_name} 
    echo "\end{center}" >>${tex_name}
    echo "\end{figurehere}" >>${tex_name} 

}

function create_all_graph_tex {
    local tex_name=tex/${cgn_ctrl_var}_alldata_${today}.tex

    echo "\begin{center}${cgn_ctrl_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}th \end{center}" >> ${tex_name} 
    echo "\begin{multicols}{2}" >> ${tex_name}

    create_all_each_graph_tex "throughput"

    for var in "${item_to_create_graph[@]}" 
    do
        create_all_each_graph_tex $var
    done
    echo "\end{multicols}" >> ${tex_name}
    echo "\clearpage" >>${tex_name} 
}

function process_log_data {
    local cgn_ctrl_var  
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local app_meta=()
    local total_count=`echo "scale=1; ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    local current_count=0

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for loss_var in "${loss[@]}"
        do
            for rtt1_var in "${rtt1[@]}"
            do
                for rtt2_var in "${rtt2[@]}"
                do
                    if [ ${rtt1_var} != ${rtt2_var} ] ; then
                        continue
                    fi
                    for queue_var in "${queue[@]}"
                    do
                        for repeat_i in `seq ${repeat}` 
                        do
                            percent=`echo "scale=3; $current_count / $total_count * 100 " | bc`
                            percent=`echo "scale=1; $percent / 1 " | bc`
                            echo -ne "processing data ...${percent}% (${current_count} / ${total_count})\r"
                            separate_cwnd
                            get_app_meta
                            extract_cwnd_each_flow
                            count_mptcp_state
                            create_graph_img
                            create_tex_file
                            process_throughput_data
                            create_throughput_time_graph
                            create_throughput_time_tex
                            create_all_graph_tex
                            (( current_count++))
                        done
                        process_throughput_data_ave
                    done    
                    create_throughput_queue_graph
                    create_throughput_queue_tex
                done
            done
        done
    done
    echo "processing data ...done                                    "
}

function build_tex_to_pdf {
    local cgn_ctrl_var
    local item_ver
    cd tex 

    if !(type platex > /dev/null 2>&1); then
       echo "platex does not exist."
       return 1
    fi

    echo -n "Build tex file ..."
    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for item_var in "${item_to_create_graph[@]}" 
        do
            platex -halt-on-error ${cgn_ctrl_var}_${item_var}_${today}.tex > /dev/null 2>&1
            dvipdfmx ${cgn_ctrl_var}_${item_var}_${today}.dvi > /dev/null 2>&1
            ln -sf tex/${cgn_ctrl_var}_${item_var}_${today}.pdf ../
        done
        platex -halt-on-error ${cgn_ctrl_var}_throughput_${today}.tex > /dev/null 2>&1
        dvipdfmx ${cgn_ctrl_var}_throughput_${today}.dvi > /dev/null 2>&1
        ln -sf tex/${cgn_ctrl_var}_throughput_${today}.pdf ../

        platex -halt-on-error ${cgn_ctrl_var}_throughput_${today}_ave.tex > /dev/null 2>&1
        dvipdfmx ${cgn_ctrl_var}_throughput_${today}_ave.dvi > /dev/null 2>&1
        ln -sf tex/${cgn_ctrl_var}_throughput_${today}_ave.pdf ../

        platex -halt-on-error ${cgn_ctrl_var}_throughput_time_${today}.tex > /dev/null 2>&1
        dvipdfmx ${cgn_ctrl_var}_throughput_time_${today}.dvi > /dev/null 2>&1
        ln -sf tex/${cgn_ctrl_var}_throughput_time_${today}.pdf ../

        platex -halt-on-error ${cgn_ctrl_var}_alldata_${today}.tex > /dev/null 2>&1
        dvipdfmx ${cgn_ctrl_var}_alldata_${today}.dvi > /dev/null 2>&1
        ln -sf tex/${cgn_ctrl_var}_alldata_${today}.pdf ../


        rm -f ${cgn_ctrl_var}*.log
        rm -f ${cgn_ctrl_var}*.dvi
        rm -f ${cgn_ctrl_var}*.aux
    
	echo "done"
    done

    cd ..
}

function create_tex_header {
    local item_name=$1



    echo '
    \documentclass{jsarticle}
    \usepackage[dvipdfmx]{graphicx}
    \usepackage{grffile}
    \usepackage[top=0truemm,bottom=0truemm,left=5truemm,right=0truemm]{geometry}
    \usepackage{multicol}
    \makeatletter
    \newenvironment{figurehere}
        {\def\@captype{figure}}
        {}
    \makeatother
    \begin{document}
    ' > tex_header.txt
   
    echo "\title{${item_name} \\\\ ${cgn_ctrl_var} }" >> ./tex_header.txt
	echo "\author{${author}}" >> ./tex_header.txt
	echo "\maketitle" >> ./tex_header.txt
	echo "\begin{table}[h]" >> ./tex_header.txt
	echo "\begin{center}" >> ./tex_header.txt
	echo "\begin{tabular}{ll}" >> ./tex_header.txt
	echo "date & \verb|${today}| \\\\" >> ./tex_header.txt
	echo "\verb|sender_kernel| & \verb|${kernel}| \\\\" >> ./tex_header.txt
	echo "\verb|receiver_kernel| & \verb|${rcvkernel}| \\\\" >> ./tex_header.txt
	echo "mptcp version & ${mptcp_ver} \\\\" >> ./tex_header.txt
	echo "other cgnctrl & ${cgn_ctrl[@]} \\\\" >> ./tex_header.txt
	echo "qdisc & \verb|${qdisc}|\\\\" >> ./tex_header.txt
	echo "\verb|subflownum| & \verb|${subflownum}| \\\\" >> ./tex_header.txt
	echo "app & ${app}\\\\" >> ./tex_header.txt
	echo "rtt1 & ${rtt1[@]}\\\\" >> ./tex_header.txt
	echo "rtt2 & ${rtt2[@]}\\\\" >> ./tex_header.txt
	echo "loss & ${loss[@]}\\\\" >> ./tex_header.txt
	echo "queue & ${queue[@]}\\\\" >> ./tex_header.txt
	echo "duration & ${duration}\\\\" >> ./tex_header.txt
	echo "\verb|app_delay| & \verb|${app_delay}|\\\\" >> ./tex_header.txt
	echo "repeat & ${repeat}\\\\" >> ./tex_header.txt
	echo "memo & \verb|${memo}|\\\\" >> ./tex_header.txt
	echo "\end{tabular}" >> ./tex_header.txt
	echo "\end{center}" >> ./tex_header.txt
	echo "\end{table}" >> ./tex_header.txt
	echo "\clearpage" >> ./tex_header.txt

    echo "\begin{verbatim} `cat ../default.conf` \end{verbatim}" >> ./tex_header.txt
	echo "\clearpage" >> ./tex_header.txt

}

function join_header_and_tex_file {
    local var
    local tex_file_name
    cd tex  

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for item_var in "${item_to_create_graph[@]}" 
        do
            create_tex_header ${item_var}
            tex_file_name=${cgn_ctrl_var}_${item_var}_${today}
            cat ./tex_header.txt ./${tex_file_name}.tex > tmp.tex
            mv tmp.tex ./${tex_file_name}.tex 
            rm ./tex_header.txt
            echo "\end{document}" >> ${tex_file_name}.tex
        done
    done

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        tex_file_name=${cgn_ctrl_var}_throughput_${today}

        create_tex_header "Throughput"
        cat ./tex_header.txt ./${tex_file_name}.tex > tmp.tex
        mv tmp.tex ./${tex_file_name}.tex 
        echo "\end{document}" >> ${tex_file_name}.tex
        rm ./tex_header.txt

        create_tex_header "Throughput ${repeat} repeat"
        cat ./tex_header.txt ./${tex_file_name}_ave.tex > tmp.tex
        mv tmp.tex ./${tex_file_name}_ave.tex 
        echo "\end{document}" >> ${tex_file_name}_ave.tex
        rm ./tex_header.txt
    done
    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        create_tex_header "Throughput"
        tex_file_name=${cgn_ctrl_var}_throughput_time_${today}
        cat ./tex_header.txt ./${tex_file_name}.tex > tmp.tex
        mv tmp.tex ./${tex_file_name}.tex 
        rm ./tex_header.txt
        echo "\end{document}" >> ${tex_file_name}.tex
    done

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        create_tex_header "Alldata"
        tex_file_name=${cgn_ctrl_var}_alldata_${today}
        cat ./tex_header.txt ./${tex_file_name}.tex > tmp.tex
        mv tmp.tex ./${tex_file_name}.tex 
        rm ./tex_header.txt
        echo "\end{document}" >> ${tex_file_name}.tex
    done

    cd ..
}

function change_graph_xrange {
     local cgn_ctrl_var  
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local scale
    
    echo "Please selecet target name"
    select targetname in ${item_to_create_graph[@]} "exit"
    do
        if [ $targetname ];then
            break
        fi
        if [ "${targetname}" = "exit" ]; then
            exit
        fi
    done

    echo "Please input x range [x1 x2]"
    echo "if you want to exit, please type [exit]"
    echo -n ">"

    
    while read start_point end_point 
    do
        if [ $start_point = "exit" ]; then
            exit
        fi

        expr ${start_point} + ${end_point} > /dev/null 2>&1 # numeric check
        if [ $? -ne 2 ] ; then
            echo "check... ok."
            break
        else
            echo "incorrect input. Please retype [x1 x2]"
            echo -n ">"
        fi
    done

    scale=`echo "scale=5; (${end_point} - ${start_point}) / 5.0" | bc`
    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for rtt1_var in "${rtt1[@]}"
        do
            for rtt2_var in "${rtt2[@]}"
            do
                if [ ${rtt1_var} != ${rtt2_var} ] ; then
                    continue
                fi
                for loss_var in "${loss[@]}"
                do
                    for queue_var in "${queue[@]}"
                    do
                        for repeat_i in `seq ${repeat}` 
                        do
                            targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
                            echo -n "$targetdir ..."                           
				cd $targetdir
                            awk -v startpoint=${start_point} -v endpoint=${end_point} -v scale=${scale} '{
                                if($2~"xrange"){
                                    printf("set xrange [%s:%s]\n",startpoint,endpoint) 
                                }else if ($2 ~ "xtics"){
                                    printf("set xtics %s\n",scale) 
                                }else{
                                    print
                                }
                            }' ${targetname}.plt > ${targetname}_xrange[${start_point},${end_point}].plt
                            gnuplot ${targetname}_xrange[${start_point},${end_point}].plt
                            echo "done"
                            cd ../..
                        done
                    done    
                done
            done
        done
    done


}
