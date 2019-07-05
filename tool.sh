#!/bin/bash
umask 000
clear

cwd=`dirname $0`
cd $cwd
if [ -e "function.sh" ]; then
    source "function.sh"
else
    echo "function.sh does not exist."
    exit
fi

message="usage: $0 [path of directory]"

if [ $# = 0 ]; then
    echo -e $message
    exit
elif [ $# = 1 ]; then
    if [ ! -e "$1/config.sh" ]; then
        echo -e "\n not found config.sh"
        echo -e $message
        exit
    else
        source $1/config.sh
        
        today=$1
        cd $today
    fi
else
    echo -e $message
    exit
fi

select VAR in "Change graph range" "exit"
do
    if [ "$VAR" = "Change graph range" ];then
        change_graph_xrange
        break
    elif [ "$VAR" = "exit" ];then
        exit
    else
        echo ""
    fi
done

exit
