#!/bin/bash

if [ -e "function.sh" ]; then
    source "function.sh"
else
    echo "function.sh dose not exist."
    exit
fi

cgn_ctrl=(lia)         
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

select VAR in ${targetname[@]} "exit"
do
    echo $VAR
done
