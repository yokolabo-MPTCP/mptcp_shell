#!/bin/bash

# EXPERIMENT SETTING

author="Izumi Daichi"
cgn_ctrl=(lia olia wvegas)          # congestion control e.g. lia olia balia wvegas cubic reno
rtt1=(5 50 200)               # delay of netem [ms]
rtt2=(5 50 200)               
loss=(0 0.001)                # Packet drop rate of netem [%]
queue=(100 1000 20000)        # The number of IFQ size [packet]
duration=100              # Communication Time [s]
app_delay=0.5           # Time of start time difference [s]
repeat=1                # The number of repeat
app=3                   # The number of Application (iperf)
subflownum=2            # The number of Subflow (path)
band1=100               # bandwidth of eth1
band2=100
qdisc=pfifo_fast        # AQM (Active queue management) e.g. pfifo_fast red fq_codel
memo=$1

item_to_create_graph=(cwnd packetsout pacingrate shiftpacing limit wmemalloc)

#reciver setting
receiver_dir="/home/yokolabo/experiment"

# DEFAULT KERNEL PARAMETER SETTING

mptcp_enabled=1
mptcp_debug=1

tcp_limit_output_bytes=262144   # default:262144
tcp_pacing_ca_ratio=120         # default:120
tcp_pacing_ss_ratio=200         # default:200

# USER ADDED KERNEL PARAMETER SETTING
# If you added kernel parameter, please describe below. 

mptcp_kariya_small_queue=0    # 0:default 1: fixed limit of TSQ
mptcp_izumi_pacing_rate=1     # 0:default 1: packetsout only of calculation of pacingrate

# USER KERNEL PARAMETER FUNCTION
function set_user_kernel_parameter {
    sysctl net.mptcp.mptcp_kariya_small_queue=${mptcp_kariya_small_queue}
    sysctl net.mptcp.mptcp_izumi_pacing_rate=${mptcp_izumi_pacing_rate}
}
