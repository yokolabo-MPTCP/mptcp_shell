#!/bin/bash

function nCr {          # 組み合わせ
    local n=$1
    local r=$2

    local i
    local numerator=1   #分子
    local denominator=1 #分母
    local result=1

    for i in `seq $n -1 $((n-r+1))`
    do
        numerator=`echo "scale=1;$numerator * $i" | bc`
    done

    for i in `seq $r`
    do
        denominator=`echo "scale=1;$denominator * $i" | bc`
    done

    result=`echo "scale=1;$numerator / $denominator" | bc`

    echo $result
    
}

function nHr {      # 重複組合せ
    local n=$1
    local r=$2
    local result
    result=$(nCr `echo "scale=1;$n + $r - 1" | bc` $r)
    echo $result
}

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

function set_kernel_parameter { 
    local var 
    for var in "${sysctl_default_kernel_parameter[@]}" 
    do
        sysctl ${var} || check_sysctl_error
    done
    
    for var in "${sysctl_user_kernel_parameter[@]}" 
    do
        sysctl ${var} || check_sysctl_error
    done

}

function check_exist_extended_parameter {
    if [ ${#extended_parameter[@]} -eq 0 ]; then
        extended_parameter+=("null")
    fi
}

function extended_function {
    local var=$1
    if [ ${var} != "null" ]; then
        set_extended_kernel_parameter ${var}
    fi
}

function set_extended_kernel_parameter { 
    local var=$1 
    sysctl ${extended_parameter_name}=${var} || check_sysctl_error
}

function check_sysctl_error { 
    # sysctl parameter check
    echo ""
    echo "Invalid argument of sysctl parameter."
    echo "Please check .conf and kernel program."
    exit	
}

function get_mptcp_version () {

    local kernel=$(uname -r)

    if [[ $kernel == *3.5.7* ]]; then
        mptcp_ver=0.86
    elif [[ $kernel == *3.1.0* ]]; then
        mptcp_ver=0.87
    elif [[ $kernel == *3.1.1* ]]; then
        mptcp_ver=0.88
    elif [[ $kernel == *3.14.* ]]; then
        mptcp_ver=0.89
    elif [[ $kernel == *3.18.* ]]; then
        mptcp_ver=0.90
    elif [[ $kernel == *4.1.* ]]; then
        mptcp_ver=0.91
    elif [[ $kernel == *4.4.* ]]; then
        mptcp_ver=0.92
    elif [[ $kernel == *4.9.* ]]; then
        mptcp_ver=0.93
    elif [[ $kernel == *4.14.* ]]; then
        mptcp_ver=0.94
    elif [[ $kernel == *4.19.* ]]; then
        mptcp_ver=0.95
    elif [[ $kernel == *vbox* ]]; then
        mptcp_ver=vbox
    else
        mptcp_ver=unknown
        echo "$kernel"
        echo "error: mptcp_ver is unkown"
    fi

    if [[ $kernel == *sptcp* ]]; then
        mptcp_ver=sptcp
    fi

    echo "$mptcp_ver"

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

function check_rtt_combination {
    if [ -v ${rtt_all_combination} ]; then      # tool.shで古い実験データを扱うときの互換性確保用
        rtt_all_combination=0
    fi
    if [ ${rtt_all_combination} = 1 ]; then
        if [ ${rtt1_var} -gt ${rtt2_var} ] ; then
            return 1
        fi
    else
        if [ ${rtt1_var} != ${rtt2_var} ] ; then
            return 1
        fi
    fi

    return 0
}

function make_directory {
    local extended_var
    local cgn_ctrl_var  
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir

    echo -n "making directory ..."
    mkdir ${rootdir}
    mkdir ${rootdir}/tex
    mkdir ${rootdir}/tex/img

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
        
            for rtt1_var in "${rtt1[@]}"
            do
                for rtt2_var in "${rtt2[@]}"
                do
                    check_rtt_combination || continue 
                    for loss_var in "${loss[@]}"
                    do
                        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
                        mkdir ${rootdir}/${targetdir}
                        mkdir ${rootdir}/${targetdir}/ave
                        for repeat_i in `seq ${repeat}` 
                        do
                            mkdir ${rootdir}/${targetdir}/${repeat_i}th
                        done

                        for queue_var in "${queue[@]}"
                        do
                            targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                            mkdir ${rootdir}/${targetdir}
                            mkdir ${rootdir}/${targetdir}/ave
                            mkdir ${rootdir}/${targetdir}/ave/throughput
                            for repeat_i in `seq ${repeat}` 
                            do
                                mkdir ${rootdir}/${targetdir}/${repeat_i}th
                                mkdir ${rootdir}/${targetdir}/${repeat_i}th/log
                                mkdir ${rootdir}/${targetdir}/${repeat_i}th/throughput

                            done
                        done    
                    done
                done
            done
        done
    done

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for loss_var in "${loss[@]}"
            do
                for queue_var in "${queue[@]}"
                do
                    targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}
                    mkdir ${rootdir}/${targetdir} 
                    mkdir ${rootdir}/${targetdir}/ave
                    for repeat_i in `seq ${repeat}` 
                    do
                        mkdir ${rootdir}/${targetdir}/${repeat_i}th
                    done
                done
            done
        done
    done

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for rtt1_var in "${rtt1[@]}"
        do
            for rtt2_var in "${rtt2[@]}"
            do
                check_rtt_combination || continue 
                for loss_var in "${loss[@]}"
                do
                    for queue_var in "${queue[@]}"
                    do
                        targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                        mkdir ${rootdir}/${targetdir} 
                        mkdir ${rootdir}/${targetdir}/ave
                        for repeat_i in `seq ${repeat}` 
                        do
                            mkdir ${rootdir}/${targetdir}/${repeat_i}th
                            mkdir ${rootdir}/${targetdir}/${repeat_i}th/srtt
                        done
                    done
                done
            done
        done
    done

    echo "done"
}

function echo_finish_time {
    local process_time
    local timestamp
    local time
    
    if [ ${mptcp_ver} == "sptcp" ]; then
        process_time=70 # sptcp 一回の実験に必要なデータ処理時間 [s]  
    else
        process_time=205 # mptcp 一回の実験に必要なデータ処理時間 [s] 
    fi

    time=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * ($duration+${process_time}) * $repeat " | bc`
    ((sec=time%60, min=(time%3600)/60, hrs=time/3600))
    timestamp=$(printf "%d時間%02d分%02d秒" $hrs $min $sec)
    echo "予想終了時刻 `date --date "$time seconds"` ${timestamp} "
}

function echo_data_byte {
    local byte
    local one_data
    local result

    if [ ${mptcp_ver} == "sptcp" ]; then
        one_data=0.0188 # sptcp 一回の実験に必要なデータ量 [GB]  
    else
        one_data=0.0434 # mptcp 一回の実験に必要なデータ量 [GB] 
    fi

    byte=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} *${one_data} * $repeat " | bc`
    result=`echo "scale=5; ${byte} < 1 " | bc`
    if [ ${result} = "1" ]; then
        
        byte=`echo "scale=2; ${byte} * 1000 " | bc`
        echo "予想データ量 ${byte} MB"
    else
        echo "予想データ量 ${byte} GB"
    fi
}
    
function set_netem_rtt_and_loss {

    local delay_harf1=`echo "scale=3; $rtt1_var / 2 " | bc`
    local delay_harf2=`echo "scale=3; $rtt2_var / 2 " | bc`

    ssh -n root@${D1_ip} "tc qdisc replace dev ${D1_eth0} root netem delay ${delay_harf1}ms loss 0% &&
                         tc qdisc replace dev ${D1_eth1} root netem delay ${delay_harf1}ms loss ${loss_var}%" 
    ssh -n root@${D2_ip} "tc qdisc replace dev ${D2_eth0} root netem delay ${delay_harf2}ms loss 0% &&
                         tc qdisc replace dev ${D2_eth1} root netem delay ${delay_harf2}ms loss ${loss_var}%"
    
}

function get_user_name_and_rewrite_config {
    local username=$SUDO_USER
    awk -v username=${username} -F = '{
        if($1~"author"){
            printf("author=\"%s\"\n",username) 
        }else{
            print
        }
    }' default.conf > out
    mv -f out default.conf
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

function run_iperf {
    local app_i 
    local delay
    local nowdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
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
     
    local nowdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
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
    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
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
    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
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
    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
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
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local app_i
    local subflow_i
    local var

    for var in "${item_to_count_state[@]}" 
    do    
        for app_i in `seq ${app}` 
        do
            for subflow_i in `seq ${subflownum}` 
            do
                grep -ic "${var}" ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}.dat > ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_${var}.dat

            done
        done
    done
    }

