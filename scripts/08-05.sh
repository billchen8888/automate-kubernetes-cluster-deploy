#!/bin/bash

cd /opt/k8s/work/kubernetes/
tar -xzvf kubernetes-src.tar.gz

cd /opt/k8s/work/kubernetes/cluster/addons/fluentd-elasticsearch
sed -i -e 's_quay.io_quay.azk8s.cn_' es-statefulset.yaml # 使用微软的 Registry
sed -i -e 's_quay.io_quay.azk8s.cn_' fluentd-es-ds.yaml # 使用微软的 Registry

cd /opt/k8s/work/kubernetes/cluster/addons/fluentd-elasticsearch
kubectl apply -f .

kubectl get all -n kube-system |grep -E 'elasticsearch|fluentd|kibana'
kubectl proxy --address='172.27.138.251' --port=8086 --accept-hosts='^*$'

