
## this seems not needed as it is already done in 01.sh
#source /opt/k8s/bin/environment.sh
#for node_ip in ${NODE_IPS[@]}
  #do
    #echo ">>> ${node_ip}"
    #ssh root@${node_ip} "yum install -y epel-release" &
    #ssh root@${node_ip} "yum install -y chrony conntrack ipvsadm ipset jq iptables curl sysstat libseccomp wget socat git" &
  #done
