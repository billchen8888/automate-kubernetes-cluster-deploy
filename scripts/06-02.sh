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

######BC the ngix proxy s mainly on worker sidem, but if we want to show master on kubectl get nodes command ======
cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} scp nginx binary"
    ssh root@${machine_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    scp /opt/k8s/work/nginx-1.15.3/nginx-prefix/sbin/nginx  root@${machine_ip}:/opt/k8s/kube-nginx/sbin/kube-nginx
    ssh root@${machine_ip} "chmod a+x /opt/k8s/kube-nginx/sbin/*"
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip} scp nginx binary"
    ssh root@${worker_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    scp /opt/k8s/work/nginx-1.15.3/nginx-prefix/sbin/nginx  root@${worker_ip}:/opt/k8s/kube-nginx/sbin/kube-nginx
    ssh root@${worker_ip} "chmod a+x /opt/k8s/kube-nginx/sbin/*"
  done
fi

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
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} scp nginx.conf"
    scp kube-nginx.conf  root@${machine_ip}:/opt/k8s/kube-nginx/conf/kube-nginx.conf
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip} scp nginx.conf"
    scp kube-nginx.conf  root@${worker_ip}:/opt/k8s/kube-nginx/conf/kube-nginx.conf
  done
fi

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
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} scp kube-nginx.service"
    scp kube-nginx.service  root@${machine_ip}:/etc/systemd/system/
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip} scp kube-nginx.service"
    scp kube-nginx.service  root@${worker_ip}:/etc/systemd/system/
  done
fi

cd /opt/k8s/work
if [ $MASTER_WORKER_SEPERATED = true ] &&  [ "$SHOW_MASTER" = "true" ]; then
  for machine_ip in ${!iphostmap[@]}
  do
    echo ">>> ${machine_ip} start nginx"
    ssh root@${machine_ip} "systemctl daemon-reload && systemctl enable kube-nginx && systemctl restart kube-nginx"
  done
else
  for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip} start nginx"
    ssh root@${worker_ip} "systemctl daemon-reload && systemctl enable kube-nginx && systemctl restart kube-nginx"
  done
fi
