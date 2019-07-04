#!/bin/bash

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
        eth0=eth0
        eth1=eth1
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
   ping $receiver_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "error: can't access to receiver [$receiver_ip]"
        exit
   fi
   ping $D1_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "error: can't access to D1 [$D1_ip]"
        exit
   fi
    ping $D2_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "error: can't access to D2 [$D2_ip]"
        exit
   fi

    echo "network is ok."
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
    echo "app_delay ${app_delay}" >> setting.txt
    echo "repeat ${repeat}" >> setting.txt
    echo "interval ${interval}" >> setting.txt
    echo "no_cwr ${no_cwr}" >> setting.txt
    echo "no_rcv ${no_rcv}" >> setting.txt
    echo "no_small_queue ${no_small_queue}" >> setting.txt
    echo "qdisc ${qdisc}" >> setting.txt
    echo "subflownum ${subflownum}" >> setting.txt
    echo "item_to_create_graph ${item_to_create_graph[@]}" >> setting.txt
    echo "memo ${memo}" >> setting.txt


}

function set_kernel_variable {
    sysctl net.mptcp.mptcp_debug=1
    sysctl net.mptcp.mptcp_enabled=1
    #sysctl net.core.default_qdisc=${qdisc}
    #sysctl net.mptcp.mptcp_no_small_queue=${no_small_queue}
    #sysctl net.mptcp.mptcp_change_small_queue=${change_small_queue}
    #sysctl net.mptcp.mptcp_no_cwr=${no_cwr}
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
			iperf -c ${receiver_ip} -t $delay -i $interval > ./${nowdir}/${repeat_i}th/throughput/app${app_i}.dat
		else
			iperf -c ${receiver_ip} -t $delay -i $interval > ./${nowdir}/${repeat_i}th/throughput/app${app_i}.dat &
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
            }
        }
        exit
    }' ./${targetdir}/log/cwnd1_subflow1.dat)
    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set key outside
    set key spacing 8
    set size ratio 0.5
    set xlabel "time[s]"
    set ylabel "number of packets"
    set datafile separator " " ' > ${targetdir}/${targetname}.plt
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

function calc_throughput_ave {
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local app_i
    local repeat_i
    mkdir ${targetdir}/ave
    mkdir ${targetdir}/ave/throughput

    for app_i in `seq ${app}` 
    do
        for repeat_i in `seq ${repeat}` 
        do
            awk 'END{
                if(NF==9){
              if($9 ~ "Kbits/sec"){	
                printf("%s Mbits/sec\n",$8/1000);
              }else{
                printf("%s %s\n",$8,$9);		
              }
                    
                }else{
              if($8 ~ "Kbits/sec"){	
                printf("%s Mbits/sec\n",$7/1000);
              }else{
                printf("%s %s\n",$7,$8);		
              }
                }
                
            }' ./${targetdir}/${repeat_i}th/throughput/app${app_i}.dat >> ./${targetdir}/ave/throughput/app${app_i}.dat

            awk 'END{
                if(NF==9){
              if($9 ~ "Kbits/sec"){	
                printf("%s\n",$8/1000);
              }else{
                printf("%s\n",$8);		
              }
                    
                }else{
                    if($8 ~ "Kbits/sec"){	
                printf("%s\n",$7/1000);
              }else{
                printf("%s\n",$7);		
              }
                }
            }' ./${targetdir}/${repeat_i}th/throughput/app${app_i}.dat >> ./${targetdir}/${repeat_i}th/throughput/app${app_i}_.dat
                
        done

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

function create_throughput_graph_plt {
    local repeat_i 
    local app_i
    local queue_var
    local throughput
    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    mkdir ${targetdir}
    for repeat_i in `seq ${repeat}` 
    do
        mkdir ${targetdir}/${repeat_i}th
    done

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
        echo "set yrange [0:200]" >> ./${targetdir}/${repeat_i}th/plot.plt
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


    mkdir ${targetdir}/ave

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
    echo "set yrange [0:200]" >> ./${targetdir}/ave/plot.plt
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

function create_throughput_graph {
    local targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    local img_file
    create_throughput_graph_plt

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
    ln -s  ../../${targetdir}/${repeat_i}th/${img_file} ../../tex/img/

    cd ../..
}

function create_throughput_tex {
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
    echo "{${targetdir}/ave/throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_ave.png}" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo "\caption{${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% ${repeat_i}回平均}" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo '\end{center}
    \end{figure}' >> ${tex_file_name}_ave.tex

    cd ..
}

function process_log_data {
    local cgn_ctrl_var  
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local app_meta=()
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
                            separate_cwnd
                            get_app_meta
                            extract_cwnd_each_flow
                            count_mptcp_state
                            create_graph_img
                            create_tex_file
                        done
                        calc_throughput_ave
                    done    
                    create_throughput_graph
                    create_throughput_tex
                done
            done
        done
    done

}

function build_tex_to_pdf {
    local cgn_ctrl_var
    local item_ver
    cd tex 

    if !(type platex > /dev/null 2>&1); then
       echo "platex does not exist."
       return 1
    fi

    echo "Make tex file ..."
    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for item_var in "${item_to_create_graph[@]}" 
        do
            platex -halt-on-error ${cgn_ctrl_var}_${item_var}_${today}.tex > /dev/null
            dvipdfmx ${cgn_ctrl[$z]}_${item_var}_${today}.dvi > /dev/null

        done
        platex -halt-on-error ${cgn_ctrl_var}_throughput_${today}.tex > /dev/null
        dvipdfmx ${cgn_ctrl_var}_throughput_${today}.dvi > /dev/null

        platex -halt-on-error ${cgn_ctrl_var}_throughput_${today}_ave.tex > /dev/null
        dvipdfmx ${cgn_ctrl_var}_throughput_${today}_ave.dvi > /dev/null

        rm -f ${cgn_ctrl_var}*.log
        rm -f ${cgn_ctrl_var}*.dvi
        rm -f ${cgn_ctrl_var}*.aux
    done

    cd ..
}

function create_tex_header {
    local item_name=$1



    echo '
    \documentclass{jsarticle}
    \usepackage[dvipdfmx]{graphicx}
    \usepackage{grffile}
    \usepackage[top=0truemm,bottom=0truemm,left=0truemm,right=0truemm]{geometry}
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
            echo "ok."
            break
        else
            echo "incorrect input. Please retype [x1 x2]"
            echo -n ">"
        fi
    done

    scale=`echo "scale=1; (${end_point} - ${start_point}) / 5.0" | bc`
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
                            targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
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
                            cd ../..
                        done
                    done    
                done
            done
        done
    done


}
