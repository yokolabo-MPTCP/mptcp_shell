#!/bin/bash

cwd=`dirname $0`
cd $cwd

##debug

debug_dir="20170929_13-13-00"


##

if [ $# = 0 ]; then
    dir=$debug_dir
    appnum=2
    subflownum=2
else
    dir=$1
    appnum=$2
    subflownum=$3
fi

cd $dir



awk '{
    if($11 ~ "cwnd="){
        if(NF == 18){
            printf("%s %s %s %s %s %s %s %s %s",$1,$5,$6,$8,$9,$11,$12,$17,$18)
        }else if(NF == 13){
            printf("%s %s %s %s %s %s %s %s",$1,$5,$6,$8,$9,$11,$12,$13)
        }else{
            printf("%s %s %s %s %s %s %s %s %s %s",$1,$5,$6,$8,$9,$11,$12,$17,$18,$19)
        }
        
    }else if($10 ~ "cwnd="){
	if(NF == 18){
            printf("%s %s %s %s %s %s %s %s %s %s",$1,$4,$5,$7,$8,$10,$11,$16,$17,$18)
        }

    }else{
        next
    }
    print ""
}' ./log/kern.dat > ./log/cwnd.dat

## app
awk '{
    if($5 ~ "meta="){
        array[$6]++   
    }
}END{
    for(i in array){
        printf("%s %d\n",i,array[i])
    }    
}' ./log/kern.dat > ./log/app.dat

sort -k2nr ./log/app.dat > ./log/app_sort.dat
mv ./log/app_sort.dat ./log/app.dat


awk -v app=${appnum} '{
    if(FNR <= app){
        print $0
    }
}' ./log/app.dat > ./log/app_num_order.dat





i=1
while [ $i -le $appnum ] 
do
    app[$i]=$(awk -v n=${i} '{
        if(NR==n){
            print $1
        }    
    }' ./log/app_num_order.dat)
    i=`expr $i + 1`

done

#app wo jikanjun ni naraberu

i=1
echo -n > ./log/app_time_order.dat
while [ $i -le $appnum ] 
do
    awk -v meta=${app[$i]} '{
        if($3 == meta){
            printf("%s %s\n",$3,$1);
            exit;
         }
    }' ./log/cwnd.dat >> ./log/app_time_order.dat
    i=`expr $i + 1`	
done

sort -k2g ./log/app_time_order.dat > ./log/app_sort.dat
mv ./log/app_sort.dat ./log/app_time_order.dat

awk -v app=${appnum} '{
    if(FNR <= app){
        print $1
    }
}' ./log/app_time_order.dat > ./log/app_exp.dat

i=1
while [ $i -le $appnum ] 
do
    app[$i]=$(awk -v n=${i} '{
        if(NR==n){
            print $1
        }    
    }' ./log/app_exp.dat)
    i=`expr $i + 1`

done

i=1
while [ $i -le $appnum ] 
do
    awk -v meta=${app[$i]} '{
        if(meta==$3){
            print $0
        }
    }' ./log/cwnd.dat > ./log/cwnd${i}.dat
    

    awk '{
        if($4 ~ "pi="){
            array[$5]++   
        }
        }END{
        for(i in array){
            printf("%s %d\n",i,array[i])
        }    
    }' ./log/cwnd${i}.dat > ./log/app${i}_subflow.dat

    sort -k2nr ./log/app${i}_subflow.dat > ./log/app${i}_subflow_sort.dat
    mv ./log/app${i}_subflow_sort.dat ./log/app${i}_subflow.dat

    i=`expr $i + 1`
done



i=1
j=1
while [ $i -le $appnum ] 
do
    j=1
    while [ $j -le $subflownum ]
    do
        subflowid=$(awk -v n=${j} '{
            if(NR==n){
                print $1
            }    
        }' ./log/app${i}_subflow.dat)

        awk -v subf=${subflowid} '{
            if(subf==$5){
                print $0
            }
        }' ./log/cwnd${i}.dat > ./log/cwnd${i}_subflow${j}.dat
        
        j=`expr $j + 1`

    done
    i=`expr $i + 1`
done
