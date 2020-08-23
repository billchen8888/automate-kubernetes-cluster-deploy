#!/bin/bash
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

cd /opt/k8s/work
git clone https://github.com/coredns/deployment.git
mv deployment coredns-deployment

cd /opt/k8s/work/coredns-deployment/kubernetes
./deploy.sh -i ${CLUSTER_DNS_SVC_IP} -d ${CLUSTER_DNS_DOMAIN} | kubectl apply -f -

kubectl get all -n kube-system -l k8s-app=kube-dns

cd /opt/k8s/work
cat > my-nginx.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      run: my-nginx
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
EOF
kubectl create -f my-nginx.yaml

kubectl expose deploy my-nginx

kubectl get services my-nginx -o wide

cd /opt/k8s/work
cat > dnsutils-ds.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: dnsutils-ds
  labels:
    app: dnsutils-ds
spec:
  type: NodePort
  selector:
    app: dnsutils-ds
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dnsutils-ds
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      app: dnsutils-ds
  template:
    metadata:
      labels:
        app: dnsutils-ds
    spec:
      containers:
      - name: my-dnsutils
        image: tutum/dnsutils:latest
        command:
          - sleep
          - "3600"
        ports:
        - containerPort: 80
EOF
kubectl create -f dnsutils-ds.yml

echo "waiting 20 seconds for container to be ready..."
sleep 20 # wait the container to come ready

kubectl get pods -lapp=dnsutils-ds -o wide

pick1dns=`kubectl get pods -lapp=dnsutils-ds -o wide |grep Running|awk '{print $1}'|head -1`
if [ "x$pick1dns" = "x" ]; then
  echo "Somehow I don't see the dnsutils-ds pods yet, so I cannot test the dns function" 
else
  kubectl -it exec $pick1dns cat /etc/resolv.conf
  kubectl -it exec $pick1dns nslookup kubernetes
  kubectl -it exec $pick1dns nslookup my-nginx
  kubectl -it exec $pick1dns nslookup www.cnn.com
fi
