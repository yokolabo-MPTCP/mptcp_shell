#!/bin/bash
umask 000
clear

cwd=`dirname $0`
cd $cwd
if [ -e "function.sh" ]; then
    source "function.sh"
else
    echo "function.sh does not exist."
    exit
fi

# User Setting 

cgn_ctrl=(lia)          # congestion control e.g. lia olia balia wvegas cubic reno
rtt1=(50)               # delay of netem [ms]
rtt2=(50)               
loss=(0)                # Packet drop rate of netem [%]
queue=(100 1000 20000)  # The number of IFQ size [packet]
duration=100            # Communication Time [s]
app_delay=0.5           # Time of start time difference [s]
repeat=1                # The number of repeat
app=3                   # The number of Application (iperf)
qdisc=pfifo_fast        # AQM (Active queue management) e.g. pfifo_fast red fq_codel
memo=$1

item_to_create_graph=(cwnd packetsout)
# Kernel variable

no_cwr=0
no_rcv=0
no_small_queue=1 #0:default 1:original
change_small_queue=10 #default:10



kernel=$(uname -r)
mptcp_ver=$(get_mptcp_version)
configure_ip_address $mptcp_ver


#fixed

interval=1
temp=0


band1=100
band2=100

num_subflow=2

timeflag=1
clearpage=0



#reciver setting
receiver_dir="/home/yokolabo/experiment"



today=$(date "+%Y%m%d_%H-%M-%S")
rcvkernel=$(ssh root@${receiver_ip} 'uname -r')
nowdir=$today
mkdir ${today}
cd ${today}

time=`echo "scale=5; ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * $duration * $repeat " | bc`

date
date --date "$time seconds"

create_setting_file


echo "------SETTING---------------------------------"
cat setting.txt
tc qdisc show
echo "----------------------------------------------"



ip link set dev ${eth0} multipath on
ip link set dev ${eth1} multipath on

#ethtool -s ${eth0} speed ${band1} duplex full
#ethtool -s ${eth1} speed ${band2} duplex full

set_kernel_variable
check_network_available


for cgn_ctrl_var in "${cgn_ctrl[@]}" 
do
	sysctl net.ipv4.tcp_congestion_control=${cgn_ctrl_var}
    for rtt1_var in "${rtt1[@]}"
	do
        for rtt2_var in "${rtt2[@]}"
		do
            for loss_var in "${loss[@]}"
			do
                set_netem_rtt_and_loss
				if [ $rtt1_var != $rtt2_var ]; then
					break
					
				fi	
                for queue_var in "${queue[@]}"
				do
					
                    set_txqueuelen
					nowdir=${cgn_ctrl_var}_rtt1=${rtt1_var}_rtt2=${rtt2_var}_loss=${loss_var}_queue=${queue_var}
					mkdir ${nowdir}
						
                    for repeat_i in `seq ${repeat}` 
					do
						mkdir ${nowdir}/${repeat_i}th
						mkdir ${nowdir}/${repeat_i}th/log
						mkdir ${nowdir}/${repeat_i}th/throughput

						echo "${cgn_ctrl_var}_RTT1=${rtt1_var}ms, RTT2=${rtt2_var}ms, LOSS=${loss_var}, queue=${queu_var}pkt, ${repeat_i}回目"

                        clean_log_sender_and_receiver
                        						
                        sleep 0.5
                        run_iperf
												
						sleep 10
						killall iperf &> /dev/null
						sleep 10
						
						format_and_copy_log
					done
				done
			done
		done
	done
done

process_log_data
create_tex_file
build_tex_to_pdf


