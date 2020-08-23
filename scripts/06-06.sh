#!/bin/bash

#source /opt/k8s/work/iphostinfo   # commented out as not used in this file

cd /opt/k8s/work
#curl https://docs.projectcalico.org/manifests/calico.yaml -O     # this is newer version

curl -L -O https://github.com/projectcalico/calico/releases/download/v3.12.0/release-v3.12.0.tgz

gunzip release-v3.12.0.tgz
tar xvf release-v3.12.0.tar release-v3.12.0/k8s-manifests/calico.yaml

sed -e "s/192.168.0.0/172.30.0.0/" -e "s/path: \/opt\/cni\/bin/path: \/opt\/k8s\/bin/"  release-v3.12.0/k8s-manifests/calico.yaml > calico.yaml

/opt/k8s/bin/kubectl apply -f calico.yaml

echo "sleep 60 seconds now, wait the calico to be ready"
sleep 60
