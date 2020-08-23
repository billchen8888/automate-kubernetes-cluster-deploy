#!/bin/bash

# kube-proxy  is on worker node

source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

cd /opt/k8s/work
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "opsnull"
    }
  ]
}
EOF

cd /opt/k8s/work
cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
ls kube-proxy*

cd /opt/k8s/work
kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/work/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

cd /opt/k8s/work
for worker_name in ${WORKER_HOSTS[@]}
  do
    echo ">>> ${worker_name}"
    scp kube-proxy.kubeconfig root@${worker_name}:/etc/kubernetes/
  done

cd /opt/k8s/work
cat > kube-proxy-config.yaml.template <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-proxy.kubeconfig"
  qps: 100
bindAddress: ##WORKER_IP##
healthzBindAddress: ##WORKER_IP##:10256
metricsBindAddress: ##WORKER_IP##:10249
enableProfiling: true
clusterCIDR: ${CLUSTER_CIDR}
hostnameOverride: ##WORKER_NAME##
mode: "ipvs"
portRange: ""
iptables:
  masqueradeAll: false
ipvs:
  scheduler: rr
  excludeCIDRs: []
EOF

cd /opt/k8s/work
#for (( i=0; i < ${#WORKER_HOSTS[@]}; i++ ))  # I don't know two hash arrays have the same order or not, so we need to avoid 
#for ip in ${!iphostmap[@]}
for (( i=0; i < ${#WORKER_IPS[@]}; i++ ))
  do 
    echo ">>> ${WORKER_IPS[$i]}"
    sed -e "s/##WORKER_NAME##/${WORKER_HOSTS[$i]}/" -e "s/##WORKER_IP##/${WORKER_IPS[$i]}/" kube-proxy-config.yaml.template > kube-proxy-config-${WORKER_HOSTS[$i]}.yaml.template
    scp kube-proxy-config-${WORKER_HOSTS[$i]}.yaml.template root@${WORKER_HOSTS[$i]}:/etc/kubernetes/kube-proxy-config.yaml
  done

cd /opt/k8s/work
cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=${K8S_DIR}/kube-proxy
ExecStart=/opt/k8s/bin/kube-proxy \\
  --config=/etc/kubernetes/kube-proxy-config.yaml \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cd /opt/k8s/work
for worker_name in ${WORKER_HOSTS[@]}
  do 
    echo ">>> ${worker_name}"
    scp kube-proxy.service root@${worker_name}:/etc/systemd/system/
  done

cd /opt/k8s/work
for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    ssh root@${worker_ip} "mkdir -p ${K8S_DIR}/kube-proxy"
    ssh root@${worker_ip} "modprobe ip_vs_rr"
    ssh root@${worker_ip} "systemctl daemon-reload && systemctl enable kube-proxy && systemctl restart kube-proxy"
  done
