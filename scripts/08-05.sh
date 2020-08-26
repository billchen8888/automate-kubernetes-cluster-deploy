#!/bin/bash

echo "=== step 08-05 started ==="
source ../USERDATA
export PATH=$PATH:/opt/k8s/bin

cd /opt/k8s/work/kubernetes/
tar -xzvf kubernetes-src.tar.gz

cd /opt/k8s/work/kubernetes/cluster/addons/fluentd-elasticsearch
#sed -i -e 's_quay.io_quay.azk8s.cn_' es-statefulset.yaml # 使用微软的 Registry
#sed -i -e 's_quay.io_quay.azk8s.cn_' fluentd-es-ds.yaml # 使用微软的 Registry
# do we really need to use quay.azk8s.cn registry?

cd /opt/k8s/work/kubernetes/cluster/addons/fluentd-elasticsearch
kubectl apply -f .

echo "=== sleep 10 seconds"
sleep 10
kubectl get all -n kube-system |grep -E 'elasticsearch|fluentd|kibana'
# how to set the IP: 
ssh ${WORKER_IPS[0]} "kubectl proxy --address=${WORKER_IPS[0]} --port=8086 --accept-hosts='^*$' " &
# can we set it on a machine outside of the k8s cluster?
sleep 4  # enforce the output order as the background thing
echo "=== step 08-05 last line reached ==="
