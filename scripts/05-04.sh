#!/bin/bash
source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

#### 05-04  deploy scheduler ####
cd /opt/k8s/work
cat > kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
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
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
      {
        "C": "US",
        "ST": "MD",
        "L": "Rockville",
        "O": "system:kube-scheduler",
        "OU": "opsnull"
      }
    ]
}
EOF

cd /opt/k8s/work
cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}    # need to check whether this one is needed everywhere
  do
    echo ">>> ${master_ip}"
    scp kube-scheduler*.pem root@${master_ip}:/etc/kubernetes/cert/
  done

cd /opt/k8s/work
kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/work/ca.pem \
  --embed-certs=true \
  --server="https://##MASTER_IP##:6443" \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem \
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context system:kube-scheduler \
  --cluster=kubernetes \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    sed -e "s/##MASTER_IP##/${master_ip}/" kube-scheduler.kubeconfig > kube-scheduler-${master_ip}.kubeconfig
    scp kube-scheduler-${master_ip}.kubeconfig root@${master_ip}:/etc/kubernetes/kube-scheduler.kubeconfig
  done

cd /opt/k8s/work
cat >kube-scheduler.yaml.template <<EOF
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
bindTimeoutSeconds: 600
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-scheduler.kubeconfig"
  qps: 100
enableContentionProfiling: false
enableProfiling: true
hardPodAffinitySymmetricWeight: 1
healthzBindAddress: ##MASTER_IP##:10251
leaderElection:
  leaderElect: true
metricsBindAddress: ##MASTER_IP##:10251
EOF

cd /opt/k8s/work
#for ip in ${!iphostmap[@]}
for ((i=0; i<${#MASTER_IPS[@]}; i++))
  do
    sed -e "s/##MASTER_NAME##/${MASTER_HOSTS[$i]}/" -e "s/##MASTER_IP##/${MASTER_IPS[$i]}/" kube-scheduler.yaml.template > kube-scheduler-${MASTER_IPS[$i]}.yaml
  done

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp kube-scheduler-${master_ip}.yaml root@${master_ip}:/etc/kubernetes/kube-scheduler.yaml
  done

cd /opt/k8s/work
cat > kube-scheduler.service.template <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=${K8S_DIR}/kube-scheduler
ExecStart=/opt/k8s/bin/kube-scheduler \\
  --config=/etc/kubernetes/kube-scheduler.yaml \\
  --bind-address=##MASTER_IP## \\
  --secure-port=10259 \\
  --port=0 \\
  --tls-cert-file=/etc/kubernetes/cert/kube-scheduler.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kube-scheduler-key.pem \\
  --authentication-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-allowed-names="" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --authorization-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
  --logtostderr=true \\
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

cd /opt/k8s/work
#for ip in ${!iphostmap[@]}
for (( i=0; i < ${#MASTER_IPS[@]}; i++ ))
  do
    sed -e "s/##MASTER_NAME##/${MASTER_HOSTS[$i]}/" -e "s/##MASTER_IP##/${MASTER_IPS[$i]}/" kube-scheduler.service.template > kube-scheduler-${MASTER_IPS[$i]}.service
  done

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp kube-scheduler-${master_ip}.service root@${master_ip}:/etc/systemd/system/kube-scheduler.service
  done

for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    ssh root@${master_ip} "mkdir -p ${K8S_DIR}/kube-scheduler"
    ssh root@${master_ip} "systemctl daemon-reload && systemctl enable kube-scheduler && systemctl restart kube-scheduler"
  done

