#!/bin/bash

# kubelet is mainly for worker nodes, but we can run kubelet on master hosts
source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for host in ${iphostmap[@]}
  do
    echo ">>> ${host} - createing kubelet-related paramters and file"

    # 创建 token
    export BOOTSTRAP_TOKEN=$(kubeadm token create \
      --description kubelet-bootstrap-token \
      --groups system:bootstrappers:${host} \
      --kubeconfig ~/.kube/config)

    # 设置集群参数
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/cert/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER} \
      --kubeconfig=kubelet-bootstrap-${host}.kubeconfig

    # 设置客户端认证参数
    kubectl config set-credentials kubelet-bootstrap \
      --token=${BOOTSTRAP_TOKEN} \
      --kubeconfig=kubelet-bootstrap-${host}.kubeconfig

    # 设置上下文参数
    kubectl config set-context default \
      --cluster=kubernetes \
      --user=kubelet-bootstrap \
      --kubeconfig=kubelet-bootstrap-${host}.kubeconfig

    # 设置默认上下文
    kubectl config use-context default --kubeconfig=kubelet-bootstrap-${host}.kubeconfig
  done
else
  for worker_name in ${WORKER_HOSTS[@]}
  do
    echo ">>> ${worker_name} - createing kubelet-related paramters and file"

    # 创建 token
    export BOOTSTRAP_TOKEN=$(kubeadm token create \
      --description kubelet-bootstrap-token \
      --groups system:bootstrappers:${worker_name} \
      --kubeconfig ~/.kube/config)

    # 设置集群参数
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/cert/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER} \
      --kubeconfig=kubelet-bootstrap-${worker_name}.kubeconfig

    # 设置客户端认证参数
    kubectl config set-credentials kubelet-bootstrap \
      --token=${BOOTSTRAP_TOKEN} \
      --kubeconfig=kubelet-bootstrap-${worker_name}.kubeconfig

    # 设置上下文参数
    kubectl config set-context default \
      --cluster=kubernetes \
      --user=kubelet-bootstrap \
      --kubeconfig=kubelet-bootstrap-${worker_name}.kubeconfig

    # 设置默认上下文
    kubectl config use-context default --kubeconfig=kubelet-bootstrap-${worker_name}.kubeconfig
  done
fi

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for host in ${iphostmap[@]}
  do
    echo ">>> ${host} - scp kubelet-bootstrap.kubeconfig"
    scp kubelet-bootstrap-${host}.kubeconfig root@${host}:/etc/kubernetes/kubelet-bootstrap.kubeconfig
  done
else
  for worker_name in ${WORKER_HOSTS[@]}
  do
    echo ">>> ${worker_name} - scp kubelet-bootstrap.kubeconfig"
    scp kubelet-bootstrap-${worker_name}.kubeconfig root@${worker_name}:/etc/kubernetes/kubelet-bootstrap.kubeconfig
  done
fi

cd /opt/k8s/work
cat > kubelet-config.yaml.template <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: "##MACHINE_IP##"
staticPodPath: ""
syncFrequency: 1m
fileCheckFrequency: 20s
httpCheckFrequency: 20s
staticPodURL: ""
port: 10250
readOnlyPort: 0
rotateCertificates: true
serverTLSBootstrap: true
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/etc/kubernetes/cert/ca.pem"
authorization:
  mode: Webhook
registryPullQPS: 0
registryBurst: 20
eventRecordQPS: 0
eventBurst: 20
enableDebuggingHandlers: true
enableContentionProfiling: true
healthzPort: 10248
healthzBindAddress: "##MACHINE_IP##"
clusterDomain: "${CLUSTER_DNS_DOMAIN}"
clusterDNS:
  - "${CLUSTER_DNS_SVC_IP}"
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 1m
imageMinimumGCAge: 2m
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
volumeStatsAggPeriod: 1m
kubeletCgroups: ""
systemCgroups: ""
cgroupRoot: ""
cgroupsPerQOS: true
cgroupDriver: cgroupfs
runtimeRequestTimeout: 10m
hairpinMode: promiscuous-bridge
maxPods: 220
podCIDR: "${CLUSTER_CIDR}"
podPidsLimit: -1
resolvConf: /etc/resolv.conf
maxOpenFiles: 1000000
kubeAPIQPS: 1000
kubeAPIBurst: 2000
serializeImagePulls: false
evictionHard:
  memory.available:  "100Mi"
  nodefs.available:  "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft: {}
enableControllerAttachDetach: true
failSwapOn: true
containerLogMaxSize: 20Mi
containerLogMaxFiles: 10
systemReserved: {}
kubeReserved: {}
systemReservedCgroup: ""
kubeReservedCgroup: ""
enforceNodeAllocatable: ["pods"]
EOF

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} - scp kubelet-config.yaml"
    sed -e "s/##MACHINE_IP##/${machine_ip}/" kubelet-config.yaml.template > kubelet-config-${machine_ip}.yaml.template
    scp kubelet-config-${machine_ip}.yaml.template root@${machine_ip}:/etc/kubernetes/kubelet-config.yaml
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do 
    echo ">>> ${worker_ip} - scp kubelet-config.yaml"
    sed -e "s/##MACHINE_IP##/${worker_ip}/" kubelet-config.yaml.template > kubelet-config-${worker_ip}.yaml.template
    scp kubelet-config-${worker_ip}.yaml.template root@${worker_ip}:/etc/kubernetes/kubelet-config.yaml
  done
