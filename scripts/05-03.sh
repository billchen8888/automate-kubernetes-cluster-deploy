#!/bin/bash
source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

##### 05-3. 部署高可用 kube-controller-manager
cd /opt/k8s/work
cat > kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
`hashsize=${#MASTER_IPS[@]}
     i=1
     for ip in ${MASTER_IPS[@]}
     do
       if [ $i -eq $hashsize ]; then
         echo "      \"$ip\""
       else
         echo "      \"$ip\","
       fi
     i=$(($i+1))
     done`
    ],
    "names": [
      {
        "C": "US",
        "ST": "MD",
        "L": "Rockville",
        "O": "system:kube-controller-manager",
        "OU": "opsnull"
      }
    ]
}
EOF

cd /opt/k8s/work
cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp kube-controller-manager*.pem root@${master_ip}:/etc/kubernetes/cert/
  done

cd /opt/k8s/work
kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/work/ca.pem \
  --embed-certs=true \
  --server="https://##MASTER_IP##:6443" \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context system:kube-controller-manager \
  --cluster=kubernetes \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    sed -e "s/##MASTER_IP##/${master_ip}/" kube-controller-manager.kubeconfig > kube-controller-manager-${master_ip}.kubeconfig
    scp kube-controller-manager-${master_ip}.kubeconfig root@${master_ip}:/etc/kubernetes/kube-controller-manager.kubeconfig
  done

cd /opt/k8s/work
cat > kube-controller-manager.service.template <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=${K8S_DIR}/kube-controller-manager
ExecStart=/opt/k8s/bin/kube-controller-manager \\
  --profiling \\
  --cluster-name=kubernetes \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kube-api-qps=1000 \\
  --kube-api-burst=2000 \\
  --leader-elect \\
  --use-service-account-credentials\\
  --concurrent-service-syncs=2 \\
  --bind-address=##MASTER_IP## \\
  --secure-port=10252 \\
  --tls-cert-file=/etc/kubernetes/cert/kube-controller-manager.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kube-controller-manager-key.pem \\
  --port=0 \\
  --authentication-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-allowed-names="aggregator" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --authorization-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --cluster-signing-cert-file=/etc/kubernetes/cert/ca.pem \\
  --cluster-signing-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --experimental-cluster-signing-duration=876000h \\
  --horizontal-pod-autoscaler-sync-period=10s \\
  --concurrent-deployment-syncs=10 \\
  --concurrent-gc-syncs=30 \\
  --node-cidr-mask-size=24 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --pod-eviction-timeout=6m \\
  --terminated-pod-gc-threshold=10000 \\
  --root-ca-file=/etc/kubernetes/cert/ca.pem \\
  --service-account-private-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cd /opt/k8s/work
for((i=0; i<${#MASTER_IPS[@]}; i++))
  do
    sed -e "s/##MASTER_NAME##/${MASTER_HOSTS[$i]}/" -e "s/##MASTER_IP##/${MASTER_IPS[$i]}/" kube-controller-manager.service.template > kube-controller-manager-${MASTER_IPS[$i]}.service 
  done


cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp kube-controller-manager-${master_ip}.service root@${master_ip}:/etc/systemd/system/kube-controller-manager.service
  done

for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    ssh root@${master_ip} "mkdir -p ${K8S_DIR}/kube-controller-manager"
    ssh root@${master_ip} "systemctl daemon-reload && systemctl enable kube-controller-manager && systemctl restart kube-controller-manager"
  done