function create_plt_file {
    local app_i
    local subflow_i
    local targetname=$1
    local targetpos
    local scale=`echo "scale=1; $duration / 5.0" | bc`
    local spacing 
    local gnuplotversion
    local statecount
    local var

    if [ $# -ne 1 ]; then
        echo "create_plt_file:argument error"
        exit 1
    fi
     
    gnuplotversion=$(gnuplot --version)
    gnuplotversion=$(echo ${gnuplotversion:8:1})
    if [ ${gnuplotversion} -eq 5 ]; then
        spacing=1
    else
        spacing=5
    fi
    spacing=$((${spacing} + ${#item_to_count_state[@]}))

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
    set size ratio 0.5
    set xlabel "time[s]"
    set datafile separator " " ' > ${targetdir}/${targetname}.plt
    echo "set key spacing ${spacing}" >> ${targetdir}/${targetname}.plt
    echo "set ylabel \"${targetname}\"" >> ${targetdir}/${targetname}.plt
    echo "set xtics $scale" >> ${targetdir}/${targetname}.plt
    echo "set xrange [0:${duration}]" >> ${targetdir}/${targetname}.plt
    echo "set output \"${targetname}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png\"" >> ${targetdir}/${targetname}.plt

    echo -n "plot " >> ${targetdir}/${targetname}.plt

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            echo -n "\"./log/cwnd${app_i}_subflow${subflow_i}.dat\" using 1:${targetpos} with lines linewidth 2 title \"APP${app_i} : subflow${subflow_i} " >> ${targetdir}/${targetname}.plt
            for var in "${item_to_count_state[@]}" 
            do
                statecount=$(awk 'NR==1' ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_${var}.dat)
                echo -n "\n ${var}=${statecount} " >> ${targetdir}/${targetname}.plt
            done
            echo -n "\" " >> ${targetdir}/${targetname}.plt
            if [ $app_i != $app ] || [ $subflow_i != $subflownum ];then

               echo -n " , " >> ${targetdir}/${targetname}.plt
                
            fi
        done
    done
}

function create_graph_img {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local img_file
    local var

    for var in "${item_to_create_graph[@]}" 
    do
        create_plt_file $var
        cd ${targetdir}
        gnuplot $var.plt 2>/dev/null
        img_file=${var}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png 
        ln -s  ../../${targetdir}/${img_file} ../../tex/img/

        cd ../../
    done

}

function create_each_tex_file {
    local targetname=$1
    local tex_name=tex/${cgn_ctrl_var}_${targetname}_${rootdir}.tex
    local img_name=${targetname}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png

    if [ $# -ne 1 ]; then
        echo "create_plt_file:argument error"
        exit 1
    fi

    
    echo "\begin{figure}[htbp]" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=95mm]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{${targetname} ${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var}\% RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_name} 
    echo '\end{center}
    \end{figure}' >>${tex_name} 
}

function create_tex_file {
    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th

    local var

    for var in "${item_to_create_graph[@]}" 
    do
        create_each_tex_file $var
    done


}

function set_yrange_max {
    local yrange_max

    if [ ${mptcp_ver} == "sptcp" ] ; then
        yrangemax=$band1
    else
        yrangemax=$(( band1 + band2 ))
    fi

    echo ${yrangemax}
}

function create_throughput_time_graph_plt {
    local app_i
    local yrangemax
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local pltfile=${targetdir}/${repeat_i}th/throughput/plot.plt
    
    yrangemax=$(set_yrange_max)
    
    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set xlabel "time[s]"
    set ylabel "throughput"
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set termoption noenhanced
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
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local tex_name=tex/${cgn_ctrl_var}_throughput_time_${rootdir}.tex
    local img_name=throughput_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png

    echo "\begin{figure}[htbp]" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=95mm]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{throguhput ${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var}\% RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_name} 
    echo '\end{center}
    \end{figure}' >>${tex_name} 

}

function create_throughput_time_graph {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local img_file

    create_throughput_time_graph_plt

    cd ${targetdir}/${repeat_i}th/throughput
    gnuplot plot.plt 2>/dev/null
    img_file=throughput_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png
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

function process_throguhput_data_queue {
    local targetdir
    local throguhput

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    throughput=$(cat ${targetdir}/throughput/app${app_i}_.dat)

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}/${repeat_i}th
    echo "${queue_var} ${throughput}" >> ./${targetdir}/app${app_i}.dat

}

function process_throughput_data_rtt {
    local targetdir
    local throguhput

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    throughput=$(cat ${targetdir}/throughput/app${app_i}_.dat)

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    echo "${rtt1_var},${rtt2_var} ${throughput}" >> ./${targetdir}/app${app_i}.dat
  
}

function process_throughput_data_ext {
    local targetdir
    local throguhput

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    throughput=$(cat ${targetdir}/throughput/app${app_i}_.dat)

    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    echo "${extended_var} ${throughput}" >> ./${targetdir}/app${app_i}.dat
  
}

function process_throughput_data {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
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

        process_throguhput_data_queue

        process_throughput_data_rtt
        
        process_throughput_data_ext
    done
}

function process_throughput_data_rtt_ave {
    local targetdir
    local throguhput

    for app_i in `seq ${app}` 
    do
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
        throughput=$(cat ${targetdir}/ave/throughput/app${app_i}_ave.dat)
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}
        echo "${queue_var} ${throughput}" >> ./${targetdir}/ave/app${app_i}.dat
    done

}

function process_throughput_data_queue_ave {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    local throguhput

    for app_i in `seq ${app}` 
    do
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
        throughput=$(cat ${targetdir}/ave/throughput/app${app_i}_ave.dat)
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
        echo "${queue_var} ${throughput}" >> ./${targetdir}/ave/app${app_i}.dat
    done

}

function process_throughput_data_ext_ave {
    local targetdir
    local throguhput

    for app_i in `seq ${app}` 
    do
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
        throughput=$(cat ${targetdir}/ave/throughput/app${app_i}_ave.dat)
        targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
        echo "${queue_var} ${throughput}" >> ./${targetdir}/ave/app${app_i}.dat
    done

}

function process_throughput_data_ave {
    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
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
    
    process_throughput_data_queue_ave
    process_throughput_data_rtt_ave
    process_throughput_data_ext_ave
}


function create_throughput_queue_graph_plt {
    local repeat_i 
    local app_i
    local queue_var
    local yrangemax

    yrangemax=$(set_yrange_max)

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    
    for repeat_i in `seq ${repeat}` 
    do
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
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    local img_file
    create_throughput_queue_graph_plt

    for repeat_i in `seq ${repeat}` 
    do
        cd ${targetdir}/${repeat_i}th
        gnuplot plot.plt 2>/dev/null
        img_file=throughput_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_${repeat_i}th.png
        ln -s  ../../${targetdir}/${repeat_i}th/${img_file} ../../tex/img/
        cd ../..
    done

    cd ${targetdir}/ave
    gnuplot plot.plt 2>/dev/null
    img_file=throughput_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_ave.png
    ln -s  ../../${targetdir}/ave/${img_file} ../../tex/img/

    cd ../..
}

function create_throughput_queue_tex {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    local repeat_i
    local tex_file_name=${cgn_ctrl_var}_throughput_queue_${rootdir}
    
    cd tex


    for repeat_i in `seq ${repeat}` 
    do
        echo "\begin{figure}[htbp]" >> ${tex_file_name}.tex
        echo "\begin{center}" >> ${tex_file_name}.tex
        echo '\includegraphics[width=95mm]' >> ${tex_file_name}.tex
        echo "{img/throughput_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_${repeat_i}th.png}" >> ${tex_file_name}.tex
        echo "\caption{${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var}\% RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms ${repeat_i}回目}" >> ${tex_file_name}.tex
        echo '\end{center}
        \end{figure}' >> ${tex_file_name}.tex
    done

#---------------------ave-------------------------

    echo "\begin{figure}[htbp]" >> ${tex_file_name}_ave.tex
    echo "\begin{center}" >> ${tex_file_name}_ave.tex
    echo '\includegraphics[width=95mm]' >> ${tex_file_name}_ave.tex
    echo "{img/throughput_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_ave.png}" >> ${tex_file_name}_ave.tex
    echo "\caption{${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var}\% RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms ${repeat_i}回平均}" >> ${tex_file_name}_ave.tex
    echo '\end{center}
    \end{figure}' >> ${tex_file_name}_ave.tex

    cd ..
}

function create_all_each_graph_tex {
    local targetname=$1
    local img_name=${targetname}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png

    echo "\begin{figurehere}" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=90mm]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{${targetname}}" >> ${tex_name} 
    echo "\end{center}" >>${tex_name}
    echo "\end{figurehere}" >>${tex_name} 

}

function create_all_graph_tex {
    local tex_name=tex/${cgn_ctrl_var}_alldata_${rootdir}.tex
    
    echo "\\" >> ${tex_name} 
    echo "\begin{center}${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}th \end{center}" >> ${tex_name} 
    echo "\begin{multicols}{2}" >> ${tex_name}

    create_all_each_graph_tex "throughput"

    for var in "${item_to_create_graph[@]}" 
    do
        create_all_each_graph_tex $var
    done
    echo "\end{multicols}" >> ${tex_name}
    echo "\clearpage" >>${tex_name} 
}

function create_throughput_rtt_graph_plt {
    local targetdir
    local yrangemax
    local repeat_i

    yrangemax=$(set_yrange_max)

    for repeat_i in `seq ${repeat}` 
    do
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 ]; then
                cp ./${targetdir}/app${app_i}.dat ./${targetdir}/graphdata.dat
            else
                join ./${targetdir}/graphdata.dat ./${targetdir}/app${app_i}.dat > ${targetdir}/tmp.dat
                mv ${targetdir}/tmp.dat ./${targetdir}/graphdata.dat
            fi
        done

        awk '{
            total=0
            for (i = 2;i <= NF;i++){
                total += $i;
            }
            printf("%s %f\n",$0,total)

        }' ./${targetdir}/graphdata.dat > ./${targetdir}/graphdata_total.dat

        echo 'set terminal emf enhanced "Arial, 24"
        set terminal png size 960,720
        set xlabel "RTT [ms]"
        set ylabel "throughput"
        set key outside
        set size ratio 0.5
        set boxwidth 0.5 relative 
        set datafile separator " " ' > ./${targetdir}/plot.plt
        echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/plot.plt 
        echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/plot.plt
        echo "set output \"throughput_${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png\"" >> ./${targetdir}/plot.plt

        echo -n "plot " >> ./${targetdir}/plot.plt

        for app_i in `seq ${app}` 
        do
            n=`expr $app_i + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${app_i}\" " >> ./${targetdir}/plot.plt
            if [ $app_i != $app ];then

                echo -n " , " >> ./${targetdir}/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/plot.plt
            fi
        done
    done
    # -------- ave --------

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}

    
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

function create_throughput_rtt_graph_gnuplot {
    local img_file
    local targetdir
    local repeat_i

    for repeat_i in `seq ${repeat}` 
    do
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
        cd ${targetdir}
        gnuplot plot.plt 2>/dev/null
        img_file=throughput_${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png
        ln -s  ../../${targetdir}/${img_file} ../../tex/img/
        cd ../..
    done

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/ave
    cd ${targetdir}
    gnuplot plot.plt 2>/dev/null
    img_file=throughput_${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}_ave.png
    ln -s  ../../${targetdir}/${img_file} ../../tex/img/
    cd ../..

}     

function create_throughput_rtt_graph_tex {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}
    local repeat_i
    local tex_file_name=${cgn_ctrl_var}_throughput_rtt_${rootdir}
    
    cd tex

    for repeat_i in `seq ${repeat}` 
    do
        echo "\begin{figure}[htbp]" >> ${tex_file_name}.tex
        echo "\begin{center}" >> ${tex_file_name}.tex
        echo '\includegraphics[width=95mm]' >> ${tex_file_name}.tex
        echo "{img/throughput_${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png}" >> ${tex_file_name}.tex
        echo "\caption{${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var}\% queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_file_name}.tex
        echo '\end{center}
        \end{figure}' >> ${tex_file_name}.tex
    done

    #---------------------ave-------------------------

    echo "\begin{figure}[htbp]" >> ${tex_file_name}_ave.tex
    echo "\begin{center}" >> ${tex_file_name}_ave.tex
    echo '\includegraphics[width=95mm]' >> ${tex_file_name}_ave.tex
    echo "{img/throughput_${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}_ave.png}" >> ${tex_file_name}_ave.tex
    echo "\caption{${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var}\% queue=${queue_var}pkt ${repeat_i}回平均}" >> ${tex_file_name}_ave.tex
    echo '\end{center}
    \end{figure}' >> ${tex_file_name}_ave.tex

    cd ..

}


function create_throughput_rtt_graph {
    local cgn_ctrl_var
    local extended_var
    local loss_var
    local rtt1_var
    local rtt2_var
    local queue_var
    local repeat_i

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for loss_var in "${loss[@]}"
            do
                for queue_var in "${queue[@]}"
                do
                    create_throughput_rtt_graph_plt
                    create_throughput_rtt_graph_gnuplot        
                    create_throughput_rtt_graph_tex
                done
            done
        done
    done
}

function create_throughput_ext_graph_plt {
    local targetdir
    local yrangemax
    local repeat_i

    yrangemax=$(set_yrange_max)

    for repeat_i in `seq ${repeat}` 
    do
        targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 ]; then
                cp ./${targetdir}/app${app_i}.dat ./${targetdir}/graphdata.dat
            else
                join ./${targetdir}/graphdata.dat ./${targetdir}/app${app_i}.dat > ${targetdir}/tmp.dat
                mv ${targetdir}/tmp.dat ./${targetdir}/graphdata.dat
            fi
        done

        awk '{
            total=0
            for (i = 2;i <= NF;i++){
                total += $i;
            }
            printf("%s %f\n",$0,total)

        }' ./${targetdir}/graphdata.dat > ./${targetdir}/graphdata_total.dat

        echo 'set terminal emf enhanced "Arial, 24"
        set terminal png size 960,720
        set ylabel "throughput"
        set key outside
        set size ratio 0.5
        set termoption noenhanced
        set boxwidth 0.5 relative 
        set datafile separator " " ' > ./${targetdir}/plot.plt
        echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/plot.plt 
        echo "set xlabel \"${extended_parameter_name}\"" >> ./${targetdir}/plot.plt 
        echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/plot.plt
        echo "set output \"throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png\"" >> ./${targetdir}/plot.plt

        echo -n "plot " >> ./${targetdir}/plot.plt

        for app_i in `seq ${app}` 
        do
            n=`expr $app_i + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${app_i}\" " >> ./${targetdir}/plot.plt
            if [ $app_i != $app ];then

                echo -n " , " >> ./${targetdir}/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/plot.plt
            fi
        done
    done
    # -------- ave --------

    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}

    
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
    set ylabel "throughput"
    set termoption noenhanced
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set datafile separator " " ' > ./${targetdir}/ave/plot.plt
    echo "set title \"throughput ${targetdir} ${repeat_i} times average \"" >> ./${targetdir}/ave/plot.plt 
    echo "set xlabel \"${extended_parameter_name}\"" >> ./${targetdir}/ave/plot.plt 
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

