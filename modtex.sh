#!/bin/bash

cwd=`dirname $0`
cd $cwd
pwd

##debug


##

mes="\nusage:  \t$0 [path of directory] \n"

if [ $# = 0 ]; then
    echo -e $mes
    exit
elif [ $# = 1 ]; then
    if [ ! -e "$1/setting.txt" ]; then
	echo -e "\n not found setting.txt"
	echo -e $mes
    	exit
    else
	setting="setting.txt"
	cdir=$1
	cd $cdir
	cdir=$(pwd)
    fi

else
    echo -e $mes
    exit
fi

cgn_ctrl=($(awk '{if($1~"conguestion_control"){$1="";print;exit;}}' $setting))
rtt1=($(awk '{if($1~"rtt1"){$1="";print;exit;}}' $setting))
rtt2=($(awk '{if($1~"rtt2"){$1="";print;exit;}}' $setting))
loss=($(awk '{if($1~"loss"){$1="";print;exit;}}' $setting))
queue=($(awk '{if($1~"queue"){$1="";print;exit;}}' $setting))
repeat=$(awk '{if($1~"repeat"){$1="";print $2;exit;}}' $setting)
duration=$(awk '{if($1~"duration"){$1="";print $2;exit;}}' $setting)
today=$(awk '{if($1~"Date"){$1="";print $2;exit;}}' $setting)
num_subflow=$(awk '{if($1~"num_subflow"){$1="";print $2;exit;}}' $setting)
sleep=$(awk '{if($1~"sleep"){$1="";print $2;exit;}}' $setting)
app=$(awk '{if($1~"app"){$1="";print $2;exit;}}' $setting)
kernel=$(awk '{if($1~"sender_kernel"){$1="";print $2;exit;}}' $setting)
rcvkernel=$(awk '{if($1~"reciever_kernel"){$1="";print $2;exit;}}' $setting)
mptcp_ver=$(awk '{if($1~"mptcp_ver"){$1="";print $2;exit;}}' $setting)
qdisc=$(awk '{if($1~"qdisc"){$1="";print $2;exit;}}' $setting)
interval=$(awk '{if($1~"interval"){$1="";print $2;exit;}}' $setting)
no_cwr=$(awk '{if($1~"no_cwr"){$1="";print $2;exit;}}' $setting)
no_rcv=$(awk '{if($1~"no_rcv"){$1="";print $2;exit;}}' $setting)
no_small_queue=$(awk '{if($1~"no_small_queue"){$1="";print $2;exit;}}' $setting)
memo=$(awk '{if($1~"memo"){$1="";print $2;exit;}}' $setting)

#echo ${cgn_ctrl[@]}
#echo ${rtt1[@]}
#echo ${rtt2[@]}
#echo ${loss[@]}
#echo ${num_subflow}
make_tex=1
clearpage=0
cwndtexcount=1
z=0
while [ $z -lt ${#cgn_ctrl[@]} ]
do
i=1
j=0
k=0
l=0
m=0	

	while [ $j -lt ${#rtt1[@]} ]
	do
		
		while [ $m -lt ${#rtt2[@]} ]
		do
			
			while [ $l -lt ${#loss[@]} ]
			do
				
				if [ $j != $m ]; then
					break
				fi
				
				while [ $k -lt ${#queue[@]} ]
				do
					
					while [ $i -le $repeat ]
					do
						echo "${cgn_ctrl[$z]} ${rtt1[$j]} ${rtt2[$m]} ${loss[$l]} ${queue[$k] $i}"
						nowdir="${cgn_ctrl[$z]}_rtt1=${rtt1[$j]}_rtt2=${rtt2[$m]}_loss=${loss[$l]}_queue=${queue[$k]}"
						#----------------------------------------------------------------------------------
						
						cd $nowdir
						cd ../

												

						#../awk.sh ${today}/${nowdir}/${i}th ${app} ${num_subflow}
						#../count_cwr.sh ${today} ${nowdir} ${i} ${app} ${num_subflow}
						#../plot.sh ${today} ${nowdir} ${i} ${app} ${num_subflow} ${duration} ${sleep}		
						if [ `expr $cwndtexcount % 3` = 0 ]; then 
							clearpage=1
						fi
						../cwnd_tex.sh ${today} ${nowdir} ${cgn_ctrl[$z]} ${rtt1[$j]} ${rtt2[$m]} ${loss[$l]} ${queue[$k]} ${i} ${clearpage}
						clearpage=0	




						cd $cdir
						
						#----------------------------------------------------------------------------------						
						i=`expr $i + 1`
						cwndtexcount=`expr $cwndtexcount + 1`
					done
					
					i=1
					k=`expr $k + 1`

				done
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
	echo "\verb|reciever_kernel| & \verb|${rcvkernel}| \\\\" >> ./tex_header.txt
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
	
	cat ./tex_header.txt ./${cgn_ctrl[$z]}_cwnd_${today}.tex > tmp.tex
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
	echo "\verb|reciever_kernel| & \verb|${rcvkernel}| \\\\" >> ./tex_header.txt
	echo "mptcp version & ${mptcp_ver} \\\\" >> ./tex_header.txt
	echo "other cgnctrl & ${cgn_ctrl[@]}\\\\" >> ./tex_header.txt
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

	cat ./tex_header.txt ${cgn_ctrl[$z]}_throughput_${today}.tex > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_throughput_${today}.tex
	cat ${cgn_ctrl[$z]}_throughput_${today}.tex ../tex_footer.txt > tmp.tex
	mv tmp.tex ${cgn_ctrl[$z]}_throughput_${today}.tex

	if [ $make_tex = 1 ]; then
		echo "Make tex file ..."
		platex -halt-on-error ${cgn_ctrl[$z]}_cwnd_${today}.tex > /dev/null
		dvipdfmx ${cgn_ctrl[$z]}_cwnd_${today}.dvi > /dev/null

		platex -halt-on-error ${cgn_ctrl[$z]}_throughput_${today}.tex > /dev/null
		dvipdfmx ${cgn_ctrl[$z]}_throughput_${today}.dvi > /dev/null

		rm ${cgn_ctrl[$z]}_cwnd_${today}.aux
		rm ${cgn_ctrl[$z]}_cwnd_${today}.log
		rm ${cgn_ctrl[$z]}_cwnd_${today}.dvi
		rm ${cgn_ctrl[$z]}_throughput_${today}.aux
		rm ${cgn_ctrl[$z]}_throughput_${today}.log
		rm ${cgn_ctrl[$z]}_throughput_${today}.dvi
	fi
	z=`expr $z + 1`
done




exit

