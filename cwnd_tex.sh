#!/bin/bash

cwd=`dirname $0`
cd $cwd

##debug

debug_today="20171006_20-36-38"
debug_dir="balia_rtt1=5_rtt2=5_loss=0.001_queue=100"

##

if [ $# = 0 ]; then
    today=$debug_today
    nowdir=$debug_dir
    cgn_ctrl=balia
    rtt1=5
    rtt2=5
    loss=0.001
    queue=100
    repeat=1
    
else
    today=$1
    nowdir=$2
    cgn_ctrl=$3
    rtt1=$4
    rtt2=$5
    loss=$6
    queue=$7
    repeat=$8
    clearpage=$9

fi

cd ${today}/

#echo "\begin{center} ${cgn_ctrl} RTT1=${rtt1}ms RTT2=${rtt2}ms LOSS=${loss}\% queue=${queue}pkt ${repeat}回目 \end{center}" >> cwnd_${today}.tex

echo "\begin{figure}[htbp]" >> ${cgn_ctrl}_cwnd_${today}.tex
echo "\begin{center}" >> ${cgn_ctrl}_cwnd_${today}.tex
echo '\includegraphics[width=95mm]' >> ${cgn_ctrl}_cwnd_${today}.tex
echo "{${cgn_ctrl}_rtt1=${rtt1}_rtt2=${rtt2}_loss=${loss}_queue=${queue}/${repeat}th/cwnd_${cgn_ctrl}_rtt1=${rtt1}_rtt2=${rtt2}_loss=${loss}_queue=${queue}_${repeat}th.png}" >> ${cgn_ctrl}_cwnd_${today}.tex
echo "\caption{${cgn_ctrl} RTT1=${rtt1}ms RTT2=${rtt2}ms LOSS=${loss}\% queue=${queue}pkt ${repeat}回目}" >> ${cgn_ctrl}_cwnd_${today}.tex
echo '\end{center}
\end{figure}' >> ${cgn_ctrl}_cwnd_${today}.tex
if [ $clearpage = 1 ]; then 
	echo "\clearpage" >> ${cgn_ctrl}_cwnd_${today}.tex
fi
