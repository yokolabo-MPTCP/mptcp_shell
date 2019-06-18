#!/bin/bash

cwd=`dirname $0`
cd $cwd

debug_today="20171002_14-24-06"
debug_dir="balia_rtt1=5_rtt2=5_loss=0_queue=100"

if [ $# = 0 ]; then
    today=$debug_today
else
    today=$1
    cgn_ctrl=$2
    rtt1=$3
    rtt2=$4
    loss=$5
    appnum=$6
    repeat=$7
    buf=("$@")
    

    i=7
    c=`expr ${#buf[@]}`
    while [ $i -le $c ]
    do
        queue=("${queue[@]}" ${buf[$i]})
        i=`expr $i + 1`
    done
fi




cd ${today}

nowdir=${cgn_ctrl}_rtt1=${rtt1}_rtt2=${rtt2}_loss=${loss}
mkdir ${nowdir}

z=1
while [ $z -le ${repeat} ]
do
    mkdir ${nowdir}/${z}th
    z=`expr $z + 1`
done


z=1
while [ $z -le ${repeat} ]
do

    j=0
    k=1

    while [ $j -lt ${#queue[@]} ]
    do
        k=1
        
        while [ $k -le ${appnum} ]
        do
            throughput=$(cat ${cgn_ctrl}_rtt1=${rtt1}_rtt2=${rtt2}_loss=${loss}_queue=${queue[$j]}/${z}th/throughput/app${k}_.dat)
            echo "${queue[$[j]]} ${throughput}" >> ./${nowdir}/${z}th/app${k}.dat

            k=`expr $k + 1`
        done
        
        
            
        j=`expr $j + 1`
    done

    k=1
    while [ $k -le ${appnum} ]
    do
        if [ $k -eq 1 ]; then
            cp ./${nowdir}/${z}th/app${k}.dat ./${nowdir}/${z}th/graphdata.dat
        else
            join ./${nowdir}/${z}th/graphdata.dat ./${nowdir}/${z}th/app${k}.dat > ${nowdir}/${z}th/tmp.dat
            mv ${nowdir}/${z}th/tmp.dat ./${nowdir}/${z}th/graphdata.dat
        fi
        
        k=`expr $k + 1`
    done

    awk '{
        total=0
        for (i = 2;i <= NF;i++){
            total += $i;
        }
        printf("%s %f\n",$0,total)

    }' ./${nowdir}/${z}th/graphdata.dat > ./${nowdir}/${z}th/graphdata_total.dat

    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set xlabel "queue"
    set ylabel "throughput"
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set datafile separator " " ' > ./${nowdir}/${z}th/plot.plt
    echo "set title \"throughput ${nowdir} ${z}th\"" >> ./${nowdir}/${z}th/plot.plt 
    echo "set yrange [0:200]" >> ./${nowdir}/${z}th/plot.plt
    echo "set output \"throughput_${nowdir}_${z}th.png\"" >> ./${nowdir}/${z}th/plot.plt

    echo -n "plot " >> ./${nowdir}/${z}th/plot.plt
    i=1
    j=1

        j=1
        while [ $j -le $appnum ]
        do
            n=`expr $j + 1`
            echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${j}\" " >> ./${nowdir}/${z}th/plot.plt
            if [ $j != $appnum ];then

                echo -n " , " >> ./${nowdir}/${z}th/plot.plt
            else
                 n=`expr $n + 1`
                 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${nowdir}/${z}th/plot.plt
            fi
            j=`expr $j + 1`

        done

    cd ./${nowdir}/${z}th/
    gnuplot "./plot.plt"
    cd ../../
    #gnuplot "./${nowdir}/${z}th/plot.plt"

    cp ${nowdir}/${z}th/throughput_${nowdir}_${z}th.png ./${nowdir}

    z=`expr $z + 1`
done 


#exit
#----------------------------------ave-------------------------------------------

    mkdir ${nowdir}/ave
    j=0
    k=1

    while [ $j -lt ${#queue[@]} ]
    do
	k=1

	while [ $k -le ${appnum} ]
	do
	    throughput=$(cat ${cgn_ctrl}_rtt1=${rtt1}_rtt2=${rtt2}_loss=${loss}_queue=${queue[$j]}/ave/throughput/app${k}_ave.dat)
	    echo "${queue[$[j]]} ${throughput}" >> ./${nowdir}/ave/app${k}.dat

	    k=`expr $k + 1`
	done


	    
	j=`expr $j + 1`
    done

    k=1
    while [ $k -le ${appnum} ]
    do
	if [ $k -eq 1 ]; then
	    cp ./${nowdir}/ave/app${k}.dat ./${nowdir}/ave/graphdata.dat
	else
	    join ./${nowdir}/ave/graphdata.dat ./${nowdir}/ave/app${k}.dat > ${nowdir}/ave/tmp.dat
	    mv ${nowdir}/ave/tmp.dat ./${nowdir}/ave/graphdata.dat
	fi

	k=`expr $k + 1`
    done

    awk '{
	total=0
	for (i = 2;i <= NF;i++){
	    total += $i;
	}
	printf("%s %f\n",$0,total)

    }' ./${nowdir}/ave/graphdata.dat > ./${nowdir}/ave/graphdata_total.dat

    echo 'set terminal emf enhanced "Arial, 24"
    set terminal png size 960,720
    set xlabel "queue"
    set ylabel "throughput"
    set key outside
    set size ratio 0.5
    set boxwidth 0.5 relative 
    set datafile separator " " ' > ./${nowdir}/ave/plot.plt
    echo "set title \"throughput ${nowdir} ${repeat} times average \"" >> ./${nowdir}/ave/plot.plt 
    echo "set yrange [0:200]" >> ./${nowdir}/ave/plot.plt
    echo "set output \"throughput_${nowdir}_ave.png\"" >> ./${nowdir}/ave/plot.plt

    echo -n "plot " >> ./${nowdir}/ave/plot.plt
    i=1
    j=1

	j=1
	while [ $j -le $appnum ]
	do
	    n=`expr $j + 1`
	    echo -n "\"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 2 title \"APP${j}\" " >> ./${nowdir}/ave/plot.plt
	    if [ $j != $appnum ];then

		echo -n " , " >> ./${nowdir}/ave/plot.plt
	    else
		 n=`expr $n + 1`
		 echo -n " , \"./graphdata_total.dat\" using $n:xtic(1) with linespoints linewidth 4 title \"Total\" " >> ./${nowdir}/ave/plot.plt
	    fi
	    j=`expr $j + 1`

	done

    cd ./${nowdir}/ave/
    gnuplot "./plot.plt"
    cd ../../
    #gnuplot "./${nowdir}/${z}th/plot.plt"

    #cp ${nowdir}/${z}th/throughput_${nowdir}_${z}th.png ./${nowdir}






exit

















