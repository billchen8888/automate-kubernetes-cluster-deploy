#!/bin/bash
source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

###### 05-01 master deployment ####

cd /opt/k8s/work
wget -nv https://dl.k8s.io/v1.16.6/kubernetes-server-linux-amd64.tar.gz  # 自行解决翻墙问题
tar -xzvf kubernetes-server-linux-amd64.tar.gz
cd kubernetes
tar -xzvf  kubernetes-src.tar.gz

cd /opt/k8s/work
# if the master and nodes are different, then we don't need to cp controller, apiserve to worker hosts
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp kubernetes/server/bin/{apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-proxy,kube-scheduler,kubeadm,kubectl,kubelet,mounter} root@${master_ip}:/opt/k8s/bin/
    ssh root@${master_ip} "chmod +x /opt/k8s/bin/*"
  done

if [ $MASTER_WORKER_SEPERATED == true ]; then
  # they are seperated. the worker nodes don't need k8s servers
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    scp kubernetes/server/bin/{kube-proxy,kubeadm,kubectl,kubelet}  root@${worker_ip}:/opt/k8s/bin/
    ssh root@${worker_ip} "chmod +x /opt/k8s/bin/*"
  done
fi


# we need to use kubeadm command in 06-04.sh to create token
scp kubernetes/server/bin/{apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-proxy,kube-scheduler,kubeadm,kubectl,kubelet,mounter} /opt/k8s/bin/
chmod +x /opt/k8s/bin/*
