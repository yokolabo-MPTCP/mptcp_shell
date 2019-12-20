#!/bin/bash

function get_slave_available_disk_space {
    local sender_i
    local target_ip
    local disk_data
    unset disk[@]
    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        disk_data=$(ssh root@${!target_ip} "df | grep sda2 | awk '{print \$4}'") 
        disk_data=`echo "scale=3;${disk_data} / 1000000  " | bc`
        disk=("${disk[@]}" ${disk_data})
    done
}

function echo_disk_space {
    local i
    local disk_i
    get_slave_available_disk_space
    echo -n "空き容量: "
    i=1
    for disk_i in "${disk[@]}"
    do
        echo -n "[sender${i}] ${disk_i}GB "
        let i++
    done
    echo ""
}

function calc_used_disk_space {
    local data
    local i
    local disk_i

    for disk_i in "${disk[@]}"
    do
        before_disk+=(${disk_i})
    done

    get_slave_available_disk_space
    echo -n "使用容量: "
    i=1
    for disk_i in "${!disk[@]}"
    do
        data=`echo "scale=3;${before_disk[$disk_i]} - ${disk[$disk_i]}  " | bc`
        echo -n "[sender${i}] ${data}GB "
        let i++
    done
    echo ""
}

function calc_used_disk_space2 {
    local data
    local i
    local disk_i

    get_slave_available_disk_space
    echo -n "使用容量: "
    i=1
    for disk_i in "${!disk[@]}"
    do
        data=`echo "scale=3;${before_disk[$disk_i]} - ${disk[$disk_i]} " | bc`
        echo -n "[sender${i}] ${data}GB "
        let i++
    done
    echo ""
}

