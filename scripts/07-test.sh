
source ../USERDATA
source /opt/k8s/bin/environment.sh
notready=`kubectl get nodes | grep -v NAME |grep -v NotReady |wc -l`
if [ $notready != 0 ]; then
  echo "WARNING cluster node are not full up, but I will still continue"
  #exit 255
  # anyway, when we use |tee in the wrapper script, this exit will only exit this script, 
  # not the wrapper, so I decide to comment out the exit line here
fi

cd /opt/k8s/work
cat > nginx-ds.yml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-ds
  labels:
    app: nginx-ds
spec:
  type: NodePort
  selector:
    app: nginx-ds
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-ds
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      app: nginx-ds
  template:
    metadata:
      labels:
        app: nginx-ds
    spec:
      containers:
      - name: my-nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
EOF

kubectl create -f /opt/k8s/work/nginx-ds.yml

echo sleep 10 seconds to let the reources to be ready
sleep 10

while [ true ]
do
  podips=`kubectl get pods  -o wide -l app=nginx-ds |grep -v NAME |awk '{print $6}' |grep -v none`
  # I notice some entries have IPcolume <none>. WhY? is it because I enabled the kubelet and containerd on master??
  if [ "$podips" = "" ]; then
    echo "pod not ready yet, sleep 10 seconds ..."
  else
    break
  fi
done

for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    #ssh ${worker_ip} "ping -c 1 172.30.244.1"
    for podip in $podips
     do
       ssh ${worker_ip} "ping -c 1 $podip"
     done
  done

svcip=`kubectl get svc -l app=nginx-ds |grep -v NAME |awk '{print $3}'`
for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    ssh ${worker_ip} "curl -s $svcip"
  done

# test the NodePort`
nodeport=`kubectl get svc -l app=nginx-ds |grep -v NAME |awk '{print $5}'|awk 'BEGIN {FS=":"} {print $2}' |sed 's/\/TCP//' `
for worker_ip in ${WORKER_IPS[@]}
  do
    echo ">>> ${worker_ip}"
    ssh ${worker_ip} "curl -s ${worker_ip}:$nodeport"
  done
