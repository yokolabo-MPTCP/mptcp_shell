#!/bin/bash

cwd=`dirname $0`
cd $cwd

debug_today="20171002_14-24-06"
debug_dir="balia_rtt1=5_rtt2=5_loss=0_queue=100"

if [ $# = 0 ]; then
    today=$debug_today
    nowdir=$debug_dir
    repeat=2
    appnum=3
    subflownum=2
    second=5
else
    today=$1
    nowdir=$2
    repeat=$3
    appnum=$4
    subflownum=$5
fi

cd ${today}/${nowdir}


mkdir ave
mkdir ave/throughput


i=1
app_i=1


while [ $app_i -le $appnum ]
do
    i=1
    while [ $i -le $repeat ]
    do
    
        awk 'END{
            if(NF==9){
		  if($9 ~ "Kbits/sec"){	
			printf("%s Mbits/sec\n",$8/1000);
		  }else{
			printf("%s %s\n",$8,$9);		
		  }
                
            }else{
		  if($8 ~ "Kbits/sec"){	
			printf("%s Mbits/sec\n",$7/1000);
		  }else{
			printf("%s %s\n",$7,$8);		
		  }
            }
            
        }' ./${i}th/throughput/app${app_i}.dat >> ./ave/throughput/app${app_i}.dat

        awk 'END{
            if(NF==9){
		  if($9 ~ "Kbits/sec"){	
		  	printf("%s\n",$8/1000);
		  }else{
			printf("%s\n",$8);		
		  }
                
            }else{
                if($8 ~ "Kbits/sec"){	
		  	printf("%s\n",$7/1000);
		  }else{
			printf("%s\n",$7);		
		  }
            }
        }' ./${i}th/throughput/app${app_i}.dat >> ./${i}th/throughput/app${app_i}_.dat
            
        i=`expr $i + 1`
    done

    awk -v repeat=${repeat} 'BEGIN{
            total=0
        }{
            total = total + $1
        }END{
        total = total / repeat
        printf("%s\n",total);
    }' ./ave/throughput/app${app_i}.dat >> ./ave/throughput/app${app_i}_ave.dat



app_i=`expr $app_i + 1`
done
