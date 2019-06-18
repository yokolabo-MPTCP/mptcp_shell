#!/bin/bash

#limit=(8192 16384 32768 65536 131072 262144)
limit=(0 1 2 3 4)
k=0

while [ $k -lt ${#limit[@]} ]
do

	./2018redmain_tsq.sh limit=${limit[$k]} ${limit[$k]}

k=`expr $k + 1`
done

