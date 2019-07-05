#!/bin/bash

# EXPERIMENT SETTING

author="Izumi Daichi"
cgn_ctrl=(lia)          # congestion control e.g. lia olia balia wvegas cubic reno
rtt1=(50)               # delay of netem [ms]
rtt2=(50)               
loss=(0)                # Packet drop rate of netem [%]
queue=(100 1000)        # The number of IFQ size [packet]
duration=1              # Communication Time [s]
app_delay=0.5           # Time of start time difference [s]
repeat=1                # The number of repeat
app=3                   # The number of Application (iperf)
subflownum=2            # The number of Subflow (path)
band1=100               # bandwidth of eth1
band2=100
qdisc=pfifo_fast        # AQM (Active queue management) e.g. pfifo_fast red fq_codel
memo=$1

item_to_create_graph=(cwnd packetsout)

#reciver setting
receiver_dir="/home/yokolabo/experiment"

# DEFAULT KERNEL PARAMETER SETTING

mptcp_enabled=1
mptcp_debug=1

# USER ADDED KERNEL PARAMETER SETTING
# If you added kernel parameter, please describe below. 

kariya_small_queue=0    # 0:default 1:original fixed limit of TSQ

# USER KERNEL PARAMETER FUNCTION
function set_user_kernel_parameter {
    sysctl net.mptcp.kariya_small_queue=${kariya_small_queue}
}
