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
    if [ ! -e "$1/setting.txt" ]; then
        echo -e "\n not found setting.txt"
        echo -e $message
        exit
    else
        setting="setting.txt"
        today=$1
        cd $today
    fi
else
    echo -e $message
    exit
fi

cgn_ctrl=($(awk '{if($1~"conguestion_control"){$1="";print;exit;}}' $setting))
rtt1=($(awk '{if($1~"rtt1"){$1="";print;exit;}}' $setting))
rtt2=($(awk '{if($1~"rtt2"){$1="";print;exit;}}' $setting))
loss=($(awk '{if($1~"loss"){$1="";print;exit;}}' $setting))
queue=($(awk '{if($1~"queue"){$1="";print;exit;}}' $setting))
repeat=$(awk '{if($1~"repeat"){$1="";print $2;exit;}}' $setting)
duration=$(awk '{if($1~"duration"){$1="";print $2;exit;}}' $setting)
today=$(awk '{if($1~"Date"){$1="";print $2;exit;}}' $setting)
num_subflow=$(awk '{if($1~"num_subflow"){$1="";print $2;exit;}}' $setting)
app_delay=$(awk '{if($1~"app_delay"){$1="";print $2;exit;}}' $setting)
app=$(awk '{if($1~"app"){$1="";print $2;exit;}}' $setting)
kernel=$(awk '{if($1~"sender_kernel"){$1="";print $2;exit;}}' $setting)
rcvkernel=$(awk '{if($1~"reciever_kernel"){$1="";print $2;exit;}}' $setting)
mptcp_ver=$(awk '{if($1~"mptcp_ver"){$1="";print $2;exit;}}' $setting)
qdisc=$(awk '{if($1~"qdisc"){$1="";print $2;exit;}}' $setting)
interval=$(awk '{if($1~"interval"){$1="";print $2;exit;}}' $setting)
memo=$(awk '{if($1~"memo"){$1="";print $2;exit;}}' $setting)

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
