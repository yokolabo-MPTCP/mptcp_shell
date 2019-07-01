#!/bin/bash

function get_mptcp_version () {

    local kernel=$(uname -r)

    if [[ $kernel == *3.5.7* ]]; then
        mptcp_ver=0.86
    elif [[ $kernel == *4.4.88* ]]; then
        mptcp_ver=0.92
    elif [[ $kernel == *4.4.110* ]]; then
        mptcp_ver=0.92
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

    if [ $mptcp_ver = 0.92 ]; then
        #receiver_ip=192.168.15.2
        #D1_ip=192.168.3.2
        #D2_ip=192.168.4.2
        #eth0=eth0
        #eth1=eth1

        receiver_ip=192.168.11.1
        D1_ip=192.168.1.2
        D2_ip=192.168.2.2
        eth0=enp0s3
        eth1=enp0s8
     elif [ $mptcp_ver = 0.86 ]; then
        receiver_ip=192.168.13.1
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=eth0
        eth1=eth1
    else
        receiver_ip=192.168.13.1
        D1_ip=192.168.3.2
        D2_ip=192.168.4.2
        eth0=eth0
        eth1=eth1
    fi
    

}

function check_network_available {
   ping receiver_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "error: can't access to receiver [$receiver_ip]"
        exit
   fi
   ping D1_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "error: can't access to D1 [$D1_ip]"
        exit
   fi
    ping D2_ip -c 1 >> /dev/null
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

function count_mptcp_state {
    local app_i
    local subflow_i
    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            grep -ic "send_stall" cwnd${app_i}_subflow${subflow_i}.dat > cwnd${app_i}_subflow${subflow_i}_sendstall.dat

        done
    done

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            grep -ic "cwnd_reduced" cwnd${app_i}_subflow${subflow_i}.dat > cwnd${app_i}_subflow${subflow_i}_cwndreduced.dat
        done
    done

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            grep -ic "rcv_buf" cwnd${app_i}_subflow${subflow_i}.dat > cwnd${app_i}_subflow${subflow_i}_rcv_buf.dat
        done
    done
}

function create_plt_file {
    local app_i
    local subflow_i
    local targetname=$1
    local scale=$((second / 5))
    
    if [ $# -ne 1 ]; then
        echo "create_plt_file:argument error"
        exit 1
    fi


    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set key outside
    set key spacing 8
    set size ratio 0.5
    set xlabel "time[s]"
    set ylabel "number of packets"
    set datafile separator " " ' > ${targetname}.plt
    echo "set xtics $scale" >> ${targetname}.plt
    echo "set xrange [0:${dulation}]" >> ${targetname}.plt
    echo "set output \"cwnd_${nowdir}_${repeat}th.png\"" >> ${targetname}.plt

    echo -n "plot " >> ${targetname}.plt

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            cwndreduced=$(awk 'NR==1' ./log/cwnd${app_i}_subflow${subflow_i}_cwndreduced.dat)
            sendstall=$(awk 'NR==1' ./log/cwnd${app_i}_subflow${subflow_i}_sendstall.dat)
            rcv_buf=$(awk 'NR==1' ./log/cwnd${app_i}_subflow${subflow_i}_rcv_buf.dat)
            echo -n "\"./log/cwnd${app_i}_subflow${subflow_i}.dat\" using 1:7 with lines linewidth 2 title \"APP${app_i} : subflow${subflow_i}   \n sendstall=${sendstall}\nrcvbuf=${rcv_buf}\" " >> ${targetname}.plt
            if [ $app_i != $app ] || [ $subflow_i != $subflownum ];then

               echo -n " , " >> ${targetname}.plt
                
            fi
        done
    done
}

function create_graph_img {

    local var

    for var in "${item_to_create_graph[@]}" 
    do
        create_plt_file $var
        gnuplot $var 
    done

}

function create_each_tex_file {
    local targetname=$1
    
    if [ $# -ne 1 ]; then
        echo "create_plt_file:argument error"
        exit 1
    fi

    
    echo "\begin{figure}[htbp]" >> ${cgn_ctrl_var}_${targetname}_${today}.tex
    echo "\begin{center}" >> ${cgn_ctrl_var}_${targetname}_${today}.tex
    echo '\includegraphics[width=95mm]' >> ${cgn_ctrl_var}_${targetname}_${today}.tex
    echo "{${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/${targetname}_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png}" >> ${cgn_ctrl}_${targetname}_${today}.tex
    echo "\caption{${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% queue=${queue_var}pkt ${repeat_i}回目}" >> ${cgn_ctrl_var}_${targetname}_${today}.tex
    echo '\end{center}
    \end{figure}' >> ${cgn_ctrl_var}_${targetname}_${today}.tex
    #if [ $clearpage = 1 ]; then 
    #    echo "\clearpage" >> ${cgn_ctrl_var}_${targetname}_${today}.tex
    #fi  
}

function create_tex_file {

    local var

    for var in "${item_to_create_graph[@]}" 
    do
        create_each_tex_file $var
    done


}

function calc_throughput_ave {
    local app_i
    local repeat_i
    mkdir ave
    mkdir ave/throughput

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
                
            }' ./${repeat_i}th/throughput/app${app_i}.dat >> ./ave/throughput/app${app_i}.dat

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
            }' ./${repeat_i}th/throughput/app${app_i}.dat >> ./${repeat_i}th/throughput/app${app_i}_.dat
                
        done

        awk -v repeat=${repeat} 'BEGIN{
                total=0
            }{
                total = total + $1
            }END{
            total = total / repeat
            printf("%s\n",total);
        }' ./ave/throughput/app${app_i}.dat >> ./ave/throughput/app${app_i}_ave.dat
    done
}