fi

cd /opt/k8s/work
cat > kubelet.service.template <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
WorkingDirectory=${K8S_DIR}/kubelet
ExecStart=/opt/k8s/bin/kubelet \\
  --bootstrap-kubeconfig=/etc/kubernetes/kubelet-bootstrap.kubeconfig \\
  --cert-dir=/etc/kubernetes/cert \\
  --network-plugin=cni \\
  --cni-conf-dir=/etc/cni/net.d \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --root-dir=${K8S_DIR}/kubelet \\
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
  --config=/etc/kubernetes/kubelet-config.yaml \\
  --hostname-override=##MACHINE_NAME## \\
  --image-pull-progress-deadline=15m \\
  --volume-plugin-dir=${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/ \\
  --logtostderr=true \\
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_name in ${iphostmap[@]}
  do
    echo ">>> ${machine_name} - scp kubelet.service"
    sed -e "s/##MACHINE_NAME##/${machine_name}/" kubelet.service.template > kubelet-${machine_name}.service
    scp kubelet-${machine_name}.service root@${machine_name}:/etc/systemd/system/kubelet.service
  done
else
  for worker_name in ${WORKER_HOSTS[@]}
  do 
    echo ">>> ${worker_name} - scp kubelet.service"
    sed -e "s/##MACHINE_NAME##/${worker_name}/" kubelet.service.template > kubelet-${worker_name}.service
    scp kubelet-${worker_name}.service root@${worker_name}:/etc/systemd/system/kubelet.service
  done
fi

echo "creating  clusterrolebinding kube-apiserver:kubelet-apis"
kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes-master
echo "creating  clusterrolebinding kubelet-bootstrap"
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:bootstrappers
# what is the impact????

cd /opt/k8s/work
cat > csr-crb.yaml <<EOF
 # Approve all CSRs for the group "system:bootstrappers"
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: auto-approve-csrs-for-group
 subjects:
 - kind: Group
   name: system:bootstrappers
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
   apiGroup: rbac.authorization.k8s.io
---
 # To let a node of the group "system:nodes" renew its own credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-client-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
   apiGroup: rbac.authorization.k8s.io
---
# A ClusterRole which instructs the CSR approver to approve a node requesting a
# serving cert matching its client cert.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: approve-node-server-renewal-csr
rules:
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/selfnodeserver"]
  verbs: ["create"]
---
 # To let a node of the group "system:nodes" renew its own server credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-server-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: approve-node-server-renewal-csr
   apiGroup: rbac.authorization.k8s.io
EOF
echo "applying csr-crb.yaml"
kubectl apply -f csr-crb.yaml

if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} - starting kubelet service"
    ssh root@${machine_ip} "mkdir -p ${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/"
    ssh root@${machine_ip} "/usr/sbin/swapoff -a"
    ssh root@${machine_ip} "systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet"
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip} - starting kubelet service"
    ssh root@${worker_ip} "mkdir -p ${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/"
    ssh root@${worker_ip} "/usr/sbin/swapoff -a"
    ssh root@${worker_ip} "systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet"
  done
fi


# manually approve kubelet server request 
# do we need to wait till the CSR is ready ??
sleep 10

if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
    CSRNO=${#iphostmap[@]}
else
    CSRNO=${#WORKER_IPS[@]}
fi

while [ true ]
do
    pendingcsrs=`kubectl get csr | grep Pending | awk '{print $1}'|wc -l`
    if [ $pendingcsrs -lt $CSRNO ]; then
        echo "the csr(s) are not created yet... wait 10 seconds"
        sleep 10
    else
        echo "now the CSR(s) are created...we will proceed to approve"
        break
    fi
done

kubectl get csr | grep Pending | awk '{print $1}' | xargs kubectl certificate approve
# later on I find there are still a bunch of certs were not approved yet. Not sure why.

#创建一个 ServiceAccount，将它和 ClusterRole system:kubelet-api-admin 绑定，从而具有调用 kubelet API 的权限：
kubectl create sa kubelet-api-test
kubectl create clusterrolebinding kubelet-api-test --clusterrole=system:kubelet-api-admin --serviceaccount=default:kubelet-api-test
SECRET=$(kubectl get secrets | grep kubelet-api-test | awk '{print $1}')
TOKEN=$(kubectl describe secret ${SECRET} | grep -E '^token' | awk '{print $2}')
echo ${TOKEN}

# add by BC ##
# at this point, all the nodes shown "NotReady" in kubectl get nodes-A
# but we can label the nodes
if [ $MASTER_WORKER_SEPERATED = true ]; then
  #kubectl label nodes ${MASTER_HOSTS[@]} kubernetes.io/role=master
  kubectl label nodes ${MASTER_HOSTS[@]} node-role.kubernetes.io/master=
  kubectl taint nodes ${MASTER_HOSTS[@]} node-role.kubernetes.io/master=:NoSchedule
fi

# test & check
#curl -s --cacert /etc/kubernetes/cert/ca.pem -H "Authorization: Bearer ${TOKEN}" https://172.27.138.251:10250/metrics | head
