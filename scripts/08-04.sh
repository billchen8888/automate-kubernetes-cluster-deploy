#!/bin/bash

echo "=== step 08-04 started now ==="
source ../USERDATA
export PATH=$PATH:/opt/k8s/bin
# source /opt/k8s/bin/environment.sh  # I don't think this is required though

cd /opt/k8s/work
git clone https://github.com/coreos/kube-prometheus.git
cd kube-prometheus/
###sed -i -e 's_quay.io_quay.azk8s.cn_' manifests/*.yaml manifests/setup/*.yaml # 使用微软的 Registry
# do we really need to use azure registry??

echo "=== doing kubectl apply -f manifests/setup"
kubectl apply -f manifests/setup # 安装 prometheus-operator

echo "wait 20 seconds for previous resource types to be ready"
sleep 20
echo "=== doing kubectl apply -f manifests/ "
kubectl apply -f manifests/ # 安装 promethes metric adapter

echo waiting 30 seconds for pods to be ready
sleep 30
echo "=== kubectl get pods -n monitoring"
kubectl get pods -n monitoring

while  [ true ]
do
   # port-forwarding to a single pod??
   pod1st=`kubectl get pods -n monitoring |grep prometheus-k8s|head -1|awk '{print $1}'`
   if [ "$pod1st" = "" ]; then
      echo "waiting for prometheus metric to be ready...sleep 30 seconds..."
      sleep 30
   else
      break
   fi
done

echo "=== kubectl top pods -n monitoring"
kubectl top pods -n monitoring

# shall we put the next two command in background? As they stay in foreground.
# Shall we create service?
ssh ${WORKER_HOSTS[0]} "kubectl port-forward --address 0.0.0.0 pod/prometheus-k8s-0 -n monitoring 9090:9090" &
ssh ${WORKER_HOSTS[0]} "kubectl port-forward --address 0.0.0.0 svc/grafana -n monitoring 3000:3000" &
# run it in thr 1st worker node, in stead of the central box we run script.
# We can set these two port-forwarding on the box outside the k8s. It works as I tested

sleep 4  # the tee command in the wrapper script cause the session on hold and on-screen order is messey. So force a few seconds sleep
echo "=== step 08-04 last line reached ==="