function create_throughput_graph {
    local repeat_i 
    local app_i
    local queue_var
    local throughput
    nowdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    mkdir ${targetdir}
    for repeat_i in `seq ${repeat}` 
    do
        mkdir ${nowdir}/${repeat_i}th
    done

    for repeat_i in `seq ${repeat}` 
    do
        for queue_var in "${queue[@]}"
        do
            for app_i in `seq ${app}` 
            do
                throughput=$(cat ${cgn_ctrl}_rtt1=${rtt1}_rtt2=${rtt2}_loss=${loss}_queue=${queue_var}/${repeat_i}th/throughput/app${app_i}_.dat)
                echo "${queue_var} ${throughput}" >> ./${nowdir}/${repeat_i}th/app${app_i}.dat
            done
        done

        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 ]; then
                cp ./${nowdir}/${repeat_i}th/app${app_i}.dat ./${nowdir}/${repeat_i}th/graphdata.dat
            else
                join ./${nowdir}/${repeat_i}th/graphdata.dat ./${nowdir}/${repeat_i}th/app${app_i}.dat > ${nowdir}/${repeat_i}th/tmp.dat
                mv ${nowdir}/${repeat_i}th/tmp.dat ./${nowdir}/${repeat_i}th/graphdata.dat
            fi
        done

        awk '{
            total=0
            for (i = 2;i <= NF;i++){
                total += $i;
            }
            printf("%s %f\n",$0,total)

        }' ./${nowdir}/${repeat_i}th/graphdata.dat > ./${nowdir}/${repeat_i}th/graphdata_total.dat

        echo 'set terminal emf enhanced "Arial, 24"
        set terminal png size 960,720
        set xlabel "queue"
        set ylabel "throughput"
        set key outside
        set size ratio 0.5
        set boxwidth 0.5 relative 
        set datafile separator " " ' > ./${nowdir}/${repeat_i}th/plot.plt
        echo "set title \"throughput ${nowdir} ${repeat_i}th\"" >> ./${nowdir}/${repeat_i}th/plot.plt 
        echo "set yrange [0:200]" >> ./${nowdir}/${repeat_i}th/plot.plt
        echo "set output \"throughput_${nowdir}_${repeat_i}th.png\"" >> ./${nowdir}/${repeat_i}th/plot.plt

        echo -n "plot " >> ./${nowdir}/${repeat_i}th/plot.plt

        for app_i in `seq ${app}` 
        do
            n=`expr $app_i + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${app_i}\" " >> ./${nowdir}/${repeat_i}th/plot.plt
            if [ $app_i != $appnum ];then

                echo -n " , " >> ./${nowdir}/${repeat_i}th/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${nowdir}/${repeat_i}th/plot.plt
            fi
        done

        cd ./${nowdir}/${repeat_i}th/
        gnuplot "./plot.plt"
        cd ../../
        #gnuplot "./${nowdir}/${repeat_i}th/plot.plt"

        cp ${nowdir}/${repeat_i}th/throughput_${nowdir}_${repeat_i}th.png ./${nowdir}

    done 


    mkdir ${nowdir}/ave

    for queue_var in "${queue[@]}"
    do
        for app_i in `seq ${app}` 
        do
            throughput=$(cat ${cgn_ctrl}_rtt1=${rtt1}_rtt2=${rtt2}_loss=${loss}_queue=${queue_var}/ave/throughput/app${app_i}_ave.dat)
            echo "${queue_var} ${throughput}" >> ./${nowdir}/ave/app${app_i}dat
        done
    done

    for app_i in `seq ${app}` 
    do
        if [ $app_i -eq 1 ]; then
            cp ./${nowdir}/ave/app${app_i}.dat ./${nowdir}/ave/graphdata.dat
        else
            join ./${nowdir}/ave/graphdata.dat ./${nowdir}/ave/app${app_i}.dat > ${nowdir}/ave/tmp.dat
            mv ${nowdir}/ave/tmp.dat ./${nowdir}/ave/graphdata.dat
        fi
    done

    awk '{
    total=0
    for (i = 2;i <= NF;i++){
        total += $i;
    }
    printf("%s %f\n",$0,total)

    }' ./${nowdir}/ave/graphdata.dat > ./${nowdir}/ave/graphdata_total.dat

    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set xlabel "queue"
    set ylabel "throughput"
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set datafile separator " " ' > ./${nowdir}/ave/plot.plt
    echo "set title \"throughput ${nowdir} ${repeat} times average \"" >> ./${nowdir}/ave/plot.plt 
    echo "set yrange [0:200]" >> ./${nowdir}/ave/plot.plt
    echo "set output \"throughput_${nowdir}_ave.png\"" >> ./${nowdir}/ave/plot.plt

    echo -n "plot " >> ./${nowdir}/ave/plot.plt

    for app_i in `seq ${app}` 
    do
        n=`expr $app_i + 1`
        echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${app_i}\" " >> ./${nowdir}/ave/plot.plt
        if [ $app_i != $appnum ];then

        echo -n " , " >> ./${nowdir}/ave/plot.plt
        else
         n=`expr $n + 1`
         echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${nowdir}/ave/plot.plt
        fi

    done

    cd ./${nowdir}/ave/
    gnuplot "./plot.plt"
    cd ../../

}

function create_throughput_tex {
    local repeat_i

    for repeat_i in `seq ${repeat}` 
    do
        echo "\begin{figure}[htbp]" >> ${cgn_ctrl_var}_throughput_${today}.tex
        echo "\begin{center}" >> ${cgn_ctrl_var}_throughput_${today}.tex
        echo '\includegraphics[width=95mm]' >> ${cgn_ctrl_var}_throughput_${today}.tex
        echo "{${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}/${repeat_i}th/throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_${repeat_i}th.png}" >> ${cgn_ctrl_var}_throughput_${today}.tex
        echo "\caption{${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% ${repeat_i}回目}" >> ${cgn_ctrl_var}_throughput_${today}.tex
        echo '\end{center}
        \end{figure}' >> ${cgn_ctrl_var}_throughput_${today}.tex
    done

#---------------------ave-------------------------

    echo "\begin{figure}[htbp]" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo "\begin{center}" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo '\includegraphics[width=95mm]' >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo "{${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}/ave/throughput_${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_ave.png}" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo "\caption{${cgn_ctrl_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms LOSS=${loss_var}\% ${repeat}回平均}" >> ${cgn_ctrl_var}_throughput_${today}_ave.tex
    echo '\end{center}
    \end{figure}' >> ${cgn_ctrl_var}_throughput_${today}_ave.tex


}

function process_log_data {
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
                            count_mptcp_state
                            create_graph_img
                            create_tex_file
                        done
                        cd ../
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

    
}
