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

check_exist_extended_parameter

echo "Please select you want to do."
select VAR in "Change graph x range" "Change graph y range" "Build tex" "decompression_and_reprocess_log_data" "exit"
do
    if [ "$VAR" = "Change graph x range" ];then
        change_graph_xrange
        break
    elif [ "$VAR" = "Change graph y range" ];then
        change_graph_yrange
    elif [ "$VAR" = "Build tex" ];then
        build_tex_to_pdf 
        break
    elif [ "$VAR" = "decompression_and_reprocess_log_data" ];then
        decompression_and_reprocess_log_data
        break
    elif [ "$VAR" = "exit" ];then
        exit
    else
        echo ""
    fi
done

exit
