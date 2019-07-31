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
    if [ ! -e "$1/default.conf" ]; then
        echo -e "\n not found default.conf"
        echo -e $message
        exit
    else
        source $1/default.conf
        
        rootdir=$1
        rootdir=$(echo ${rootdir%/})
        cd $rootdir
    fi
else
    echo -e $message
    exit
fi

echo "Please select you want to do."
select VAR in "Change graph range" "Build tex" "exit"
do
    if [ "$VAR" = "Change graph range" ];then
        change_graph_xrange
        break
    elif [ "$VAR" = "Build tex" ];then
        build_tex_to_pdf 
        break
    elif [ "$VAR" = "exit" ];then
        exit
    else
        echo ""
    fi
done

exit
