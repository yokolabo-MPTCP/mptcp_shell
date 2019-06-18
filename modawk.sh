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

												

						../awk.sh ${today}/${nowdir}/${i}th ${app} ${num_subflow}
						../count_cwr.sh ${today} ${nowdir} ${i} ${app} ${num_subflow}
						../plot.sh ${today} ${nowdir} ${i} ${app} ${num_subflow} ${duration} ${sleep}		





						cd $cdir
						
						#----------------------------------------------------------------------------------						
						i=`expr $i + 1`
					done
					
					i=1
					k=`expr $k + 1`

				done
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





exit

