#!/bin/bash

if [ -e "function.sh" ]; then
    source "function.sh"
else
    echo "function.sh dose not exist."
    exit
fi

cgn_ctrl=(lia olia a a a a a)         
rtt1=(50)              
rtt2=(50)              
loss=(0)               
queue=(100) 
duration=100           
app_delay=0.5          
repeat=1               
app=3                  
subflownum=2
qdisc=pfifo_fast       
memo=$1   
today=debug_log
#split_log
targetname=(a b c)
total_count=`echo "scale=1; ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * $repeat " | bc`
echo "total =$total_count"
current_count=0

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
                            percent=`echo "scale=3; $current_count / $total_count * 100 " | bc`
                            percent=`echo "scale=1; $percent / 1 " | bc`
                            echo -ne "processing data ...${percent}%\r"
                            sleep 2
                            (( current_count++))
                        done
                    done
                done
            done
        done
    done
    echo "processing data ...done   "
