#!/bin/bash

cwd=`dirname $0`
cd $cwd


##debug

debug_dir="20170929_13-13-00"


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



select VAR in "all" "lia(coupled)" "olia" "balia" "wvegas" "exit"

#echo "$VAR"
do
	if [ "$VAR" = "all" ]; then
	
		break
	elif [ "$VAR" = "lia(coupled)" ];then
		cgn_ctrl=(lia)
		if [ "$mptcp_ver" = 0.86 ]; then
			cgn_ctrl=(coupled)
		fi
		break
	elif [ "$VAR" = "olia" ];then
		cgn_ctrl=(olia)
		break	
	elif [ "$VAR" = "balia" ];then
		cgn_ctrl=(balia)
		break		
	elif [ "$VAR" = "wvegas" ];then
		cgn_ctrl=(wvegas)
		break

	elif [ "$VAR" = "exit" ];then
		exit
	else
		echo ""
	fi
done

#echo ${cgn_ctrl[@]}
#echo ${rtt1[@]}
#echo ${rtt2[@]}
#echo ${loss[@]}
#echo ${repeat}

echo "" > avedata_for_excel.txt

z=0
while [ $z -lt ${#cgn_ctrl[@]} ]
do
i=1
j=0
k=0
l=0
m=0
o=1
p=1
	while [ $l -lt ${#loss[@]} ]
	do

		while [ $j -lt ${#rtt1[@]} ]
		do
		
			while [ $m -lt ${#rtt2[@]} ]
			do
			
			
					
					if [ $j != $m ]; then
						m=`expr $m + 1`
						continue
					fi
					echo "${cgn_ctrl[$z]}_rtt1=${rtt1[$j]}_rtt2=${rtt2[$m]}_loss=${loss[$l]}"  >> avedata_for_excel.txt
					
			
					nowdir="${cgn_ctrl[$z]}_rtt1=${rtt1[$j]}_rtt2=${rtt2[$m]}_loss=${loss[$l]}"
					#----------------------------------------------------------------------------------
										
					echo "${nowdir}"
				
				
					cat avedata_for_excel.txt ${nowdir}/ave/graphdata_total.dat >> tmp.txt
					mv tmp.txt avedata_for_excel.txt
					echo "" >> avedata_for_excel.txt
					echo "" >> avedata_for_excel.txt
					#----------------------------------------------------------------------------------						
												
					
				m=`expr $m + 1`
			done
			m=0
			j=`expr $j + 1`
		done
		j=0	
		l=`expr $l + 1`	
	done
	l=0
	z=`expr $z + 1`
done





exit