function create_throughput_ext_graph_gnuplot {
    local img_file
    local targetdir
    local repeat_i

    for repeat_i in `seq ${repeat}` 
    do
        targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
        cd ${targetdir}
        gnuplot plot.plt 2>/dev/null
        img_file=throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png
        ln -s  ../../${targetdir}/${img_file} ../../tex/img/
        cd ../..
    done

    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave
    cd ${targetdir}
    gnuplot plot.plt 2>/dev/null
    img_file=throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_ave.png
    ln -s  ../../${targetdir}/${img_file} ../../tex/img/
    cd ../..

}

function create_throughput_ext_graph_tex {
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local repeat_i
    local tex_file_name=${cgn_ctrl_var}_throughput_ext_${rootdir}
    
    cd tex

    for repeat_i in `seq ${repeat}` 
    do
        echo "\begin{figure}[htbp]" >> ${tex_file_name}.tex
        echo "\begin{center}" >> ${tex_file_name}.tex
        echo '\includegraphics[width=95mm]' >> ${tex_file_name}.tex
        echo "{img/throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png}" >> ${tex_file_name}.tex
        echo "\caption{${cgn_ctrl_var} LOSS=${loss_var}\% rtt1=${rtt1_var} rtt2=${rtt2_var} queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_file_name}.tex
        echo '\end{center}
        \end{figure}' >> ${tex_file_name}.tex
    done

    #---------------------ave-------------------------

    echo "\begin{figure}[htbp]" >> ${tex_file_name}_ave.tex
    echo "\begin{center}" >> ${tex_file_name}_ave.tex
    echo '\includegraphics[width=95mm]' >> ${tex_file_name}_ave.tex
    echo "{img/throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_ave.png}" >> ${tex_file_name}_ave.tex
    echo "\caption{${cgn_ctrl_var} LOSS=${loss_var}\% rtt1=${rtt1_var} rtt2=${rtt2_var} queue=${queue_var}pkt ${repeat_i}回平均}" >> ${tex_file_name}_ave.tex
    echo '\end{center}
    \end{figure}' >> ${tex_file_name}_ave.tex

    cd ..

}

