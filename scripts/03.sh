#!/bin/bash
source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

######## 03 kubectl ####
cd /opt/k8s/work
wget -nv https://dl.k8s.io/v1.16.6/kubernetes-client-linux-amd64.tar.gz # 自行解决翻墙下载问题
tar -xzvf kubernetes-client-linux-amd64.tar.gz

# as I am on a seperate box, where I need to use kubectl to generate configuration file
cp /opt/k8s/work/kubernetes/client/bin/kubectl /opt/k8s/bin/
chmod +x /opt/k8s/bin/*

cd /opt/k8s/work
for ip in ${!iphostmap[@]}    # it doesn't hurt to have kubectl everywhere
  do
    echo ">>> ${ip}"
    scp kubernetes/client/bin/kubectl root@${ip}:/opt/k8s/bin/
    ssh root@${ip} "chmod +x /opt/k8s/bin/*"
  done

#### admin cert ####
cd /opt/k8s/work
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "ST": "MD",
      "L": "Rockville",
      "O": "system:masters",
      "OU": "opsnull"
    }
  ]
}
EOF

cd /opt/k8s/work
cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes admin-csr.json | cfssljson -bare admin

cd /opt/k8s/work

# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/work/ca.pem \
  --embed-certs=true \
  --server=https://${MASTER_IPS[0]}:6443 \
  --kubeconfig=kubectl.kubeconfig
# question:  why we use MASTER_IPS[0]  ???  - it is mentioned in Zhangjun's doc

# 设置客户端认证参数
kubectl config set-credentials admin \
  --client-certificate=/opt/k8s/work/admin.pem \
  --client-key=/opt/k8s/work/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=kubectl.kubeconfig

# 设置上下文参数
kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=kubectl.kubeconfig

# 设置默认上下文
kubectl config use-context kubernetes --kubeconfig=kubectl.kubeconfig

cd /opt/k8s/work
for ip in ${!iphostmap[@]}    # it doesn't hurt if we have it everywhere
  do
    echo ">>> ${ip}"
    ssh root@${ip} "mkdir -p ~/.kube"
    scp kubectl.kubeconfig root@${ip}:~/.kube/config
  done


# optional: copy the kubeconfig file to this central box so it can talk to the k8s cluster
mkdir -p ~/.kube
cp kubectl.kubeconfig ~/.kube/config