z=0
while [ $z -lt ${#cgn_ctrl[@]} ]
do
	cp ../tex_header.txt ./tex_header.txt
	echo "\title{cwnd \\\\ ${cgn_ctrl[$z]} }" >> ./tex_header.txt
	echo "\author{Kariya Naito}" >> ./tex_header.txt
	echo "\maketitle" >> ./tex_header.txt
	echo "\begin{table}[h]" >> ./tex_header.txt
	echo "\begin{center}" >> ./tex_header.txt
	echo "\begin{tabular}{ll}" >> ./tex_header.txt
	echo "date & \verb|${today}| \\\\" >> ./tex_header.txt
	echo "\verb|sender_kernel| & \verb|${kernel}| \\\\" >> ./tex_header.txt
	echo "\verb|receiver_kernel| & \verb|${rcvkernel}| \\\\" >> ./tex_header.txt
	echo "mptcp version & ${mptcp_ver} \\\\" >> ./tex_header.txt
	echo "other cgnctrl & ${cgn_ctrl[@]} \\\\" >> ./tex_header.txt
	echo "qdisc & ${qdisc}\\\\" >> ./tex_header.txt
	echo "app & ${app}\\\\" >> ./tex_header.txt
	echo "rtt1 & ${rtt1[@]}\\\\" >> ./tex_header.txt
	echo "rtt2 & ${rtt2[@]}\\\\" >> ./tex_header.txt
	echo "loss & ${loss[@]}\\\\" >> ./tex_header.txt
	echo "queue & ${queue[@]}\\\\" >> ./tex_header.txt
	echo "duration & ${duration}\\\\" >> ./tex_header.txt
	echo "sleep & ${sleep}\\\\" >> ./tex_header.txt
	echo "repeat & ${repeat}\\\\" >> ./tex_header.txt
	echo "nocwr & ${no_cwr}\\\\" >> ./tex_header.txt
	echo "norcv & ${no_rcv}\\\\" >> ./tex_header.txt
	echo "\verb|no_small_queue| & ${no_small_queue}\\\\" >> ./tex_header.txt
	echo "\verb|num_subflow| & \verb|${num_subflow}| \\\\" >> ./tex_header.txt
	echo "memo & \verb|${memo}|\\\\" >> ./tex_header.txt
	echo "\end{tabular}" >> ./tex_header.txt
	echo "\end{center}" >> ./tex_header.txt
	echo "\end{table}" >> ./tex_header.txt
	echo "\clearpage" >> ./tex_header.txt

	cat ./tex_header.txt ${cgn_ctrl[$z]}_cwnd_${today}.tex > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_cwnd_${today}.tex
	cat ${cgn_ctrl[$z]}_cwnd_${today}.tex ../tex_footer.txt > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_cwnd_${today}.tex

	cp ../tex_header.txt ./tex_header.txt
	echo "\title{Throughput \\\\ ${cgn_ctrl[$z]} }" >> ./tex_header.txt
	echo "\author{Kariya Naito}" >> ./tex_header.txt
	echo "\maketitle" >> ./tex_header.txt
	echo "\begin{table}[h]" >> ./tex_header.txt
	echo "\begin{center}" >> ./tex_header.txt
	echo "\begin{tabular}{ll}" >> ./tex_header.txt
	echo "date & \verb|${today}| \\\\" >> ./tex_header.txt
	echo "\verb|sender_kernel| & \verb|${kernel}| \\\\" >> ./tex_header.txt
	echo "\verb|receiver_kernel| & \verb|${rcvkernel}| \\\\" >> ./tex_header.txt
	echo "mptcp version & ${mptcp_ver} \\\\" >> ./tex_header.txt
	echo "other cgnctrl & ${cgn_ctrl[@]}\\\\" >> ./tex_header.txt
	echo "qdisc & \verb|${qdisc}|\\\\" >> ./tex_header.txt
	echo "app & ${app}\\\\" >> ./tex_header.txt
	echo "rtt1 & ${rtt1[@]}\\\\" >> ./tex_header.txt
	echo "rtt2 & ${rtt2[@]}\\\\" >> ./tex_header.txt
	echo "loss & ${loss[@]}\\\\" >> ./tex_header.txt
	echo "queue & ${queue[@]}\\\\" >> ./tex_header.txt
	echo "duration & ${duration}\\\\" >> ./tex_header.txt
	echo "sleep & ${sleep}\\\\" >> ./tex_header.txt
	echo "repeat & ${repeat}\\\\" >> ./tex_header.txt
	echo "nocwr & ${no_cwr}\\\\" >> ./tex_header.txt
	echo "norcv & ${no_rcv}\\\\" >> ./tex_header.txt
	echo "\verb|no_small_queue| & ${no_small_queue}\\\\" >> ./tex_header.txt
	echo "\verb|num_subflow| & \verb|${num_subflow}| \\\\" >> ./tex_header.txt
	echo "memo & \verb|${memo}|\\\\" >> ./tex_header.txt
	echo "\end{tabular}" >> ./tex_header.txt
	echo "\end{center}" >> ./tex_header.txt
	echo "\end{table}" >> ./tex_header.txt
	echo "\clearpage" >> ./tex_header.txt

	cat ./tex_header.txt ${cgn_ctrl[$z]}_throughput_${today}.tex > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_throughput_${today}.tex
	cat ${cgn_ctrl[$z]}_throughput_${today}.tex ../tex_footer.txt > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_throughput_${today}.tex

	cat ./tex_header.txt ${cgn_ctrl[$z]}_throughput_${today}_ave.tex > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_throughput_${today}_ave.tex
	cat ${cgn_ctrl[$z]}_throughput_${today}_ave.tex ../tex_footer.txt > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_throughput_${today}_ave.tex
	z=`expr $z + 1`
done



sysctl net.mptcp.mptcp_debug=0
sysctl net.mptcp.mptcp_enabled=1
#sysctl net.core.netdev_debug=0
sysctl net.mptcp.mptcp_no_cwr=0
umask 022

date
