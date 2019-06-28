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
configure_ip_address mptcp_ver


exit


#fixed

interval=1
i=1
j=0
k=0
l=0
m=0
z=0
temp=0

app_i=1

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

while [ $z -lt ${#cgn_ctrl[@]} ]
do
i=1
j=0
k=0
l=0
m=0
cwndtexcount=1
SECONDS=0
clearpage=0
	sysctl net.ipv4.tcp_congestion_control=${cgn_ctrl[$z]}
	while [ $j -lt ${#rtt1[@]} ]
	do

		while [ $m -lt ${#rtt2[@]} ]
		do
		

			while [ $l -lt ${#loss[@]} ]
			do
                set_netem_rtt_and_loss
				if [ $j != $m ]; then
					break
					
				fi	


				while [ $k -lt ${#queue[@]} ]
				do
					
                    set_txqueuelen
					nowdir=${cgn_ctrl[$z]}_rtt1=${rtt1[$j]}_rtt2=${rtt2[$m]}_loss=${loss[$l]}_queue=${queue[$k]}
					mkdir ${nowdir}
						
					while [ $i -le $repeat ]
					do
						
						
						app_i=1

						mkdir ${nowdir}/${i}th
						mkdir ${nowdir}/${i}th/log
						mkdir ${nowdir}/${i}th/throughput


						ssh root@${receiver_ip} "sysctl net.mptcp.mptcp_debug=1" > /dev/null
						echo "${cgn_ctrl[$z]}_RTT1=${rtt1[$j]}ms, RTT2=${rtt2[$m]}ms, LOSS=${loss[$l]}, queue=${queue[$k]}pkt, ${i}回目"

                        crean_log_sender_and_receiver
                        						
                        sleep 0.5
                        run_iperf
												
						sleep 10
						killall iperf &> /dev/null
						sleep 10
						
						#receiver
						ssh root@${receiver_ip} "sysctl net.mptcp.mptcp_debug=0" > /dev/null
						##ssh root@${receiver_ip} "cd ${reciever_dir}/ && ./reciever_exp.sh ${today}"
						format_and_copy_log
						
						
						../awk.sh ${today}/${nowdir}/${i}th ${app} ${num_subflow}
						../count_cwr.sh ${today} ${nowdir} ${i} ${app} ${num_subflow}
						../plot.sh ${today} ${nowdir} ${i} ${app} ${num_subflow} ${duration} ${sleep}
						if [ `expr $cwndtexcount % 3` = 0 ]; then 
							clearpage=1
						fi
						../cwnd_tex.sh ${today} ${nowdir} ${cgn_ctrl[$z]} ${rtt1[$j]} ${rtt2[$m]} ${loss[$l]} ${queue[$k]} ${i} ${clearpage}
						clearpage=0						

						i=`expr $i + 1`
						cwndtexcount=`expr $cwndtexcount + 1`
						
						if [ $timeflag = 1 ]; then
							onetime=$SECONDS
							time2=`echo "scale=5; ${#cgn_ctrl[@]} * ${#rtt1[@]} * ${#loss[@]} * ${#queue[@]} * $repeat * $onetime " | bc`
							echo "終了予想時刻 `date --date "$time2 seconds"`"
							timeflag=2				
						fi

					done
					
					../ave.sh ${today} ${nowdir} ${repeat} ${app} ${num_subflow}
					
					i=1
					k=`expr $k + 1`

					

				done
				../thput.sh ${today} ${cgn_ctrl[$z]} ${rtt1[$j]} ${rtt2[$m]} ${loss[$l]} ${app} ${repeat} ${queue[@]}
				../thput_tex.sh ${today} ${nowdir} ${cgn_ctrl[$z]} ${rtt1[$j]} ${rtt2[$m]} ${loss[$l]} ${repeat} ${clearpage}
				k=0
				l=`expr $l + 1`


			done
			l=0
			m=`expr $m + 1`
		done
			m=0
			j=`expr $j + 1`
	done
	z=`expr $z + 1`
done

split_log

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

	if [ $make_tex = 1 ]; then
		echo "Make tex file ..."
		platex -halt-on-error ${cgn_ctrl[$z]}_cwnd_${today}.tex > /dev/null
		dvipdfmx ${cgn_ctrl[$z]}_cwnd_${today}.dvi > /dev/null

		platex -halt-on-error ${cgn_ctrl[$z]}_throughput_${today}.tex > /dev/null
		dvipdfmx ${cgn_ctrl[$z]}_throughput_${today}.dvi > /dev/null

		platex -halt-on-error ${cgn_ctrl[$z]}_throughput_${today}_ave.tex > /dev/null
		dvipdfmx ${cgn_ctrl[$z]}_throughput_${today}_ave.dvi > /dev/null

		rm ${cgn_ctrl[$z]}_cwnd_${today}.aux
		rm ${cgn_ctrl[$z]}_cwnd_${today}.log
		rm ${cgn_ctrl[$z]}_cwnd_${today}.dvi
		rm ${cgn_ctrl[$z]}_throughput_${today}.aux
		rm ${cgn_ctrl[$z]}_throughput_${today}.log
		rm ${cgn_ctrl[$z]}_throughput_${today}.dvi
		rm ${cgn_ctrl[$z]}_throughput_${today}_ave.aux
		rm ${cgn_ctrl[$z]}_throughput_${today}_ave.log
		rm ${cgn_ctrl[$z]}_throughput_${today}_ave.dvi
	fi
	z=`expr $z + 1`
done



sysctl net.mptcp.mptcp_debug=0
sysctl net.mptcp.mptcp_enabled=1
#sysctl net.core.netdev_debug=0
sysctl net.mptcp.mptcp_no_cwr=0
umask 022

date
