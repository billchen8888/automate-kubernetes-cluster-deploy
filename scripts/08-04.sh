#!/bin/bash

export PATH=$PATH:/opt/k8s/bin

cd /opt/k8s/work
git clone https://github.com/coreos/kube-prometheus.git
cd kube-prometheus/
###sed -i -e 's_quay.io_quay.azk8s.cn_' manifests/*.yaml manifests/setup/*.yaml # 使用微软的 Registry
# do we really need to use azure registry??

kubectl apply -f manifests/setup # 安装 prometheus-operator
kubectl apply -f manifests/ # 安装 promethes metric adapter

echo waiting 30 seconds for pods to be ready
sleep 30
kubectl get pods -n monitoring
kubectl top pods -n monitoring

# port-forwarding to a single pod??
pod1st=`kubectl get pods -n monitoring |grep prometheus-k8s|head -1|awk '{print $1}'`

# shall we put the next two command in background? As they stay in foreground.
# Shall we create service?
kubectl port-forward --address 0.0.0.0 pod/$pod1st -n monitoring 9090:9090 &
kubectl port-forward --address 0.0.0.0 svc/grafana -n monitoring 3000:3000 &
