#!/bin/bash

cwd=`dirname $0`
cd $cwd

##debug

debug_today="20171101_10-23-07"
debug_dir="coupled_rtt1=10_rtt2=10_loss=0_queue=100"

##

if [ $# = 0 ]; then
    today=$debug_today
    nowdir=$debug_dir
    repeat=1
    appnum=2
    subflownum=2
else
    today=$1
    nowdir=$2
    repeat=$3
    appnum=$4
    subflownum=$5
fi

cd ${today}/${nowdir}/${repeat}th/log

i=1
j=1
while [ $i -le $appnum ] 
do
    j=1
    while [ $j -le $subflownum ]
    do
        grep -ic "send_stall" cwnd${i}_subflow${j}.dat > cwnd${i}_subflow${j}_sendstall.dat
        j=`expr $j + 1`

    done
    i=`expr $i + 1`
done

i=1
j=1
while [ $i -le $appnum ] 
do
    j=1
    while [ $j -le $subflownum ]
    do
        grep -ic "cwnd_reduced" cwnd${i}_subflow${j}.dat > cwnd${i}_subflow${j}_cwndreduced.dat
        j=`expr $j + 1`

    done
    i=`expr $i + 1`
done

i=1
j=1
while [ $i -le $appnum ] 
do
    j=1
    while [ $j -le $subflownum ]
    do
        grep -ic "rcv_buf" cwnd${i}_subflow${j}.dat > cwnd${i}_subflow${j}_rcv_buf.dat
        j=`expr $j + 1`

    done
    i=`expr $i + 1`
done




exit
####################




i=1
j=1
while [ $i -le $appnum ] 
do
    j=1
    while [ $j -le $subflownum ]
    do
        grep -ic "rbuf_opti1" cwnd${i}_subflow${j}.dat > cwnd${i}_subflow${j}_rbuf_opti1.dat
        j=`expr $j + 1`

    done
    i=`expr $i + 1`
done




i=1
j=1
while [ $i -le $appnum ] 
do
    j=1
    while [ $j -le $subflownum ]
    do
        grep -ic "rbuf_opti2" cwnd${i}_subflow${j}.dat > cwnd${i}_subflow${j}_rbuf_opti2.dat
        j=`expr $j + 1`

    done
    i=`expr $i + 1`
done
