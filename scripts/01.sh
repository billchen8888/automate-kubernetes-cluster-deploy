#!/bin/bash

source ../USERDATA
source /opt/k8s/work/iphostinfo

mkdir -p /opt/k8s/{bin,work} /etc/{kubernetes,etcd}/cert
################################

cat << EOF > /opt/k8s/bin/initial_host_config.sh
`for K in ${!iphostmap[@]}
do
  echo "echo $K  ${iphostmap[$K]} >> /etc/hosts"
done`
#hostnamectl set-hostname iphostmap[$ip]  # it will not work as this is a general script
echo "PATH=/opt/k8s/bin:\$PATH" >> /root/.bashrc    # >> is literbally, not redirect
yum -y update
yum -y install epel-release 
# we cannot put jq in the same line as epel-release as jq is from epel-release repo
yum -y install chrony conntrack ipvsadm ipset jq iptables curl sysstat libseccomp wget socat git
mkdir -p /opt/k8s/{bin,work} /etc/{kubernetes,etcd}/cert
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
echo br_netfilter >  /etc/modules-load.d/kubernetes.conf
echo nf_conntrack >> /etc/modules-load.d/kubernetes.conf

echo net.bridge.bridge-nf-call-iptables=1 > /etc/sysctl.d/kubernetes.conf
echo net.bridge.bridge-nf-call-ip6tables=1 >> /etc/sysctl.d/kubernetes.conf
echo net.ipv4.ip_forward=1 >> /etc/sysctl.d/kubernetes.conf
echo net.ipv4.tcp_tw_recycle=0 >> /etc/sysctl.d/kubernetes.conf
echo net.ipv4.neigh.default.gc_thresh1=1024 >> /etc/sysctl.d/kubernetes.conf
echo net.ipv4.neigh.default.gc_thresh2=2048 >> /etc/sysctl.d/kubernetes.conf
echo net.ipv4.neigh.default.gc_thresh3=4096 >> /etc/sysctl.d/kubernetes.conf
echo vm.swappiness=0 >> /etc/sysctl.d/kubernetes.conf
echo vm.overcommit_memory=1 >> /etc/sysctl.d/kubernetes.conf
echo vm.panic_on_oom=0 >> /etc/sysctl.d/kubernetes.conf
echo fs.inotify.max_user_instances=8192 >> /etc/sysctl.d/kubernetes.conf
echo fs.inotify.max_user_watches=1048576 >> /etc/sysctl.d/kubernetes.conf
echo fs.file-max=52706963 >> /etc/sysctl.d/kubernetes.conf
echo fs.nr_open=52706963 >> /etc/sysctl.d/kubernetes.conf
echo net.ipv6.conf.all.disable_ipv6=1 >> /etc/sysctl.d/kubernetes.conf
echo net.netfilter.nf_conntrack_max=2310720 >> /etc/sysctl.d/kubernetes.conf

# no need to do the following as centos 7 EC2 doesn't load firewalld
#systemctl stop firewalld
#systemctl disable firewalld
#iptables -F && iptables -X && iptables -F -t nat && iptables -X -t na t
#iptables -P FORWARD ACCEPT
timedatectl set-timezone America/New_York
rpm -Uvh http://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
# 安装完成后检查 /boot/grub2/grub.cfg 中对应内核 menuentry 中是否包含 initrd16 配置，如果没有，再安装一次！
yum --enablerepo=elrepo-kernel install -y kernel-lt
# 设置开机从新内核启动
grub2-set-default 0
sync
# init 6   # take it out as the reboot can cause the scp environent.sh fail as the instance are not up yet
EOF

for ip in  ${!iphostmap[@]}
do
  scp /opt/k8s/bin/initial_host_config.sh root@${ip}:/root/
  #ssh root@${ip} "chmod +x /root/initial_host_config.sh; hostnamectl set-hostname ${iphostmap[$ip]}; /root/initial_host_config.sh"

  ## put in foreground then we can see the error. We can put in background using command below, but then we need to check the log
  ## if we do run the inital_host_config.sh on background, then we sleep enough time here before we restart the remotes hosts
  # sleep 600
  #ssh root@${ip} "chmod +x /root/initial_host_config.sh; hostnamectl set-hostname ${iphostmap[$ip]}; /root/initial_host_config.sh > /tmp/initial_host_config.log 2>&1 &"
  
  # now we find a good sl=olution. the way be,ow will still send the output to the screen
  ssh root@${ip} "chmod +x /root/initial_host_config.sh; hostnamectl set-hostname ${iphostmap[$ip]}; /root/initial_host_config.sh" &
  # we put in background only want to save time... note te & is outside the quote!

done

################################

cat << EOF  > /opt/k8s/bin/environment.sh
#!/usr/bin/bash

# 生成 EncryptionConfig 所需的加密 key
export ENCRYPTION_KEY=\$(head -c 32 /dev/urandom | base64)

# 集群各机器 IP 数组
# we get these from USERDATA

# 集群各 IP 对应的主机名数组
# we get these from USERDATA
#
# etcd 集群服务地址列表
#export ETCD_ENDPOINTS="https://$host1_ip:2379,https://$host2_ip:2379,https://$host3_ip:2379" # this works. but need to be dynamic for more nodes
#export ETCD_ENDPOINTS="`i=0;for ip in $NODE_IPS;do if [ $i = 0 ]; then url=https://${ip}:2379;else url=${url},https://${ip}:2379;fi;i=$(($i+1)); done;echo $url`"
#export ETCD_ENDPOINTS="`i=0;for ip in ${NODE_IPS[@]};do if [ $i = 0 ]; then url=https://${ip}:2379;else url=${url},https://${ip}:2379;fi;i=$(($i+1)); done;echo $url`"
#the above two do NOT work!!
export ETCD_ENDPOINTS="`i=0;for ip in ${MASTER_IPS[@]};do if [ $i = 0 ]; then url=https://${ip}:2379;else url=${url},https://${ip}:2379;fi;i=$(($i+1)); done;echo $url`"