function echo_slave {
    local str=$1
    local str2=$2
    local echo_pos
    local hostname_i
    local space=20
    local str_len=${#str}

    if [ $(hostname) == "master" ]; then
        echo_pos=$str_len 
    else
        hostname_i=$(hostname)
        hostname_i=${hostname_i:6:1}
        echo_pos=`echo "scale=1;${str_len} + (${hostname_i} * ${space}) " | bc`
    fi
    echo -ne "\033[100D${str}\033[${echo_pos}C[$(hostname)]$str2"

}

function receive_all_data_pdf {
    local sender_i
    local target_ip
    
    echo -ne "[$(hostname)]Receiving pdf from each sender... \r" 
    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        scp root@${!target_ip}:${senderdir}/${rootdir}/tex/*.pdf ./sender${sender_i} >/dev/null &

    done

    wait
    echo "[$(hostname)]Receiving pdf from each sender ...done" 


}
function copy_slave_throughput {
    local target_ip
    local sender_i
    local app_i

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            target_ip="sender${sender_i}_ip"
            targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/throughput
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/throughput
            scp root@${!target_ip}:${senderdir}/${rootdir}/${targetdir}/app${app_i}_.dat ./${targetmasterdir}/sender${sender_i}_app${app_i}.dat > /dev/null &
        done
    done
    wait
}

function copy_slave_throughput_ave {
    local target_ip
    local sender_i
    local app_i

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            target_ip="sender${sender_i}_ip"
            targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave/throughput
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave/throughput
            scp root@${!target_ip}:${senderdir}/${rootdir}/${targetdir}/app${app_i}_ave.dat ./${targetmasterdir}/sender${sender_i}_app${app_i}_ave.dat > /dev/null &
        done
    done
    wait

}

function process_alldata_master {
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local targetmasterdir
    local app_meta=()
    local current_count=0
    local start_time
    local one_time
    local r_time
    local current_count=0
    local total_count
    
    total_count=`echo "scale=1; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    echo -ne "[$(hostname)]Processing alldata ...\r"
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
                                echo -ne "[$(hostname)]Processing alldata ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                                copy_slave_alldata
                                shift_time_alldata
                                ((current_count++))
                            done
                        done    
                    done
                done
            done
        done
    done
    echo "[$(hostname)]Processing alldata ...done (${current_count} / ${total_count})                            "


}

function shift_time_alldata {
    local target_ip
    local sender_i
    local app_i
    local targetmasterdir
    local targetdir
    local count_item
    local time_adjust

    #echo -ne "[$(hostname)]Shifting time ... \r"

    for sender_i in `seq ${sender_num}` 
    do
        (
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/
            for app_i in `seq ${app}` 
            do
                for subflow_i in `seq ${subflownum}` 
                do
                    if [ $sender_i != "1" ]; then
                        time_adjust=`echo "scale=3; (${sender_i} - 1) * ${sender_delay} " | bc`
                        awk -v delay=${time_adjust} '{
                           printf ("%f ",$1 + delay);
                           for(i=2;i<=NF;i++){
                               printf $i" ";
                           }
                           printf("\n");

                        }' ./${targetmasterdir}/log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}.dat > ./${targetmasterdir}/log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}_tmp.dat
                        mv -f ./${targetmasterdir}/log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}_tmp.dat ./${targetmasterdir}/log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}.dat
                    fi
                done

                if [ $sender_i != "1" ]; then
                    time_adjust=`echo "scale=3; (${sender_i} - 1) * ${sender_delay} " | bc`
                    awk -v delay=${time_adjust} '{
                       printf ("%f ",$1 + delay);
                       for(i=2;i<=NF;i++){
                           printf $i" ";
                       }
                       printf("\n");

                    }' ./${targetmasterdir}/throughput/sender${sender_i}_app${app_i}_time.dat > ./${targetmasterdir}/throughput/sender${sender_i}_app${app_i}_tmp.dat
                    mv -f ./${targetmasterdir}/throughput/sender${sender_i}_app${app_i}_tmp.dat ./${targetmasterdir}/throughput/sender${sender_i}_app${app_i}_time.dat
                fi
            done
        ) &
    done

    wait
    #echo  "[$(hostname)]Shifting time ... done"

   
}
function copy_slave_alldata {
    local target_ip
    local sender_i
    local app_i
    local targetmasterdir
    local targetdir
    local count_item

    #echo -ne "[$(hostname)]Receiving alldata ...\r"

    for sender_i in `seq ${sender_num}` 
    do
        (
            target_ip="sender${sender_i}_ip"
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/
            targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/
            for app_i in `seq ${app}` 
            do
                for subflow_i in `seq ${subflownum}` 
                do
                    #echo -ne "[$(hostname)]copying alldata ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                    scp root@${!target_ip}:${senderdir}/${rootdir}/${targetdir}/log/cwnd${app_i}_subflow${subflow_i}.dat ${targetmasterdir}/log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}.dat>/dev/null 
                    for count_item in ${item_to_count_state[@]}
                    do
                        scp root@${!target_ip}:${senderdir}/${rootdir}/${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_${count_item}.dat ${targetmasterdir}/log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}_${count_item}.dat >/dev/null
                    done
                done
                scp root@${!target_ip}:${senderdir}/${rootdir}/${targetdir}/throughput/app${app_i}_graph.dat ${targetmasterdir}/throughput/sender${sender_i}_app${app_i}_time.dat >/dev/null
            done
        ) &
    done

    wait
    #echo "[$(hostname)]Receiving alldata ... done        "

}

function process_throughput_master {
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local targetdir
    local targetmasterdir
    local app_meta=()
    local current_count=0
    local start_time
    local one_time
    local r_time

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
                                copy_slave_throughput
                                copy_throughput_queue
                                copy_throughput_cgnctrl
                                copy_throughput_ext
                                copy_throughput_rtt
                            done
                            copy_slave_throughput_ave
                            copy_throughput_queue_ave
                            copy_throughput_cgnctrl_ave
                            copy_throughput_ext_ave
                            copy_throughput_rtt_ave
                        done    
                    done
                done
            done
        done
    done
}

function copy_throughput_rtt {
    local target_ip
    local sender_i
    local app_i
    local throughput

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/throughput
            throughput=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}.dat)
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
            echo "${rtt1_var},${rtt2_var} ${throughput}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done
}

function copy_throughput_ext {
    local target_ip
    local sender_i
    local app_i
    local throughput

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/throughput
            throughput=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}.dat)
            targetmasterdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
            echo "${extended_var} ${throughput}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done
}

function copy_throughput_queue {
    local target_ip
    local sender_i
    local app_i
    local throughput

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/throughput
            throughput=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}.dat)
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}/${repeat_i}th
            echo "${queue_var} ${throughput}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done
}

function copy_throughput_cgnctrl {
    local target_ip
    local sender_i
    local app_i
    local throughput

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/throughput
            throughput=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}.dat)
            targetmasterdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
            echo "${cgn_ctrl_var} ${throughput}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done
}
function copy_throughput_rtt_ave {
    local target_ip
    local sender_i
    local app_i
    local throughputave

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave/throughput
            throughputave=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}_ave.dat)
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/ave
            echo "${rtt1_var},${rtt2_var} ${throughputave}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done

}
function copy_throughput_rtt_ave {
    local target_ip
    local sender_i
    local app_i
    local throughputave

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave/throughput
            throughputave=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}_ave.dat)
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}/ave
            echo "${rtt1_var},${rtt2_var} ${throughputave}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done

}
function copy_throughput_ext_ave {
    local target_ip
    local sender_i
    local app_i
    local throughputave

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave/throughput
            throughputave=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}_ave.dat)
            targetmasterdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave
            echo "${extended_var} ${throughputave}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done

}

function copy_throughput_queue_ave {
    local target_ip
    local sender_i
    local app_i
    local throughputave

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave/throughput
            throughputave=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}_ave.dat)
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}/ave
            echo "${queue_var} ${throughputave}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done

}


function copy_throughput_cgnctrl_ave {
    local target_ip
    local sender_i
    local app_i
    local throughput

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            targetmasterdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave/throughput
            throughput=$(cat ${targetmasterdir}/sender${sender_i}_app${app_i}_ave.dat)
            targetmasterdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/ave
            echo "${cgn_ctrl_var} ${throughput}" >> ${targetmasterdir}/sender${sender_i}_app${app_i}.dat
        done
    done
}

function create_graph_and_tex_master {
    local total_count
    local current_count=0
    total_count=`echo "scale=1; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    total_count=`echo "scale=1; ${total_count} + ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} " | bc`
    total_count=`echo "scale=1; ${total_count} + ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]}  " | bc`
    total_count=`echo "scale=1; ${total_count} + ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#loss[@]} * ${#queue[@]}" | bc`
    create_queue_graph_and_tex_master 
    create_cgnctrl_graph_and_tex_master 
    create_time_graph_and_tex_master 
    create_ext_graph_and_tex_master 
    create_rtt_graph_and_tex_master 
    create_cgnctrl_all_each_graph_and_tex_master 

    echo "[$(hostname)]Creating graph ...done (${current_count} / ${total_count})                       "
}

function create_time_graph_and_tex_master {
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local item_var

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
                                echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                                for item_var in "${item_to_create_graph[@]}" 
                                do
                                    create_time_graph_plt_master
                                    create_time_graph_gnuplot           #使い回し
                                    create_time_graph_tex               #使い回し
                                done
                                create_all_graph_tex

                                create_throughput_time_graph_plt_master
                                create_throughput_time_graph_gnuplot    #使い回し
                                create_throughput_time_tex              #使い回し

                                ((current_count++))
                            done
                        done
                    done
                done
            done
        done
    done
   
}

function create_cgnctrl_all_each_graph_and_tex_master {
   local cgn_ctrl_var  
   local extended_var
   local rtt1_var  
   local rtt2_var  
   local queue_var  
   local repeat_i 
   local item_var

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

                            echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                            create_all_graph_cgnctrl_tex 
                            ((current_count++))
                        done
                    done
                done
            done
        done
    done
}

function create_all_graph_cgnctrl_tex {
    local var
    local tex_name
   
    
    for var in "${item_to_create_graph[@]}" 
    do
        tex_name=tex/${var}_cgnctrl_${rootdir}.tex

        echo "\\" >> ${tex_name} 
        echo "\begin{center}${var} ext=${extended_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}th \end{center}" >> ${tex_name} 

        echo "\begin{multicols}{2}" >> ${tex_name}

        for cgn_ctrl_var in "${cgn_ctrl[@]}" 
        do
            create_all_each_cgnctrl_graph_tex $var
        done

        echo "\end{multicols}" >> ${tex_name}
        echo "\clearpage" >>${tex_name} 
    done
}

function create_throughput_time_graph_plt_master {
    local app_i
    local yrangemax
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local pltfile=${targetdir}/${repeat_i}th/throughput/plot.plt
    local sender_i
    
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

    
    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            echo -n "\"./sender${sender_i}_app${app_i}_time.dat\" using 1:2 with lines linewidth 2 title \"sender${sender_i}_APP${app_i}\"" >> ${pltfile}
            if [ $sender_i != $sender_num ] || [ $app_i != $app ]; then
               echo -n " , " >> ${pltfile}
            fi
        done
    done
}
function create_time_graph_gnuplot_master {
create_time_graph_gnuplot
}

function create_time_graph_plt_master {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local app_i
    local subflow_i
    local targetpos
    local scale=`echo "scale=1; $duration / 5.0" | bc`
    local spacing 
    local gnuplotversion
    local statecount
    local var

    gnuplotversion=$(gnuplot --version)
    gnuplotversion=$(echo ${gnuplotversion:8:1})
    #if [ ${gnuplotversion} -eq 5 ]; then
    #    spacing=1
    #else
    #    spacing=5
    #fi
    #spacing=$((${spacing} + ${#item_to_count_state[@]}))

    targetpos=$(awk -v item_var=${item_var} '{
        targetname2=item_var"*" 
        for(i=1;i<=NF;i++){
            if( match ($i, targetname2) == 1){
                print i+1;
		exit
            }
        }
	if(NR>100){
            exit
        }
    }' ./${targetdir}/log/sender1_cwnd1_subflow1.dat) # hard coding
    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,620
    set key outside
    set size ratio 0.5
    set xlabel "time[s]"
    set termoption noenhanced
    set datafile separator " " ' > ${targetdir}/${item_var}.plt
    #echo "set key spacing ${spacing}" >> ${targetdir}/${item_var}.plt
    echo "set ylabel \"${item_var}\"" >> ${targetdir}/${item_var}.plt
    echo "set xtics $scale" >> ${targetdir}/${item_var}.plt
    echo "set xrange [0:${duration}]" >> ${targetdir}/${item_var}.plt
    echo "set output \"${item_var}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png\"" >> ${targetdir}/${item_var}.plt

    echo -n "plot " >> ${targetdir}/${item_var}.plt
    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            for subflow_i in `seq ${subflownum}` 
            do
                echo -n "\"./log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}.dat\" using 1:${targetpos} with lines linewidth 2 title \"sender${sender_i}_APP${app_i}_subflow${subflow_i} " >> ${targetdir}/${item_var}.plt
                for var in "${item_to_count_state[@]}" 
                do
                    statecount=$(awk 'NR==1' ./${targetdir}/log/sender${sender_i}_cwnd${app_i}_subflow${subflow_i}_${var}.dat)
                    #echo -n "\n ${var}=${statecount} " >> ${targetdir}/${item_var}.plt
                done
                echo -n "\" " >> ${targetdir}/${item_var}.plt

                if [ $sender_i != $sender_num ] || [ $app_i != $app ] || [ $subflow_i != $subflownum ];then

                   echo -n " , " >> ${targetdir}/${item_var}.plt
                    
                fi
            done
        done
    done
}


function create_throughput_queue_graph_plt_master {
    local repeat_i 
    local app_i
    local queue_var
    local yrangemax
    local sender_i

    yrangemax=$(set_yrange_max)

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}
    
    for repeat_i in `seq ${repeat}` 
    do
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                if [ $app_i -eq 1 -a ${sender_i} -eq 1 ]; then
                    cp ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                else
                    join ./${targetdir}/${repeat_i}th/graphdata.dat ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat > ${targetdir}/${repeat_i}th/tmp.dat
                    mv ${targetdir}/${repeat_i}th/tmp.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                fi
            done
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
        set termoption noenhanced
        set datafile separator " " ' > ./${targetdir}/${repeat_i}th/plot.plt
        echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/${repeat_i}th/plot.plt 
        echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/${repeat_i}th/plot.plt
        echo "set output \"throughput_${targetdir}_${repeat_i}th.png\"" >> ./${targetdir}/${repeat_i}th/plot.plt

        echo -n "plot " >> ./${targetdir}/${repeat_i}th/plot.plt
        n=1
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                n=`expr $n + 1`
                echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/${repeat_i}th/plot.plt
                if [ $app_i != $app ];then
                    echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
                fi


            done
            if [ $sender_i != $sender_num ];then

                echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/${repeat_i}th/plot.plt
            fi
        done
    done 

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 -a $sender_i -eq 1 ]; then
                cp ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat ./${targetdir}/ave/graphdata.dat
            else
                join ./${targetdir}/ave/graphdata.dat ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat > ${targetdir}/ave/tmp.dat
                mv ${targetdir}/ave/tmp.dat ./${targetdir}/ave/graphdata.dat
            fi
        done
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
    set termoption noenhanced
    set datafile separator " " ' > ./${targetdir}/ave/plot.plt
    echo "set title \"throughput ${targetdir} ${repeat_i} times average \"" >> ./${targetdir}/ave/plot.plt 
    echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/ave/plot.plt
    echo "set output \"throughput_${targetdir}_ave.png\"" >> ./${targetdir}/ave/plot.plt

    echo -n "plot " >> ./${targetdir}/ave/plot.plt

    n=1
    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            #n=`echo "scale=1; ($sender_i - 1) * 2 + $app_i + 1 " | bc`
            n=`expr $n + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/ave/plot.plt
            if [ $app_i != $app ];then
                echo -n " , " >> ./${targetdir}/ave/plot.plt
            fi


        done
        if [ $sender_i != $sender_num ];then

            echo -n " , " >> ./${targetdir}/ave/plot.plt
        else
             n=`expr $n + 1`
             echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/ave/plot.plt
        fi
    done
}
function create_throughput_rtt_graph_plt_master {
    local repeat_i 
    local app_i
    local yrangemax
    local sender_i

    yrangemax=$(set_yrange_max)

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}
    
    for repeat_i in `seq ${repeat}` 
    do
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                if [ $app_i -eq 1 -a ${sender_i} -eq 1 ]; then
                    cp ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                else
                    join ./${targetdir}/${repeat_i}th/graphdata.dat ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat > ${targetdir}/${repeat_i}th/tmp.dat
                    mv ${targetdir}/${repeat_i}th/tmp.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                fi
            done
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
        set ylabel "throughput"
        set xlabel "rtt [ms]" 
        set key outside
        set size ratio 0.5
        set boxwidth 0.5 relative 
        set termoption noenhanced
        set datafile separator " " ' > ./${targetdir}/${repeat_i}th/plot.plt
        echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/${repeat_i}th/plot.plt 
        echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/${repeat_i}th/plot.plt
        echo "set output \"throughput_${targetdir}_${repeat_i}th.png\"" >> ./${targetdir}/${repeat_i}th/plot.plt

        echo -n "plot " >> ./${targetdir}/${repeat_i}th/plot.plt
        n=1
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                n=`expr $n + 1`
                echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/${repeat_i}th/plot.plt
                if [ $app_i != $app ];then
                    echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
                fi


            done
            if [ $sender_i != $sender_num ];then

                echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/${repeat_i}th/plot.plt
            fi
        done
    done 

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 -a $sender_i -eq 1 ]; then
                cp ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat ./${targetdir}/ave/graphdata.dat
            else
                join ./${targetdir}/ave/graphdata.dat ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat > ${targetdir}/ave/tmp.dat
                mv ${targetdir}/ave/tmp.dat ./${targetdir}/ave/graphdata.dat
            fi
        done
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
    set xlabel "rtt [ms]" 
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set termoption noenhanced
    set datafile separator " " ' > ./${targetdir}/ave/plot.plt
    echo "set title \"throughput ${targetdir} ${repeat_i} times average \"" >> ./${targetdir}/ave/plot.plt 
    echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/ave/plot.plt
    echo "set output \"throughput_${targetdir}_ave.png\"" >> ./${targetdir}/ave/plot.plt

    echo -n "plot " >> ./${targetdir}/ave/plot.plt

    n=1
    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            #n=`echo "scale=1; ($sender_i - 1) * 2 + $app_i + 1 " | bc`
            n=`expr $n + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/ave/plot.plt
            if [ $app_i != $app ];then
                echo -n " , " >> ./${targetdir}/ave/plot.plt
            fi


        done
        if [ $sender_i != $sender_num ];then

            echo -n " , " >> ./${targetdir}/ave/plot.plt
        else
             n=`expr $n + 1`
             echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/ave/plot.plt
        fi
    done
}
function create_throughput_ext_graph_plt_master {
    local repeat_i 
    local app_i
    local yrangemax
    local sender_i

    yrangemax=$(set_yrange_max)

    targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    
    for repeat_i in `seq ${repeat}` 
    do
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                if [ $app_i -eq 1 -a ${sender_i} -eq 1 ]; then
                    cp ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                else
                    join ./${targetdir}/${repeat_i}th/graphdata.dat ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat > ${targetdir}/${repeat_i}th/tmp.dat
                    mv ${targetdir}/${repeat_i}th/tmp.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                fi
            done
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
        set ylabel "throughput"
        set key outside
        set size ratio 0.5
        set boxwidth 0.5 relative 
        set termoption noenhanced
        set datafile separator " " ' > ./${targetdir}/${repeat_i}th/plot.plt
        echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/${repeat_i}th/plot.plt 
        echo "set xlabel \"${extended_parameter_name}\"" >> ./${targetdir}/plot.plt 
        echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/${repeat_i}th/plot.plt
        echo "set output \"throughput_${targetdir}_${repeat_i}th.png\"" >> ./${targetdir}/${repeat_i}th/plot.plt

        echo -n "plot " >> ./${targetdir}/${repeat_i}th/plot.plt
        n=1
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                n=`expr $n + 1`
                echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/${repeat_i}th/plot.plt
                if [ $app_i != $app ];then
                    echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
                fi


            done
            if [ $sender_i != $sender_num ];then

                echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/${repeat_i}th/plot.plt
            fi
        done
    done 

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 -a $sender_i -eq 1 ]; then
                cp ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat ./${targetdir}/ave/graphdata.dat
            else
                join ./${targetdir}/ave/graphdata.dat ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat > ${targetdir}/ave/tmp.dat
                mv ${targetdir}/ave/tmp.dat ./${targetdir}/ave/graphdata.dat
            fi
        done
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
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set termoption noenhanced
    set datafile separator " " ' > ./${targetdir}/ave/plot.plt
    echo "set title \"throughput ${targetdir} ${repeat_i} times average \"" >> ./${targetdir}/ave/plot.plt 
    echo "set xlabel \"${extended_parameter_name}\"" >> ./${targetdir}/plot.plt 
    echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/ave/plot.plt
    echo "set output \"throughput_${targetdir}_ave.png\"" >> ./${targetdir}/ave/plot.plt

    echo -n "plot " >> ./${targetdir}/ave/plot.plt

    n=1
    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            #n=`echo "scale=1; ($sender_i - 1) * 2 + $app_i + 1 " | bc`
            n=`expr $n + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/ave/plot.plt
            if [ $app_i != $app ];then
                echo -n " , " >> ./${targetdir}/ave/plot.plt
            fi


        done
        if [ $sender_i != $sender_num ];then

            echo -n " , " >> ./${targetdir}/ave/plot.plt
        else
             n=`expr $n + 1`
             echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/ave/plot.plt
        fi
    done
}
function create_throughput_cgnctrl_graph_plt_master {
    local repeat_i 
    local app_i
    local yrangemax
    local sender_i

    yrangemax=$(set_yrange_max)

    targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    
    for repeat_i in `seq ${repeat}` 
    do
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                if [ $app_i -eq 1 -a ${sender_i} -eq 1 ]; then
                    cp ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                else
                    join ./${targetdir}/${repeat_i}th/graphdata.dat ./${targetdir}/${repeat_i}th/sender${sender_i}_app${app_i}.dat > ${targetdir}/${repeat_i}th/tmp.dat
                    mv ${targetdir}/${repeat_i}th/tmp.dat ./${targetdir}/${repeat_i}th/graphdata.dat
                fi
            done
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
        set xlabel "Congestion Control"
        set ylabel "throughput"
        set key outside
        set size ratio 0.5
        set boxwidth 0.5 relative 
        set termoption noenhanced
        set datafile separator " " ' > ./${targetdir}/${repeat_i}th/plot.plt
        echo "set title \"throughput ${targetdir} ${repeat_i}th\"" >> ./${targetdir}/${repeat_i}th/plot.plt 
        echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/${repeat_i}th/plot.plt
        echo "set output \"throughput_${targetdir}_${repeat_i}th.png\"" >> ./${targetdir}/${repeat_i}th/plot.plt

        echo -n "plot " >> ./${targetdir}/${repeat_i}th/plot.plt
        n=1
        for sender_i in `seq ${sender_num}` 
        do
            for app_i in `seq ${app}` 
            do
                n=`expr $n + 1`
                echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/${repeat_i}th/plot.plt
                if [ $app_i != $app ];then
                    echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
                fi


            done
            if [ $sender_i != $sender_num ];then

                echo -n " , " >> ./${targetdir}/${repeat_i}th/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/${repeat_i}th/plot.plt
            fi
        done
    done 

    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            if [ $app_i -eq 1 -a $sender_i -eq 1 ]; then
                cp ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat ./${targetdir}/ave/graphdata.dat
            else
                join ./${targetdir}/ave/graphdata.dat ./${targetdir}/ave/sender${sender_i}_app${app_i}.dat > ${targetdir}/ave/tmp.dat
                mv ${targetdir}/ave/tmp.dat ./${targetdir}/ave/graphdata.dat
            fi
        done
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
    set xlabel "Congestion Control"
    set ylabel "throughput"
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set termoption noenhanced
    set datafile separator " " ' > ./${targetdir}/ave/plot.plt
    echo "set title \"throughput ${targetdir} ${repeat_i} times average \"" >> ./${targetdir}/ave/plot.plt 
    echo "set yrange [0:${yrangemax}]" >> ./${targetdir}/ave/plot.plt
    echo "set output \"throughput_${targetdir}_ave.png\"" >> ./${targetdir}/ave/plot.plt

    echo -n "plot " >> ./${targetdir}/ave/plot.plt

    n=1
    for sender_i in `seq ${sender_num}` 
    do
        for app_i in `seq ${app}` 
        do
            #n=`echo "scale=1; ($sender_i - 1) * 2 + $app_i + 1 " | bc`
            n=`expr $n + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"Sender${sender_i}_APP${app_i}\" " >> ./${targetdir}/ave/plot.plt
            if [ $app_i != $app ];then
                echo -n " , " >> ./${targetdir}/ave/plot.plt
            fi


        done
        if [ $sender_i != $sender_num ];then

            echo -n " , " >> ./${targetdir}/ave/plot.plt
        else
             n=`expr $n + 1`
             echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${targetdir}/ave/plot.plt
        fi
    done
}


function create_queue_graph_and_tex_master {
    local cgn_ctrl_var
    local extended_var
    local loss_var
    local rtt1_var
    local rtt2_var
    local targetdir
    local img_file

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
                        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}

                        echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                        
                        create_throughput_queue_graph_plt_master
                        create_throguhput_queue_graph_gnuplot
                        create_throughput_queue_graph_tex
                        
                        ((current_count++))
                    done
                done
            done
        done
    done

}
function create_rtt_graph_and_tex_master {
    local cgn_ctrl_var
    local extended_var
    local loss_var
    local rtt1_var
    local rtt2_var
    local targetdir
    local img_file

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for extended_var in "${extended_parameter[@]}" 
        do
            for loss_var in "${loss[@]}"
            do
                for queue_var in "${queue[@]}"
                do
                    targetdir=${cgn_ctrl_var}_ext=${extended_var}_loss=${loss_var}_queue=${queue_var}
                    echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                    
                    create_throughput_rtt_graph_plt_master
                    create_throughput_rtt_graph_gnuplot
                    create_throughput_rtt_graph_tex
                    ((current_count++))
                done
            done
        done
    done


}
function create_ext_graph_and_tex_master {
    local cgn_ctrl_var
    local extended_var
    local loss_var
    local rtt1_var
    local rtt2_var
    local targetdir
    local img_file

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
                        targetdir=${cgn_ctrl_var}_ext=rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                        echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                        
                        create_throughput_ext_graph_plt_master
                        create_throughput_ext_graph_gnuplot
                        create_throughput_ext_graph_tex
                        ((current_count++))
                    done
                done
            done
        done
    done


}
function create_cgnctrl_graph_and_tex_master {
    local cgn_ctrl_var
    local extended_var
    local loss_var
    local rtt1_var
    local rtt2_var
    local targetdir
    local img_file

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
                        targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                        echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                        
                        create_throughput_cgnctrl_graph_plt_master
                        create_throughput_cgnctrl_graph_gnuplot
                        create_throughput_cgnctrl_graph_tex
                        ((current_count++))
                    done
                done
            done
        done
    done


}

function send_command {
    local send_command=$1
    local bg_option
    local sender_i
    local target_ip

    if [ $# -eq 2 ]; then
        bg_option=1
    else
        bg_option=0
    fi

    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        if [ ${bg_option} -eq 1 ];then
            ssh root@${!target_ip} "${senderdir}/slave.sh ${send_command}" &
        else
            ssh root@${!target_ip} "${senderdir}/slave.sh ${send_command}"
        fi
    done
    if [ ${bg_option} -eq 1 ];then
        wait
    fi
}

function write_and_send_now_parameter {
    local sender_i
    local target_ip

    echo "cgn_ctrl_var=${cgn_ctrl_var}">now_parameter.txt
    echo "extended_var=${extended_var}">>now_parameter.txt
    echo "rtt1_var=${rtt1_var}">>now_parameter.txt
    echo "rtt2_var=${rtt2_var}">>now_parameter.txt
    echo "loss_var=${loss_var}">>now_parameter.txt
    echo "queue_var=${queue_var}">>now_parameter.txt
    echo "repeat_i=${repeat_i}">>now_parameter.txt
    


    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        scp ./now_parameter.txt root@${!target_ip}:/${senderdir}/now_parameter.txt > /dev/null &
    done

    wait

}

function sender_set_netem_rtt_and_loss {
    local sender_i
    local target_ip

    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        ssh root@${!target_ip} "${senderdir}/slave.sh "set_netem_rtt_and_loss ${rtt1_var} ${rtt2_var} ${loss_var} ${queue_var}""
    done

    wait
}

function get_sender_and_ne_status_and_scp {
    local sender_i
    local target_ip
    local kernel_name
    local ne_qdisc
    local sender_qdisc

    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        kernel_name=$(ssh root@${!target_ip} "uname -a") 
        echo "sender${sender_i} ${kernel_name}" >> ./${rootdir}/sender_and_ne_status.txt
    done
    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        sender_qdisc=$(ssh root@${!target_ip} "tc qdisc show") 
        echo "---sender${sender_i}---" >> ./${rootdir}/sender_and_ne_status.txt
        echo "${sender_qdisc}" >> ./${rootdir}/sender_and_ne_status.txt
    done
    ne_qdisc=$(ssh root@${sender1_ip} "ssh root@${ne1_ne3_ip} "tc qdisc show"") 
    echo "---ne1---" >> ./${rootdir}/sender_and_ne_status.txt
    echo "${ne_qdisc}" >> ./${rootdir}/sender_and_ne_status.txt
    ne_qdisc=$(ssh root@${sender1_ip} "ssh root@${ne2_ne3_ip} "tc qdisc show"") 
    echo "---ne2---" >> ./${rootdir}/sender_and_ne_status.txt
    echo "${ne_qdisc}" >> ./${rootdir}/sender_and_ne_status.txt
    ne_qdisc=$(ssh root@${sender1_ip} "ssh root@${ne3_ne1_ip} "tc qdisc show"") 
    echo "---ne3---" >> ./${rootdir}/sender_and_ne_status.txt
    echo "${ne_qdisc}" >> ./${rootdir}/sender_and_ne_status.txt

    for sender_i in `seq ${sender_num}` 
    do
        target_ip="sender${sender_i}_ip"
        scp ${rootdir}/sender_and_ne_status.txt root@${!target_ip}:${senderdir}/${rootdir} >/dev/null &
    done

    wait

}

function init_sender {
    local sender_i

    echo -n "[$(hostname)]transmitting shell file..."
    for sender_i in `seq ${sender_num}` 
    do
        
        target_ip="sender${sender_i}_ip"
        scp ./slave.sh root@${!target_ip}:${senderdir}>/dev/null & 
        scp ./function.sh root@${!target_ip}:${senderdir} >/dev/null& 
        scp ./${configfile} root@${!target_ip}:${senderdir}/default.conf >/dev/null &

    done
    wait

    for sender_i in `seq ${sender_num}` 
    do
        
        target_ip="sender${sender_i}_ip"
        ssh root@${!target_ip} "echo "rootdir=${rootdir}">${senderdir}/rootdir.txt && echo "today=${today}">>${senderdir}/rootdir.txt && echo "memo=${memo}">>${senderdir}/rootdir.txt" 
        mes="source ${senderdir}/default.conf && echo \"rcvkernel=\$(ssh root@\${receiver_ip} 'uname -r')\">>${senderdir}/rootdir.txt " 
        ssh root@${!target_ip} "$mes" 

    done
    wait
    echo  "done"
}

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
    echo -en "\033[0;31m"
    echo "^^^ Invalid argument of sysctl parameter. are you ok? ^^^"
    echo -en "\033[0;39m"
}

function get_mptcp_version_master {
    local kernel=$(grep -m 1 "mptcp" ./${rootdir}/sender_and_ne_status.txt | awk '{print $4}')

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
    local ne1_ip="ne1_$(hostname)_ip"
    local ne2_ip="ne2_$(hostname)_ip"
   echo -n "checking network is available ..."
   ping $receiver_ip -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "ng"
        echo "error: can't access to receiver [$receiver_ip]"
        exit
   fi
   ping ${!ne1_ip} -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "ng"
        echo "error: can't access to ne1 [${!ne1_ip}]"
        exit
   fi
    ping ${!ne2_ip} -c 1 >> /dev/null
   if [ $? -ne 0 ]; then
        echo "ng"
        echo "error: can't access to ne2 [${!ne2_ip}]"
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
    local sender_i

    echo -ne "[$(hostname)] making directory ...\r"
    mkdir ${rootdir}
    mkdir ${rootdir}/tex
    mkdir ${rootdir}/tex/img

    for sender_i in `seq ${sender_num}` 
    do
        mkdir ${rootdir}/sender${sender_i}
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
                        targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                        mkdir ${rootdir}/${targetdir}/
                        for repeat_i in `seq ${repeat}` 
                        do
                            mkdir ${rootdir}/${targetdir}/${repeat_i}th
                        done
                        mkdir ${rootdir}/${targetdir}/ave
                    done
                done
            done
        done
    done


    echo "[$(hostname)]making directory...done"
}

function echo_finish_time {
    local process_time
    local timestamp
    local time
    local total_time
    local total_count
    local process_time
    local copy_log_time
    
    if [ ${mptcp_ver} == "sptcp" ]; then
        process_time=70 # sptcp 一回の実験に必要なデータ処理時間 [s]  
        copy_log_time=28 # （仮）
    elif [ ${sender_num} == 1 ]; then
        process_time=212 # mptcp 一回の実験に必要なデータ処理時間 [s] (1sender 3app)
        copy_log_time=28
    else
        process_time=83 # mptcp 一回の実験に必要なデータ処理時間 [s] (3sender 1app)
        copy_log_time=16
    fi

    time=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * (${duration}+${process_time}+${copy_log_time}) * $repeat " | bc`
    ((sec=time%60, min=(time%3600)/60, hrs=time/3600))
    timestamp=$(printf "%d時間%02d分%02d秒" $hrs $min $sec)
    echo "予想終了時刻 `date --date "$time seconds"` ${timestamp} "

    total_time=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * ($duration) * $repeat " | bc`
    total_count=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    total_process_time=`echo "scale=5; ${total_count} * ${process_time} " | bc`
    ((sec=total_time%60, min=(total_time%3600)/60, hrs=total_time/3600))
    total_timestamp=$(printf "%d時間%02d分%02d秒" $hrs $min $sec)
    ((sec=total_process_time%60, min=(total_process_time%3600)/60, hrs=total_process_time/3600))
    process_timestamp=$(printf "%d時間%02d分%02d秒" $hrs $min $sec)
    echo "実験回数=${total_count} 送受信時間=${total_timestamp} データ処理時間=${process_timestamp}"
}

function echo_data_byte {
    local compressed_byte
    local normal_byte
    local compressed_one_data
    local normal_one_data
    local result
    local hdd_limit=300 # アラートを表示するデータ量 [GB]

    if [ ${mptcp_ver} == "sptcp" ]; then
        compressed_one_data=0.0188 # sptcp 一回の実験に必要なデータ量 [GB]  
        normal_one_data=0
    elif [ $sender_num == 1 ]; then
        compressed_one_data=0.0463 # mptcp 一回の実験に必要なデータ量 [GB] (1sender app3)
        normal_one_data=2
    else
        compressed_one_data=0.0075 # mptcp 一回の実験に必要なデータ量 [GB] (3sender app1)
        normal_one_data=0.2367
    fi

    compressed_byte=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} *${compressed_one_data} * $repeat " | bc`
    normal_byte=`echo "scale=5; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} *${normal_one_data} * $repeat " | bc`
    result=`echo "scale=5; ${compressed_byte} < 1 " | bc`
    if [ ${result} = "1" ]; then
        
        compressed_byte=`echo "scale=2; ${compressed_byte} * 1000 " | bc`
        echo "予想データ量 ${compressed_byte} MB"
        result=`echo "scale=5; ${normal_byte} < 1 " | bc`
        if [ ${result} = "1" ]; then
            normal_byte=`echo "scale=2; ${normal_byte} * 1000 " | bc`
            echo "最大必要容量 ${normal_byte} MB"
        else
            echo "最大必要容量 ${normal_byte} GB"
        fi
    else
        echo "予想データ量 ${compressed_byte} GB"
        echo "最大必要容量 ${normal_byte} GB"
    fi

    if [ `echo "$normal_byte > $hdd_limit" | bc` == 1 ]; then
        echo -e "\033[0;31m"
        echo "########################################################################"
        echo "#######                                                          #######"
        echo "####### 注意!!!!! 圧縮前のデータ量が${hdd_limit}GBを超えています         #######"
        echo "#######                                                          #######"
        echo "########################################################################"
        echo -e "\033[0;39m"
    fi

}
    
function set_netem_rtt_and_loss {

    local delay_harf1=`echo "scale=3; $rtt1_var / 2 " | bc`
    local delay_harf2=`echo "scale=3; $rtt2_var / 2 " | bc`
    local ne1_ip="ne1_$(hostname)_ip"
    local ne2_ip="ne2_$(hostname)_ip"
    local ne1_eth="ne1_$(hostname)_eth"
    local ne2_eth="ne2_$(hostname)_eth"
    local netem_queue

    if [ $queue_is_netem_queue == 1 ]; then
        netem_queue=$queue_var
    else
        netem_queue=1000
    fi

	if [ $loss_var == 0 ]; then
        ssh -n root@${!ne1_ip} "tc qdisc replace dev ${!ne1_eth} root netem limit ${netem_queue} delay ${delay_harf1}ms &&
                             tc qdisc replace dev ${ne1_ne3_eth} root netem limit ${netem_queue} delay ${delay_harf1}ms" 
        ssh -n root@${!ne2_ip} "tc qdisc replace dev ${!ne2_eth} root netem limit ${netem_queue} delay ${delay_harf2}ms &&
                             tc qdisc replace dev ${ne2_ne3_eth} root netem limit ${netem_queue} delay ${delay_harf2}ms"
	else
        ssh -n root@${!ne1_ip} "tc qdisc replace dev ${!ne1_eth} root netem limit ${netem_queue} delay ${delay_harf1}ms &&
                             tc qdisc replace dev ${ne1_ne3_eth} root netem limit ${netem_queue} delay ${delay_harf1}ms loss ${loss_var}%" 
        ssh -n root@${!ne2_ip} "tc qdisc replace dev ${!ne2_eth} root netem limit ${netem_queue} delay ${delay_harf2}ms &&
                             tc qdisc replace dev ${ne2_ne3_eth} root netem limit ${netem_queue} delay ${delay_harf2}ms loss ${loss_var}%"
	fi
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

    author=$username
}

function clean_log_sender_and_receiver {
    #ssh root@${receiver_ip} "echo > /var/log/kern.log" > /dev/null
    echo > /var/log/kern.log
	find /var/log/ -type f -name \* -exec cp -f /dev/null {} \;
}

function set_txqueuelen {
    local txqueue
    if [ $queue_is_netem_queue == 1 ]; then
        txqueue=1000
    else
        txqueue=$queue_var
    fi

    ip link set dev ${eth0} txqueuelen ${txqueue}
    ip link set dev ${eth1} txqueuelen ${txqueue}
}

function set_qdisc {
    echo -n "[$(hostname)] setting qdisc to (${qdisc})..."
    tc qdisc replace dev ${eth0} root ${qdisc}
    tc qdisc replace dev ${eth1} root ${qdisc}
    echo "done"

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

function run_iperf_multi_sender {
    local base_duration

    local sender_i
    local send_command="run_iperf"
    local time_i
    local sec
    local min
    local hrs
    local timestamp


    for sender_i in `seq ${sender_num}` 
    do
        base_duration=`echo "scale=5; $duration + ($sender_num - $sender_i) * $sender_delay " | bc`
		if [ $sender_i = $sender_num ]; then  # When final app launch
            target_ip="sender${sender_i}_ip"
            ssh root@${!target_ip} "${senderdir}/slave.sh ${send_command} ${base_duration}" &
		else
            target_ip="sender${sender_i}_ip"
            ssh root@${!target_ip} "${senderdir}/slave.sh ${send_command} ${base_duration}" &
			sleep $sender_delay
		fi
    done
    # sender_delayが極端になると、最後のsenderの残り実験時間を表示する
    # 例 sender_delayが10秒でsender数が2なら、最初の10秒は残り時間が表示されず、最後の10秒のみ表示される
    for time_i in `seq ${duration}` 
    do
        total_time_i=`echo "scale=1; ${total_time_i} - 1 " | bc`
        ((sec=total_time_i%60, min=(total_time_i%3600)/60, hrs=total_time_i/3600))
        timestamp=$(printf "%d時間%02d分%02d秒" $hrs $min $sec)
        echo -ne "${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目 ...(${time_i}s / ${duration}s) ($timestamp) \r"
        sleep 1
    done

    wait
    echo "${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目 ...done (${time_i}s / ${duration}s)                  "

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

    }else if(match ($7, target)==1){
        printf("%s ",$1)
        for(i=3;i<=NF;i++){
            printf("%s ",$i)
        }
    
    }else if(match ($8, target)==1){
		printf("%s ",$1)
        for(i=4;i<=NF;i++){
            printf("%s ",$i)
        }
    }else if(match ($6, target)==1){
		printf("%s",$0)
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
        if($2 ~ "meta="){
            array[$3]++   
        }
    }END{
        for(i in array){
            printf("%s %d\n",i,array[i])
        }    
    }' ./${targetdir}/log/cwnd.dat > ./${targetdir}/log/app.dat

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

        sort -k2nr ./${targetdir}/log/app${app_i}_subflow.dat | head -n 2 | sort -k1n > ./${targetdir}/log/app${app_i}_subflow_sort.dat
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

    rm -f ./${targetdir}/log/cwnd.dat
    for app_i in `seq ${app}` 
    do
        rm -f ./${targetdir}/log/cwnd${app_i}.dat
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

function create_time_graph_plt {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local app_i
    local subflow_i
    local targetpos
    local scale=`echo "scale=1; $duration / 5.0" | bc`
    local spacing 
    local gnuplotversion
    local statecount
    local var

    gnuplotversion=$(gnuplot --version)
    gnuplotversion=$(echo ${gnuplotversion:8:1})
    #if [ ${gnuplotversion} -eq 5 ]; then
    #    spacing=1
    #else
    #    spacing=5
    #fi
    #spacing=$((${spacing} + ${#item_to_count_state[@]}))

    targetpos=$(awk -v item_var=${item_var} '{
        targetname2=item_var"*" 
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
    set datafile separator " " ' > ${targetdir}/${item_var}.plt
    #echo "set key spacing ${spacing}" >> ${targetdir}/${item_var}.plt
    echo "set ylabel \"${item_var}\"" >> ${targetdir}/${item_var}.plt
    echo "set xtics $scale" >> ${targetdir}/${item_var}.plt
    echo "set xrange [0:${duration}]" >> ${targetdir}/${item_var}.plt
    echo "set output \"${item_var}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png\"" >> ${targetdir}/${item_var}.plt

    echo -n "plot " >> ${targetdir}/${item_var}.plt

    for app_i in `seq ${app}` 
    do
        for subflow_i in `seq ${subflownum}` 
        do
            echo -n "\"./log/cwnd${app_i}_subflow${subflow_i}.dat\" using 1:${targetpos} with lines linewidth 2 title \"APP${app_i} : subflow${subflow_i} " >> ${targetdir}/${item_var}.plt
            for var in "${item_to_count_state[@]}" 
            do
                statecount=$(awk 'NR==1' ./${targetdir}/log/cwnd${app_i}_subflow${subflow_i}_${var}.dat)
                #echo -n "\n ${var}=${statecount} " >> ${targetdir}/${item_var}.plt
            done
            echo -n "\" " >> ${targetdir}/${item_var}.plt
            if [ $app_i != $app ] || [ $subflow_i != $subflownum ];then

               echo -n " , " >> ${targetdir}/${item_var}.plt
                
            fi
        done
    done
}

function create_time_graph_and_tex {
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local item_var

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
                                echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                                for item_var in "${item_to_create_graph[@]}" 
                                do
                                    create_time_graph_plt
                                    create_time_graph_gnuplot
                                    create_time_graph_tex
                                done
                                create_all_graph_tex

                                create_throughput_time_graph_plt
                                create_throughput_time_graph_gnuplot
                                create_throughput_time_tex

                                ((current_count++))
                            done
                        done
                    done
                done
            done
        done
    done
}

function create_time_graph_gnuplot {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    local img_file

    cd ${targetdir}
    gnuplot ${item_var}.plt 2>/dev/null
    img_file=${item_var}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png 
    ln -s  ../../${targetdir}/${img_file} ../../tex/img/

    cd ../../

}



function create_time_graph_tex {
    local tex_name=tex/${cgn_ctrl_var}_${item_var}_${rootdir}.tex
    local img_name=${item_var}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png
    
    echo "\begin{figure}[htbp]" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=95mm,trim=0 50 0 50,clip]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{${item_var} ${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var}\% RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_name} 
    echo '\end{center}
    \end{figure}' >>${tex_name} 
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


function create_throughput_time_graph_gnuplot {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local img_file

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

function process_throughput_data_queue {
    local targetdir
    local throguhput

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    throughput=$(cat ${targetdir}/throughput/app${app_i}_.dat)

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}/${repeat_i}th
    echo "${queue_var} ${throughput}" >> ./${targetdir}/app${app_i}.dat

}

function process_throughput_data_cgnctrl {
    local targetdir
    local throguhput

    targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    throughput=$(cat ${targetdir}/throughput/app${app_i}_.dat)

    targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th
    echo "${cgn_ctrl_var} ${throughput}" >> ./${targetdir}/app${app_i}.dat

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

        process_throughput_data_queue

        process_throughput_data_cgnctrl

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
        echo "${rtt1_var},${rtt2_var} ${throughput}" >> ./${targetdir}/ave/app${app_i}.dat
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

function process_throughput_data_cgnctrl_ave {
    local targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local throguhput

    for app_i in `seq ${app}` 
    do
        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
        throughput=$(cat ${targetdir}/ave/throughput/app${app_i}_ave.dat)
        targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
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
        echo "${extended_var} ${throughput}" >> ./${targetdir}/ave/app${app_i}.dat
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
    process_throughput_data_cgnctrl_ave
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

function create_throguhput_queue_graph_gnuplot {
    local repeat_i

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

function create_throughput_cgnctrl_graph_gnuplot {
    local repeat_i

    for repeat_i in `seq ${repeat}` 
    do
        cd ${targetdir}/${repeat_i}th
        gnuplot plot.plt 2>/dev/null
        img_file=throughput_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png
        ln -s  ../../${targetdir}/${repeat_i}th/${img_file} ../../tex/img/
        cd ../..
    done

    cd ${targetdir}/ave
    gnuplot plot.plt 2>/dev/null
    img_file=throughput_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_ave.png
    ln -s  ../../${targetdir}/ave/${img_file} ../../tex/img/

    cd ../..
}

function create_cgnctrl_graph_and_tex {
    local cgn_ctrl_var
    local extended_var
    local loss_var
    local rtt1_var
    local rtt2_var
    local targetdir
    local img_file

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
                        targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
                        echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                        
                        create_throughput_cgnctrl_graph_plt
                        create_throughput_cgnctrl_graph_gnuplot
                        create_throughput_cgnctrl_graph_tex
                        ((current_count++))
                    done
                done
            done
        done
    done


}

function create_throughput_cgnctrl_graph_plt {
    local repeat_i 
    local app_i
    local yrangemax

    yrangemax=$(set_yrange_max)

    targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    
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
        set xlabel "Congestion Control"
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
    set xlabel "Congestion Control"
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


function create_queue_graph_and_tex {
    local targetdir
    local img_file

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
                        targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}

                        echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                        
                        create_throughput_queue_graph_plt
                        create_throguhput_queue_graph_gnuplot
                        create_throughput_queue_graph_tex
                        
                        ((current_count++))
                    done
                done
            done
        done
    done
    
}

function create_throughput_queue_graph_tex {
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

function create_throughput_cgnctrl_graph_tex {
    local targetdir=ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
    local repeat_i
    local tex_file_name=throughput_cgnctrl_${rootdir}
    
    cd tex


    for repeat_i in `seq ${repeat}` 
    do
        echo "\begin{figure}[htbp]" >> ${tex_file_name}.tex
        echo "\begin{center}" >> ${tex_file_name}.tex
        echo '\includegraphics[width=95mm]' >> ${tex_file_name}.tex
        echo "{img/throughput_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png}" >> ${tex_file_name}.tex
        echo "\caption{ext=${extended_var} LOSS=${loss_var}\% RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回目}" >> ${tex_file_name}.tex
        echo '\end{center}
        \end{figure}' >> ${tex_file_name}.tex
    done

#---------------------ave-------------------------

    echo "\begin{figure}[htbp]" >> ${tex_file_name}_ave.tex
    echo "\begin{center}" >> ${tex_file_name}_ave.tex
    echo '\includegraphics[width=95mm]' >> ${tex_file_name}_ave.tex
    echo "{img/throughput_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_ave.png}" >> ${tex_file_name}_ave.tex
    echo "\caption{ext=${extended_var} LOSS=${loss_var}\% RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}回平均}" >> ${tex_file_name}_ave.tex
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

function create_all_each_cgnctrl_graph_tex {
    local targetname=$1
    local img_name=${targetname}_${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}_${repeat_i}th.png

    echo "\begin{figurehere}" >> ${tex_name}
    echo "\begin{center}" >> ${tex_name}
    echo '\includegraphics[width=90mm]' >> ${tex_name}
    echo "{img/${img_name}}" >> ${tex_name} 
    echo "\caption{${cgn_ctrl_var}}" >> ${tex_name} 
    echo "\end{center}" >>${tex_name}
    echo "\end{figurehere}" >>${tex_name} 

}

function insert_table_parameter {
    local targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/
    local targetname
    local hostname
    echo "\begin{table}[htb]">>${tex_name}
    echo "\scalebox{0.66}{">>${tex_name}
    
    for sender_i in `seq ${sender_num}` 
    do
        if [ $(hostname) != "master" ]; then
            if [ $sender_num == "1" ]; then
                hostname=$(hostname)
                sender_i=${hostname:6:1}
            fi
            if [ $(hostname) != "sender${sender_i}" ]; then
                continue
            fi
        fi

        if [ ${sender_i} -eq "4" ]; then
            echo "}\par\scalebox{0.66}{">>${tex_name}
        fi

        echo -n "\begin{tabular}{c">>${tex_name}

        for var in "${item_to_count_state[@]}" 
        do
            echo -n "c">>${tex_name}
        done
        echo "} \hline">>${tex_name}
     
        echo -n "name " >>${tex_name}
        for var in "${item_to_count_state[@]}" 
        do
            echo -n "& $var ">>${tex_name}
        done
        echo "\\\\ \hline \hline">>${tex_name}
        for app_i in `seq ${app}` 
        do
            for subflow_i in `seq ${subflownum}`
            do
                if [ $(hostname) != "master" ]; then
                        echo -n "sender${sender_i}\_app${app_i}\_subflow${subflow_i} ">>${tex_name}
                else
                    echo -n "sender${sender_i}\_app${app_i}\_subflow${subflow_i} ">>${tex_name}
                fi
                for var in "${item_to_count_state[@]}" 
                do
                    if [ $(hostname) == "master" ]; then
                        targetname="sender${sender_i}_cwnd${app_i}_subflow${subflow_i}_${var}.dat"
                    else
                        targetname="cwnd${app_i}_subflow${subflow_i}_${var}.dat"
                    fi
                    statecount=$(awk 'NR==1' ./${targetdir}/log/${targetname})
                    echo -n "& ${statecount} ">>${tex_name}
                done
                echo " \\\\ \hline">>${tex_name}
            done
        done
        echo "\end{tabular}">>${tex_name}
    done
    echo "}" >>${tex_name}
    echo "\end{table}" >>${tex_name}

}

function create_all_graph_tex {
    local tex_name=tex/${cgn_ctrl_var}_alldata_${rootdir}.tex
    
    echo "\\" >> ${tex_name} 
    echo "\begin{center}${cgn_ctrl_var} ext=${extended_var} LOSS=${loss_var} RTT1=${rtt1_var}ms RTT2=${rtt2_var}ms queue=${queue_var}pkt ${repeat_i}th \end{center}" >> ${tex_name} 
    insert_table_parameter
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
    set xlabel "RTT [ms]"
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


function create_rtt_graph_and_tex {
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
                    echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"

                    create_throughput_rtt_graph_plt
                    create_throughput_rtt_graph_gnuplot        
                    create_throughput_rtt_graph_tex
                    ((current_count++))
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

function process_srtt_ext_boxplot_data {
    local app_i
    local subflow_i
    local targetdir
    local pltdir

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


}

function create_srtt_ext_graph_plt {
    local targetdir
    local pltdir
    local yrangemax
    local repeat_i


    for repeat_i in `seq ${repeat}` 
    do
        targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/srtt
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


function create_ext_graph_and_tex {
    local cgn_ctrl_var
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
                        echo -ne "[$(hostname)]Creating graph ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"

                        create_throughput_ext_graph_plt
                        create_throughput_ext_graph_gnuplot
                        create_throughput_ext_graph_tex

                        create_srtt_ext_graph_plt
                        create_srtt_ext_graph_gnuplot
                        create_srtt_ext_graph_tex
                        ((current_count++))
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

function calc_progress_percent {
    local percent
    percent=`echo "scale=3; $current_count / $total_count * 100 " | bc`
    percent=`echo "scale=1; $percent / 1 " | bc`
    echo $percent
}

function calc_remaining_time {
    local r_count=`echo "scale=1; $total_count - $current_count " | bc`
    local end_time

    if [ $current_count -eq 0 ]; then
        start_time=$(date +%s)
        r_time="..."
    elif [ $current_count -eq 1 ]; then
        end_time=$(date +%s) 
        one_time=`echo "scale=1; $end_time - $start_time " | bc`
        r_time=`echo "scale=1; $one_time * $r_count " | bc`
    else
        r_time=`echo "scale=1; $one_time * $r_count " | bc`
    fi
    
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
    local current_count=0
    local total_count=`echo "scale=1; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    local start_time
    local one_time
    local r_time

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
                                calc_remaining_time
                                echo -ne "[$(hostname)] Processing data ...$(calc_progress_percent)% (${current_count} / ${total_count}) 残り${r_time}s     \r"
                                #echo_slave "Processing data ..." "$(calc_progress_percent)% (${current_count} / ${total_count}) 残り${r_time}s"
                                separate_cwnd
                                get_app_meta
                                extract_cwnd_each_flow

                                count_mptcp_state
                                process_throughput_data
                                process_srtt_ext_boxplot_data
                                (( current_count++))
                            done
                            process_throughput_data_ave
                        done    
                    done
                done
            done
        done
    done
    echo "[$(hostname)]Processing data ...done (${current_count} / ${total_count})                       "
}

function create_graph_and_tex {
    local total_count
    local current_count=0

    total_count=`echo "scale=1; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    total_count=`echo "scale=1; ${total_count} + ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} " | bc`
    total_count=`echo "scale=1; ${total_count} + ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]}  " | bc`
    total_count=`echo "scale=1; ${total_count} + ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * ${#loss[@]} * ${#queue[@]}" | bc`

    create_time_graph_and_tex
    create_ext_graph_and_tex
    create_queue_graph_and_tex
    create_cgnctrl_graph_and_tex
    create_rtt_graph_and_tex

    echo "[$(hostname)]Creating graph ...done (${current_count} / ${total_count})                       "
}

function delete_and_compress_processed_log_data {
    local targetdir
    local cgn_ctrl_var  
    local extended_var
    local rtt1_var  
    local rtt2_var  
    local queue_var  
    local repeat_i 
    local total_count
    local current_count=0
    
    total_count=`echo "scale=1; ${#extended_parameter[@]} * ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
    total_count=`echo "scale=1; ${total_count} + ${#cgn_ctrl[@]} * $(calc_combination_number_of_rtt) * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`

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
                                echo -ne "[$(hostname)] Delete and compress data ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                                targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/log
                                cd ${targetdir}
                                tar cvzf kern.dat.tar.gz kern.dat > /dev/null 2>&1

                                rm -f *.dat 
                                cd ../../../
                                ((current_count++))
                            done
                        done    
                    done
                done
            done
        done
    done

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
                        for repeat_i in `seq ${repeat}` 
                        do
                            echo -ne "Delete and compress data ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                            targetdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/srtt
                            cd ${targetdir}
                            echo "容量削減のため削除されました。復元する場合はtool.shを使ってください。" >srtt_boxplot.dat
                            echo "These were deleted for reducing data size." >>srtt_boxplot.dat
                            echo "Please use tool.sh for recover boxplot data." >>srtt_boxplot.dat
                            cd ../../../
                            ((current_count++))

                        done
                    done
                done
            done
        done
    done
    echo "[$(hostname)]Delete and compress data ...done (${current_count} / ${total_count})                       "
}

function platex_dvipdfmx_link {
    local tex_file_name=$1

    echo -ne "[$(hostname)] Build tex file ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
    platex -halt-on-error -interaction=nonstopmode ${tex_file_name}.tex > /dev/null 2>&1
    dvipdfmx ${tex_file_name}.dvi > /dev/null 2>&1
    if [ -e ./${tex_file_name}.pdf ]; then
        ln -sf tex/${tex_file_name}.pdf ../
    fi
    ((current_count++))
}


function build_tex_to_pdf {
    local cgn_ctrl_var
    local item_ver
    local total_count
    local current_count=0

    total_count=`echo "scale=1; ${#item_to_create_graph[@]} * ${#cgn_ctrl[@]} + 6 " | bc`
    if [ ${repeat} -ne 1 ]; then
        total_count=`echo "scale=1; ${total_count} + ${#cgn_ctrl[@]} * 3 " | bc`
    fi

    cd tex 

    if !(type platex > /dev/null 2>&1); then
       echo "platex does not exist."
       return 1
    fi

    for cgn_ctrl_var in "${cgn_ctrl[@]}" 
    do
        for item_var in "${item_to_create_graph[@]}" 
        do
            # Alldataがあるし、どうせ見ないからビルドしない 
            # 使いたいならコメント外すべし
            #platex_dvipdfmx_link ${cgn_ctrl_var}_${item_var}_${rootdir} 
            echo "" >/dev/null
        done

        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_queue_${rootdir} 

        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_rtt_${rootdir}
        
        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_time_${rootdir}

        platex_dvipdfmx_link ${cgn_ctrl_var}_alldata_${rootdir}

        platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_ext_${rootdir}
        
        platex_dvipdfmx_link ${cgn_ctrl_var}_srtt_ext_${rootdir}

        if [ ${repeat} -ne 1 ]; then
            platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_queue_${rootdir}_ave
            platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_rtt_${rootdir}_ave
            platex_dvipdfmx_link ${cgn_ctrl_var}_throughput_ext_${rootdir}_ave
        fi
        rm -f *.log
        rm -f *.dvi
        rm -f *.aux

            
    done
    platex_dvipdfmx_link throughput_cgnctrl_${rootdir} 

    for item_var in "${item_to_create_graph[@]}" 
    do
        platex_dvipdfmx_link ${item_var}_cgnctrl_${rootdir} 
    done

    if [ ${repeat} -ne 1 ]; then
        platex_dvipdfmx_link throughput_cgnctrl_${rootdir}_ave
    fi
    rm -f throughput*.log
    rm -f throughput*.dvi
    rm -f throughput*.aux

    echo "[$(hostname)]Build tex file ...done (${current_count} / ${total_count})                       "

    cd ..
}

function create_tex_header {
    local item_name=$1
    local sender_i
    local target_ip
    local kernel_name


    echo '
    \documentclass{jsarticle}
    \usepackage[dvipdfmx]{graphicx}
    \usepackage{grffile}
    \usepackage[top=0truemm,bottom=0truemm,left=0truemm,right=0truemm]{geometry}
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
	echo "Sender & \verb|$(hostname)| \\\\" >> ./tex_header.txt
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
	echo "\verb|sender_delay| & \verb|${sender_delay}|\\\\" >> ./tex_header.txt
	echo "repeat & ${repeat}\\\\" >> ./tex_header.txt
	echo "memo & \verb|${memo}|\\\\" >> ./tex_header.txt
	echo "\end{tabular}" >> ./tex_header.txt
	echo "\end{center}" >> ./tex_header.txt
	echo "\end{table}" >> ./tex_header.txt
	echo "\clearpage" >> ./tex_header.txt
	echo "\newgeometry{top=0truemm,bottom=0truemm,left=5truemm,right=0truemm} " >> ./tex_header.txt
    echo "\begin{verbatim} `cat ../sender_and_ne_status.txt` \end{verbatim}" >> ./tex_header.txt
	echo "\restoregeometry " >> ./tex_header.txt

	echo "\clearpage" >> ./tex_header.txt

	echo "\newgeometry{top=0truemm,bottom=0truemm,left=5truemm,right=0truemm} " >> ./tex_header.txt
    echo "\begin{verbatim} `cat ../default.conf` \end{verbatim}" >> ./tex_header.txt
	echo "\restoregeometry " >> ./tex_header.txt
	echo "\clearpage" >> ./tex_header.txt

}

function join_header {
    local tex_file_name=$1
    if [ -e ./${tex_file_name}.tex ]; then
        cat ./tex_header.txt ./${tex_file_name}.tex > tmp.tex
        mv tmp.tex ./${tex_file_name}.tex 
        rm ./tex_header.txt
        echo "\end{document}" >> ${tex_file_name}.tex
    fi
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
    cgn_ctrl_var=All
    tex_file_name=throughput_cgnctrl_${rootdir}
    create_tex_header "Throughput Congestion Control"
    join_header ${tex_file_name}
    create_tex_header "Throughput Congestion Control ${repeat} repeat"
    join_header ${tex_file_name}_ave

    for item_var in "${item_to_create_graph[@]}" 
    do
        tex_file_name=${item_var}_cgnctrl_${rootdir}
        create_tex_header ${item_var}
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
                                targetdir=${cgn_ctrl_var}_ext=${extended_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}/${repeat_i}th/log
                                cd ${targetdir}
                                tar xzf kern.dat.tar.gz  > /dev/null 2>&1
                                cd ../../../
                                echo -ne "Reprocessing data ...$(calc_progress_percent)% (${current_count} / ${total_count})\r"
                                separate_cwnd
                                get_app_meta
                                extract_cwnd_each_flow
                                count_mptcp_state
                                process_throughput_data
                                process_srtt_ext_boxplot_data
                                (( current_count++))
                            done
                            process_throughput_data_ave
                        done    
                    done
                done
            done
        done
    done
    
    echo "Reprocessing data ...done                                    "
}