function create_srtt_ext_graph_plt {
    local targetdir
    local pltdir
    local yrangemax
    local repeat_i


    for extended_var in "${extended_parameter[@]}" 
    do
        for repeat_i in `seq ${repeat}` 
        do
            pltdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
            for app_i in `seq ${app}` 
            do
                for subflow_i in `seq ${subflownum}` 
                do
                    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/log
                    awk  -v subflow_i=$subflow_i -v extended_var=$extended_var ' {
                        targetname="srtt"
                        targetname2=targetname"*" 
                        for(i=1;i<=NF;i++){
                            if( match ($i, targetname2) == 1){
                             printf("ext=%s_subflow%s %s\n",extended_var,subflow_i,$(i+1)/1000) 
                                break
                            }
                            
                        }
                    }' ./${targetdir}/cwnd${app_i}_subflow${subflow_i}.dat >> $pltdir/srtt/srtt_boxplot.dat
                done
            done
        done
    done


    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/srtt
    for repeat_i in `seq ${repeat}` 
    do
        echo 'set terminal emf enhanced "Arial, 24"
        set terminal png size 960,720
        set ylabel "srtt [ms]"
        set key off
        set style boxplot fraction 1
        set size ratio 0.5
        set termoption noenhanced
        set xtics rotate by -90
        set boxwidth 0.5 relative 
        set datafile separator " " ' > ./${targetdir}/plot.plt
        echo "set title \"srtt ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/plot.plt 
        echo "set xlabel \"${extended_parameter_name}\"" >> ./${targetdir}/plot.plt 
        echo "set output \"srtt_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png\"" >> ./${targetdir}/plot.plt

        echo -n "plot " >> ./${targetdir}/plot.plt

        echo -n "\"./srtt_boxplot.dat\" using (1.0):2:(0):1 with boxplot  " >> ./${targetdir}/plot.plt
    done
}

