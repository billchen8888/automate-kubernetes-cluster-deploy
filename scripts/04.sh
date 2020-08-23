#!/bin/bash
#source /opt/k8s/work/iphostinfo # iphostmapis not used in this file
source ../USERDATA
source /opt/k8s/bin/environment.sh

###### 04: etcd ####
cd /opt/k8s/work
wget -nv https://github.com/coreos/etcd/releases/download/v3.4.3/etcd-v3.4.3-linux-amd64.tar.gz
tar -xvf etcd-v3.4.3-linux-amd64.tar.gz

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp etcd-v3.4.3-linux-amd64/etcd* root@${master_ip}:/opt/k8s/bin
    ssh root@${master_ip} "chmod +x /opt/k8s/bin/*"
  done

cd /opt/k8s/work
cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
`arraysize=${#MASTER_IPS[@]}
 i=1
 for ip in ${MASTER_IPS[@]}
 do
   if [ $i -eq $arraysize ]; then
     echo "    \"$ip\""
   else
     echo "    \"$ip\","
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
    -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${mastere_ip}"
    ssh root@${master_ip} "mkdir -p /etc/etcd/cert"
    scp etcd*.pem root@${master_ip}:/etc/etcd/cert/
  done

cd /opt/k8s/work
cat > etcd.service.template <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=${ETCD_DATA_DIR}
ExecStart=/opt/k8s/bin/etcd \\
  --data-dir=${ETCD_DATA_DIR} \\
  --wal-dir=${ETCD_WAL_DIR} \\
  --name=##MASTER_NAME## \\
  --cert-file=/etc/etcd/cert/etcd.pem \\
  --key-file=/etc/etcd/cert/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-cert-file=/etc/etcd/cert/etcd.pem \\
  --peer-key-file=/etc/etcd/cert/etcd-key.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-peer-urls=https://##MASTER_IP##:2380 \\
  --initial-advertise-peer-urls=https://##MASTER_IP##:2380 \\
  --listen-client-urls=https://##MASTER_IP##:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://##MASTER_IP##:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --auto-compaction-mode=periodic \\
  --auto-compaction-retention=1 \\
  --max-request-bytes=33554432 \\
  --quota-backend-bytes=6442450944 \\
  --heartbeat-interval=250 \\
  --election-timeout=2000
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cd /opt/k8s/work
#for ip in ${MASTER_IPS[@]}
for (( i=0; i < ${#MASTER_IPS[@]}; i++ ))
  do
    sed -e "s/##MASTER_NAME##/${MASTER_HOSTS[$i]}/" -e "s/##MASTER_IP##/${MASTER_IPS[$i]}/" etcd.service.template > etcd-${MASTER_IPS[$i]}.service 
  done
ls *.service

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp etcd-${master_ip}.service root@${master_ip}:/etc/systemd/system/etcd.service
  done

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo "========================starting etcd.service on ${master_ip} at `date` ============================= "
    ssh root@${master_ip} "mkdir -p ${ETCD_DATA_DIR} ${ETCD_WAL_DIR}"
    ssh root@${master_ip} "systemctl daemon-reload && systemctl enable etcd && systemctl restart etcd " &
    # in Zhangjun's document, a "&" is attached in the end. If not, the starting etcd on the 1st node would timeout and systemctl 
    # said failed, but it actuallty doesn't fail. ETCD is up. why?? in Zhangjun's docudment
    # it mentioned that the etcd will wait for other nodes to join, so it might get stuck for some time
    # to avoid the false-alert for the 1st etcd node, it is good to put "&"
  done

sleep 5 # (let the etcd cluster to be ready)
for master_ip in ${MASTER_IPS[@]}
  do
    ssh $master_ip "systemctl status etcd.service | grep Active"
  done

## status check commands here. etcdctl should be invoked from any etcd node
## comment it out now before we get a good way to test it
#ssh -q {MASTER_IPS[0]} sh -c  "
#for master_ip in ${MASTER_IPS[@]}
# do
#    /opt/k8s/bin/etcdctl \
#        --endpoints=https://${master_ip}:2379 \
#        --cacert=/etc/kubernetes/cert/ca.pem \
#        --cert=/etc/etcd/cert/etcd.pem \
#        --key=/etc/etcd/cert/etcd-key.pem endpoint health
#  done "
