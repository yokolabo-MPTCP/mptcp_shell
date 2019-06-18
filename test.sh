#!/bin/bash
queue=(10 100 500 1000) 
k=1
queue[1]=$1
limitsize=$(( 130 * queue[$k]))
max=$((2 * queue[$k]))
					halfsize=$((limitsize / 2)) #this command is invalid.
					burst=$((halfsize / 100 + 1)) 
echo $limitsize
echo $halfsize
echo $burst

tc qdisc replace dev eth0 root red limit $limitsize min $halfsize max $max avpkt 1000 burst $burst adaptive probability 0.02 bandwidth 100Mbps ecn harddrop
					tc qdisc replace dev eth1 root red limit $limitsize min $halfsize max $max avpkt 1000 burst $burst adaptive probability 0.02 bandwidth 100Mbps ecn harddrop

#./main.sh
#./redmain.sh