function create_srtt_ext_graph_gnuplot {
    local img_file
    local targetdir
    local repeat_i

    for repeat_i in `seq ${repeat}` 
    do
        targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/srtt
        cd ${targetdir}
        gnuplot plot.plt 2>/dev/null
        img_file=srtt_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png
        ln -s  ../../${targetdir}/${img_file} ../../../tex/img/
        cd ../../..
    done

}

function create_srtt_ext_graph_tex {
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local repeat_i
    local tex_file_name=${cgn_ctrl_var}_srtt_ext_${rootdir}
    
    cd tex

    for repeat_i in `seq ${repeat}` 
    do
        echo "\begin{figure}[htbp]" >> ${tex_file_name}.tex
        echo "\begin{center}" >> ${tex_file_name}.tex
        echo '\includegraphics[width=95mm]' >> ${tex_file_name}.tex
        echo "{img/srtt_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png}" >> ${tex_file_name}.tex
        echo "\caption{${cgn_ctrl_var} LOSS=${loss_var}\% rtt1=${rtt1_var} rtt2=${rtt2_var} queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_file_name}.tex
        echo '\end{center}
        \end{figure}' >> ${tex_file_name}.tex
    done

    cd ../
}


function create_ext_graph {
    local cgn_ctrl_var
    local extended_var
    local loss_var
    local rtt1_var
    local rtt2_var
    local queue_var
    local repeat_i

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for loss_var in "${loss[@]}"
        do
            for rtt1_var in "${rtt1[@]}"
            do
                for rtt2_var in "${rtt2[@]}"
                do 
                    check_rtt_combination || continue 
                    for queue_var in "${queue[@]}"
                    do
                        create_throughput_ext_graph_plt
                        create_throughput_ext_graph_gnuplot
                        create_throughput_ext_graph_tex

                        create_srtt_ext_graph_plt
                        create_srtt_ext_graph_gnuplot
                        create_srtt_ext_graph_tex
                    done
                done
            done
        done
    done
}

