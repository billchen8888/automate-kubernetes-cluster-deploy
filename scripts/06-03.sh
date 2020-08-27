#!/bin/bash

# I found the kubelet.service requires containerd. As I plan to add kubelet.service into master hosts for kubectl get nodes to show master hosts
# so we need logic to add containerd on master hosts then. 

source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

cd /opt/k8s/work
wget -nv https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.17.0/crictl-v1.17.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc10/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz \
  https://github.com/containerd/containerd/releases/download/v1.3.3/containerd-1.3.3.linux-amd64.tar.gz 

cd /opt/k8s/work
mkdir containerd
tar -xvf containerd-1.3.3.linux-amd64.tar.gz -C containerd
tar -xvf crictl-v1.17.0-linux-amd64.tar.gz

mkdir cni-plugins
sudo tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz -C cni-plugins

sudo mv runc.amd64 runc

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  # /etc/cni/net.d/  is referenced in kubelet.service. If we wanto kubelet to run on mster, then it is better to copy it
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} scp containerd binary"
    scp containerd/bin/*  crictl  cni-plugins/*  runc  root@${machine_ip}:/opt/k8s/bin
    ssh root@${machine_ip} "chmod a+x /opt/k8s/bin/* && mkdir -p /etc/cni/net.d"
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    scp containerd/bin/*  crictl  cni-plugins/*  runc  root@${worker_ip}:/opt/k8s/bin
    ssh root@${worker_ip} "chmod a+x /opt/k8s/bin/* && mkdir -p /etc/cni/net.d"
  done
fi

cd /opt/k8s/work
cat << EOF | sudo tee containerd-config.toml
version = 2
root = "${CONTAINERD_DIR}/root"
state = "${CONTAINERD_DIR}/state"

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.cn-beijing.aliyuncs.com/images_k8s/pause-amd64:3.1"
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/k8s/bin"
      conf_dir = "/etc/cni/net.d"
  [plugins."io.containerd.runtime.v1.linux"]
    shim = "containerd-shim"
    runtime = "runc"
    runtime_root = ""
    no_shim = false
    shim_debug = false
EOF

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} scp conatiner config.toml"
    ssh root@${machine_ip} "mkdir -p /etc/containerd/ ${CONTAINERD_DIR}/{root,state}"
    scp containerd-config.toml root@${machine_ip}:/etc/containerd/config.toml
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    ssh root@${worker_ip} "mkdir -p /etc/containerd/ ${CONTAINERD_DIR}/{root,state}"
    scp containerd-config.toml root@${worker_ip}:/etc/containerd/config.toml
  done
fi

cd /opt/k8s/work
cat <<EOF | sudo tee containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
Environment="PATH=/opt/k8s/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStartPre=/sbin/modprobe overlay
ExecStart=/opt/k8s/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} scp containerd.service"
    scp containerd.service root@${machine_ip}:/etc/systemd/system
    ssh root@${machine_ip} "systemctl enable containerd && systemctl restart containerd"
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip} scp conatiner.service"
    scp containerd.service root@${worker_ip}:/etc/systemd/system
    ssh root@${worker_ip} "systemctl enable containerd && systemctl restart containerd"
  done
fi

cd /opt/k8s/work
cat << EOF | sudo tee crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} scp crictl.yaml"
    scp crictl.yaml root@${machine_ip}:/etc/crictl.yaml
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    scp crictl.yaml root@${worker_ip}:/etc/crictl.yaml
  done
fi


## optional:  if we want to run crictl on the central - this tmp  instance: It will NOT work. we have to run in the cluster
##cp containerd/bin/*  crictl  cni-plugins/*  runc  root@${worker_ip}:/opt/k8s/bin
#cp crictl /opt/k8s/bin
#cp crictl.yaml /etc/crictl.yaml
