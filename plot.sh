#!/bin/bash

cwd=`dirname $0`
cd $cwd

##debug

debug_today="20170929_13-52-27"
debug_dir=""

##

if [ $# = 0 ]; then
    today=$debug_today
    nowdir=$debug_dir
    repeat=2
    appnum=2
    subflownum=2
    second=5
else
    today=$1
    nowdir=$2
    repeat=$3
    appnum=$4
    subflownum=$5
    second=$6
    sleep=$7
fi

cd ${today}/${nowdir}/${repeat}th

scale=$((second / 5))


echo 'set terminal emf enhanced "Arial, 24"
set terminal png size 960,720
set key outside
set size ratio 0.5
set xlabel "time[s]"
set ylabel "number of packets"
set datafile separator " " ' > plot.plt
#echo "set title \"cwnd ${nowdir} ${repeat}th\"" >> plot.plt
echo "set key spacing 8" >> plot.plt
echo "set xtics $scale" >> plot.plt
echo "set xrange [0:${second}]" >> plot.plt
#echo "set yrange [0:200]" >> plot.plt
echo "set output \"cwnd_${nowdir}_${repeat}th.png\"" >> plot.plt

echo -n "plot " >> plot.plt
i=1
j=1
while [ $i -le $appnum ] 
do
    j=1
    while [ $j -le $subflownum ]
    do
        cwndreduced=$(awk 'NR==1' ./log/cwnd${i}_subflow${j}_cwndreduced.dat)
        sendstall=$(awk 'NR==1' ./log/cwnd${i}_subflow${j}_sendstall.dat)
        rcv_buf=$(awk 'NR==1' ./log/cwnd${i}_subflow${j}_rcv_buf.dat)
        echo -n "\"./log/cwnd${i}_subflow${j}.dat\" using 1:7 with lines linewidth 2 title \"APP${i} : subflow${j}   \n sendstall=${sendstall}\nrcvbuf=${rcv_buf}\" " >> plot.plt
        #echo -n "\"./log/cwnd${i}_subflow${j}.dat\" using 1:7 with lines linewidth 2 title \"APP${i} : subflow${j}\n cwndreduced=${cwndreduced}\n  sendstall=${sendstall}\n  rbuf-opti1=${rbuf_opti1}\n  rbuf-opti2=${rbuf_opti2} \" " >> plot.plt
        #echo -n "\"./log/cwnd${i}_subflow${j}.dat\" using 1:7 with points title \"APP${i} : subflow${j}\" " >> plot.plt
        if [ $i != $appnum ] || [ $j != $subflownum ];then

           echo -n " , " >> plot.plt
            
        fi
        j=`expr $j + 1`

    done
    i=`expr $i + 1`
done

gnuplot << EOF
    load "plot.plt"
EOF

cp cwnd_${nowdir}_${repeat}th.png ../

exit
if [ $sleep -lt 1 ]; then
    exit
fi

k=1
while [ $k -le ${appnum} ]
do
    
    sed '$d' ./throughput/app${k}.dat > ./throughput/app${k}_graph.dat
    sed -e '1','6d' ./throughput/app${k}_graph.dat > ./throughput/tmp.dat
    mv ./throughput/tmp.dat ./throughput/app${k}_graph.dat
    
    startgraph=$((sleep * k - sleep))
    x=0
    while [ $x -le ${startgraph} ]
    do
        echo "${x} 0" >> ./throughput/tmp.dat
        x=`expr $x + 1`
    done
    awk -v startgraph=${startgraph} 'BEGIN{
        count=startgraph+1;
        }{
            if(NF==9){
                printf("%d %s\n",count,$8);
            }else{
                printf("%d %s\n",count,$7);
            }
        count++;
    }' ./throughput/app${k}_graph.dat >> ./throughput/tmp.dat
    mv ./throughput/tmp.dat ./throughput/app${k}_graph.dat
    
    k=`expr $k + 1`
done

k=1
while [ $k -le ${appnum} ]
do
    if [ $k -eq 1 ]; then
        cp ./throughput/app${k}_graph.dat ./throughput/graphdata.dat
    else
        join ./throughput/graphdata.dat ./throughput/app${k}_graph.dat > ./throughput/tmp.dat
        mv ./throughput/tmp.dat ./throughput/graphdata.dat
    fi
    k=`expr $k + 1`
done

 awk '{
        sum=0;
        for(i=2;i<=NF;i++){
            sum+=$i
        }
        printf("%s %f\n",$0, sum);
}' ./throughput/graphdata.dat >> ./throughput/graph_total.dat




echo 'set terminal emf enhanced "Arial, 24"
set terminal png
set xlabel "time[s]"
set key outside
set lmargin 0
set rmargin 0
set tmargin 0
set bmargin 0
set ylabel "throughput[Mbits/s]"
set datafile separator " " ' > ./throughput/plot.plt
n=`expr $j + 1`
echo "set title \"Throughput ${nowdir} ${repeat}th\"" >> ./throughput/plot.plt
echo "set yrange [0:300]" >> ./throughput/plot.plt
echo "set output \"./throughput/throughput_${nowdir}_${repeat}th.png\"" >> ./throughput/plot.plt

echo -n "plot " >> ./throughput/plot.plt
i=1
j=1

    j=1
    while [ $j -le $appnum ]
    do
        n=`expr $j + 1`
        echo -n "\"./throughput/graph_total.dat\" using $n:xtic(1) with lines linewidth 2 title \"APP${j}\" " >> ./throughput/plot.plt
        if [ $j != $appnum ];then
            echo -n " , " >> ./throughput/plot.plt
        else
            n=`expr $n + 1`
            echo -n " , \"./throughput/graph_total.dat\" using $n:xtic(1) with lines linewidth 4 title \"Total\" " >> ./throughput/plot.plt      
        fi
        j=`expr $j + 1`

    done
    


gnuplot "./throughput/plot.plt"

cp ./throughput/throughput_${nowdir}_${repeat}th.png ../