# etcd 集群间通信的 IP 和端口
#export ETCD_NODES="$host1=https://$host1_ip:2380,$host2=https://$host2_ip:2380,$host3=https://$host3_ip:2380"
export ETCD_NODES="`i=0;for ip in ${MASTER_IPS[@]};do if [ $i = 0 ]; then url=${MASTER_HOSTS[$i]}=https://${ip}:2380;else url=${url},${MASTER_HOSTS[$i]}=https://${ip}:2380;fi;i=$(($i+1)); done;echo $url`"

# kube-apiserver 的反向代理(kube-nginx)地址端口
export KUBE_APISERVER="https://127.0.0.1:8443"

# 节点间互联网络接口名称
export IFACE="eth0"

# etcd 数据目录
export ETCD_DATA_DIR="/data/k8s/etcd/data"

# etcd WAL 目录，建议是 SSD 磁盘分区，或者和 ETCD_DATA_DIR 不同的磁盘分区
export ETCD_WAL_DIR="/data/k8s/etcd/wal"

# k8s 各组件数据目录
export K8S_DIR="/data/k8s/k8s"

## DOCKER_DIR 和 CONTAINERD_DIR 二选一
# docker 数据目录
export DOCKER_DIR="/data/k8s/docker"

# containerd 数据目录
export CONTAINERD_DIR="/data/k8s/containerd"

## 以下参数一般不需要修改

# TLS Bootstrapping 使用的 Token，可以使用命令 head -c 16 /dev/urandom | od -An -t x | tr -d ' ' 生成
BOOTSTRAP_TOKEN="41f7e4ba8b7be874fcff18bf5cf41a7c"

# 最好使用 当前未用的网段 来定义服务网段和 Pod 网段

# 服务网段，部署前路由不可达，部署后集群内路由可达(kube-proxy 保证)
SERVICE_CIDR="10.254.0.0/16"

# Pod 网段，建议 /16 段地址，部署前路由不可达，部署后集群内路由可达(flanneld 保证)
CLUSTER_CIDR="172.30.0.0/16"

# 服务端口范围 (NodePort Range)
export NODE_PORT_RANGE="30000-32767"

# kubernetes 服务 IP (一般是 SERVICE_CIDR 中第一个IP)
export CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"

# 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配)
export CLUSTER_DNS_SVC_IP="10.254.0.2"

# 集群 DNS 域名（末尾不带点号）
export CLUSTER_DNS_DOMAIN="cluster.local"

# 将二进制目录 /opt/k8s/bin 加到 PATH 中
export PATH=/opt/k8s/bin:\$PATH
EOF

#source /opt/k8s/bin/environment.sh # 先修改
#I changed the logic. I don't put the IPs and hosts in the environment.sh any more
for ip in ${!iphostmap[@]}    # cross-board
  do
    echo ">>> ${ip}"
    ssh root@${ip} "mkdir -p /opt/k8s/bin/"
    # in case the initial_host_config has not created this folder yet, do we really need this file on the nother nodes ?
    scp /opt/k8s/bin/environment.sh root@${ip}:/opt/k8s/bin/
  done

#sleep 1200 # need to wait enough time
# now we reboot the nodes
#for node_ip in ${NODE_IPS[@]}
#  do
#    ssh root@${node_ip} "init 6"
#  done

# do it on this localhost - in the case we run on a instance not in the k8s nodes
chmod +x /opt/k8s/bin/*
yum -y install epel-release
yum install -y wget git jq  # we need the package on this machine
# jq is needed in this central box. in 08-02.sh, the downloaded deploy.sh inside the  coredns-deployment uses jq command
# the following is optopnal -  good to have on the central box: as we will compile nginx and copy the binary to the nodes. maybe good to keep everythng match.
# yum update -y

for K in ${!iphostmap[@]}
do
  echo $K  ${iphostmap[$K]} >> /etc/hosts
done

echo "We submitted the yum update job at all servers at same time, and it can take quite some time to finish"
echo "checking whether the initialization finished on the remote notes, then reboot them  ......."
sleep 30
while [ true ]
do
  isitdone=0
  for ip in ${!iphostmap[@]}    # this is cross-board
  do
    eachbox=`ssh root@${ip} "ps -ef |grep initial_host_config|grep -v grep|wc -l"`
    isitdone=$(($isitdone+$eachbox))
  done
  if [ $isitdone != 0 ]; then
    echo "sleep 30 seconds and wait the yum on the remote ndoes to be done"
    sleep 30
  else
    break
  fi
done

for ip in ${!iphostmap[@]}
do
  echo "rebooting $ip..."
  ssh $ip "init 6"
done

# I put sleep here to let the nodes come up.
# in case we manually run the individual scripts too fast.
echo "sleeping to wait the node are rebooted...."

# next verify the nodes are up and the hostname is set. The command also add the known host in case they are referred later on
while [ true ]
do
    allup=0
    for host in  ${iphostmap[@]}   # cross the board
    do
        echo ================= checking $host ================
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $host hostname
        if [ $? != 0 ];then
            allup=$(($allup+1))
        fi
    done
    if [ $allup -gt 0 ]; then
        echo "sleep 30 seconds, waiting server coming up after reboot..."
        sleep 30
    else
        break
    fi
done 

echo "======= step 01 is completed ===="
