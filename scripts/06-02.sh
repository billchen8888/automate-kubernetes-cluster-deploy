#!/bin/bash
source ../USERDATA
source /opt/k8s/work/iphostinfo
source /opt/k8s/bin/environment.sh

cd /opt/k8s/work
wget -nv http://nginx.org/download/nginx-1.15.3.tar.gz
tar -xzvf nginx-1.15.3.tar.gz

cd /opt/k8s/work/nginx-1.15.3
mkdir nginx-prefix
yum install -y gcc make
./configure --with-stream --without-http --prefix=$(pwd)/nginx-prefix --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module

cd /opt/k8s/work/nginx-1.15.3
make && make install

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    ssh root@${master_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
  done

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    ssh root@${master_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    scp /opt/k8s/work/nginx-1.15.3/nginx-prefix/sbin/nginx  root@${master_ip}:/opt/k8s/kube-nginx/sbin/kube-nginx
    ssh root@${master_ip} "chmod a+x /opt/k8s/kube-nginx/sbin/*"
  done

cd /opt/k8s/work
cat > kube-nginx.conf << EOF
worker_processes 1;

events {
    worker_connections  1024;
}

stream {
    upstream backend {
        hash $remote_addr consistent;
`for ip in ${MASTER_IPS[@]};do echo "       server ${ip}:6443 max_fails=3 fail_timeout=30s;";done`
    }

    server {
        listen 127.0.0.1:8443;
        proxy_connect_timeout 1s;
        proxy_pass backend;
    }
}
EOF

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp kube-nginx.conf  root@${master_ip}:/opt/k8s/kube-nginx/conf/kube-nginx.conf
  done

cd /opt/k8s/work
cat > kube-nginx.service <<EOF
[Unit]
Description=kube-apiserver nginx proxy
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStartPre=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -t
ExecStart=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx
ExecReload=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -s reload
PrivateTmp=true
Restart=always
RestartSec=5
StartLimitInterval=0
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    scp kube-nginx.service  root@${master_ip}:/etc/systemd/system/
  done

cd /opt/k8s/work
for master_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${master_ip}"
    ssh root@${master_ip} "systemctl daemon-reload && systemctl enable kube-nginx && systemctl restart kube-nginx"
  done


