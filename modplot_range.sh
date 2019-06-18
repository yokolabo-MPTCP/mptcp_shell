#!/bin/bash

cwd=`dirname $0`
cd $cwd
pwd

make_tex=1

##debug


##

mes="\nusage:  \t$0 [max xrange] \n\t$0 [max xrange] [path of directory] \n"

if [ $# = 0 ]; then
    echo -e $mes
    exit
elif [ $# = 1 ]; then
    if [ ! -e "setting.txt" ]; then
	echo -e "\n not found setting.txt"
	echo -e $mes
    	exit
    else
	setting="setting.txt"
	targetname=$1
	cdir=$cwd
	cdir=$(pwd)
    fi
elif [ $# = 2 ]; then
    if [ ! -e "$2/setting.txt" ]; then
	echo -e "\n not found setting.txt"
	echo -e $mes
    	exit
    else
	cdir=$2
	cd $cdir
	cdir=$(pwd)
	setting="setting.txt"
	targetname=$1
    fi
else
    echo -e $mes
    exit
fi

expr 1 + $1 > /dev/null 2>&1
if [ $? -gt 1 ]; then
	echo -e $mes	
	exit
fi
cgn_ctrl=($(awk '{if($1~"conguestion_control"){$1="";print;exit;}}' $setting))
rtt1=($(awk '{if($1~"rtt1"){$1="";print;exit;}}' $setting))
rtt2=($(awk '{if($1~"rtt2"){$1="";print;exit;}}' $setting))
loss=($(awk '{if($1~"loss"){$1="";print;exit;}}' $setting))
queue=($(awk '{if($1~"queue"){$1="";print;exit;}}' $setting))
repeat=$(awk '{if($1~"repeat"){$1="";print;exit;}}' $setting)
duration=$(awk '{if($1~"duration"){$1="";print;exit;}}' $setting)
today=$(awk '{if($1~"Date"){$1="";print;exit;}}' $setting)

today=`echo ${today} | sed -e "s/[\r\n]\+//g"`

select VAR in "all" "lia" "olia" "balia" "wvegas" "exit"

#echo "$VAR"
do
	if [ "$VAR" = "all" ]; then
	
		break
	elif [ "$VAR" = "lia" ];then
		cgn_ctrl=(lia)
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

												

						awk -v target=${targetname} '{
						   for(i=1;i<=NF;i++){
							if($i ~ "xrange"){
						        printf("set xrange [0:%d] \n",target)
							 next
						    	}else if($i ~ "xtics"){
							 printf("set xtics %f \n",target/5)
							 next
							}else if(i == NF){
							 print $0
							}
						    }
 						   
						}' ./${i}th/plot.plt > ./${i}th/plot2.plt
	
						cd ${i}th/
						gnuplot ./plot2.plt
									





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

cd $cdir
echo $cdir
echo $today
z=0
while [ $z -lt ${#cgn_ctrl[@]} ]
do
	if [ $make_tex = 1 ]; then
		echo "Make tex file ..."
		platex -halt-on-error ${cgn_ctrl[$z]}_cwnd_${today}.tex > /dev/null
		dvipdfmx ${cgn_ctrl[$z]}_cwnd_${today}.dvi > /dev/null

		#platex -halt-on-error ${cgn_ctrl[$z]}_throughput_${today}.tex > /dev/null
		#dvipdfmx ${cgn_ctrl[$z]}_throughput_${today}.dvi > /dev/null

		rm ${cgn_ctrl[$z]}_cwnd_${today}.aux
		rm ${cgn_ctrl[$z]}_cwnd_${today}.log
		rm ${cgn_ctrl[$z]}_cwnd_${today}.dvi
		#rm ${cgn_ctrl[$z]}_throughput_${today}.aux
		#rm ${cgn_ctrl[$z]}_throughput_${today}.log
		#rm ${cgn_ctrl[$z]}_throughput_${today}.dvi
	fi
	z=`expr $z + 1`
done

exit