function calc_combination_number_of_rtt {
    local result

    if [ ${rtt_all_combination} = 1 ]; then
        result=$(nHr ${#rtt1[@]} 2)
    else
        result=${#rtt1[@]}
    fi

    echo $result
}

function process_log_data {
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local app_meta=()
    local total_count=`echo "scale=1; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    local current_count=0

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for loss_var in "${loss[@]}"
            do
                for rtt1_var in "${rtt1[@]}"
                do
                    for rtt2_var in "${rtt2[@]}"
                    do
                        check_rtt_combination || continue 
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
    done
    create_ext_graph
    create_throughput_rtt_graph
    deleat_and_compress_processed_log_data
    echo "processing data ...done                                    "
}

function deleat_and_compress_processed_log_data {
    local targetdir
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for loss_var in "${loss[@]}"
            do
                for rtt1_var in "${rtt1[@]}"
                do
                    for rtt2_var in "${rtt2[@]}"
                    do
                        check_rtt_combination || continue 
                        for queue_var in "${queue[@]}"
                        do
                            for repeat_i in `seq ${repeat}` 
                            do
                                targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/log
                                cd ${targetdir}
                                tar cvzf kern.dat.tar.gz kern.dat > /dev/null 2>&1

                                rm -f *.dat 
                                cd ../../../

                            done
                        done    
                    done
                done
            done
        done
    done
 
}

function platex_dvipdfmx_link {
    local tex_file_name=$1

    platex -halt-on-error -interaction=nonstopmode ${tex_file_name}.tex > /dev/null 2>&1
    dvipdfmx ${tex_file_name}.dvi > /dev/null 2>&1
    ln -sf tex/${tex_file_name}.pdf ../

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
            platex_dvipdfmx_link ${cgn_ctrl_var}_${item_var}_${rootdir} 
        done

        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_queue_${rootdir} 

        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_queue_${rootdir}_ave
        
        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_rtt_${rootdir}
        
        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_rtt_${rootdir}_ave

        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_time_${rootdir}

        platex_dvipdfmx_link ${cgn_ctrl_var}_alldata_${rootdir}

        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_ext_${rootdir}
        
        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_ext_${rootdir}_ave

        platex_dvipdfmx_link ${cgn_ctrl_var}_srtt_ext_${rootdir}

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

function join_header {
    local tex_file_name=$1
    cat ./tex_header.txt ./${tex_file_name}.tex > tmp.tex
    mv tmp.tex ./${tex_file_name}.tex 
    rm ./tex_header.txt
    echo "\end{document}" >> ${tex_file_name}.tex
}

function join_header_and_tex_file {
    local var
    local tex_file_name
    cd tex  

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for item_var in "${item_to_create_graph[@]}" 
        do
            tex_file_name=${cgn_ctrl_var}_${item_var}_${rootdir}
            create_tex_header ${item_var}
            join_header ${tex_file_name}     
        done

        tex_file_name=${cgn_ctrl_var}_throughput_queue_${rootdir}
        create_tex_header "Throughput queue"
        join_header ${tex_file_name}
        create_tex_header "Throughput queue ${repeat} repeat"
        join_header ${tex_file_name}_ave

        tex_file_name=${cgn_ctrl_var}_throughput_rtt_${rootdir}
        create_tex_header "Throughput rtt"
        join_header ${tex_file_name}
        create_tex_header "Throughput rtt ${repeat} repeat"
        join_header ${tex_file_name}_ave

        tex_file_name=${cgn_ctrl_var}_throughput_time_${rootdir}
        create_tex_header "Throughput time"
        join_header ${tex_file_name}

        tex_file_name=${cgn_ctrl_var}_alldata_${rootdir}
        create_tex_header "Alldata"
        join_header ${tex_file_name}

        tex_file_name=${cgn_ctrl_var}_throughput_ext_${rootdir}
        create_tex_header "Throughput ext"
        join_header ${tex_file_name}
        create_tex_header "Throughput ext ${repeat} repeat"
        join_header ${tex_file_name}_ave

        tex_file_name=${cgn_ctrl_var}_srtt_ext_${rootdir}
        create_tex_header "srtt ext"
        join_header ${tex_file_name}
        
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
        for extended_var in "${extended_parameter[@]}" 
        do
            for rtt1_var in "${rtt1[@]}"
            do
                for rtt2_var in "${rtt2[@]}"
                do
                    check_rtt_combination || continue 
                    for loss_var in "${loss[@]}"
                    do
                        for queue_var in "${queue[@]}"
                        do
                            for repeat_i in `seq ${repeat}` 
                            do
                                targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
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
                                gnuplot ${targetname}_xrange[${start_point},${end_point}].plt 2>/dev/null
                                echo "done"
                                cd ../..
                            done
                        done    
                    done
                done
            done
        done
    done


}

function change_graph_yrange {
    local cgn_ctrl_var  
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    
    echo "Please selecet target name"
    select targetname in "Throughput" "exit"
    do
        if [ $targetname = "Throughput" ];then
            targetname=plot
            break
        elif [ "${targetname}" = "exit" ]; then
            exit
        fi
    done

    echo "Please input y range [y1 y2]"
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
            echo "incorrect input. Please retype [y1 y2]"
            echo -n ">"
        fi
    done

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for rtt1_var in "${rtt1[@]}"
            do
                for rtt2_var in "${rtt2[@]}"
                do
                    check_rtt_combination || continue 
                    for loss_var in "${loss[@]}"
                    do
                        for repeat_i in `seq ${repeat}` 
                        do
                            targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}/${repeat_i}th
                            echo -n "$targetdir ..."                           
                            cd $targetdir
                            awk -v startpoint=${start_point} -v endpoint=${end_point} -v scale=${scale} '{
                                if($2~"yrange"){
                                    printf("set yrange [%s:%s]\n",startpoint,endpoint) 
                                }else{
                                    print
                                }
                            }' ${targetname}.plt > ${targetname}_yrange[${start_point},${end_point}].plt
                            gnuplot ${targetname}_yrange[${start_point},${end_point}].plt 2>/dev/null
                            echo "done"
                            cd ../..
                        done
                    done
                done
            done
        done
    done

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for queue_var in "${queue[@]}"
            do
                check_rtt_combination || continue 
                for loss_var in "${loss[@]}"
                do
                    for repeat_i in `seq ${repeat}` 
                    do
                        targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
                        echo -n "$targetdir ..."                           
                        cd $targetdir
                        awk -v startpoint=${start_point} -v endpoint=${end_point} -v scale=${scale} '{
                            if($2~"yrange"){
                                printf("set yrange [%s:%s]\n",startpoint,endpoint) 
                            }else{
                                print
                            }
                        }' ${targetname}.plt > ${targetname}_yrange[${start_point},${end_point}].plt
                        gnuplot ${targetname}_yrange[${start_point},${end_point}].plt 2>/dev/null
                        echo "done"
                        cd ../..
                    done
                done
            done
        done
    done


}

function decompression_and_reprocess_log_data {
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local app_meta=()
    local total_count=`echo "scale=1; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    local current_count=0

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for loss_var in "${loss[@]}"
            do
                for rtt1_var in "${rtt1[@]}"
                do
                    for rtt2_var in "${rtt2[@]}"
                    do
                        check_rtt_combination || continue 
                        for queue_var in "${queue[@]}"
                        do
                            for repeat_i in `seq ${repeat}` 
                            do
                                targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/log
                                cd ${targetdir}
                                tar xzf kern.dat.tar.gz  > /dev/null 2>&1
                                cd ../../../
                                percent=`echo "scale=3; $current_count / $total_count * 100 " | bc`
                                percent=`echo "scale=1; $percent / 1 " | bc`
                                echo -ne "reprocessing data ...${percent}% (${current_count} / ${total_count})\r"
                                separate_cwnd
                                get_app_meta
                                extract_cwnd_each_flow
                                count_mptcp_state
                                (( current_count++))
                            done
                        done    
                    done
                done
            done
        done
    done
    echo "reprocessing data ...done                                    "
}
