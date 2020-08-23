#!/bin/bash

source ../USERDATA
# we need to keep in mind what files to be sourced in different servers.
# Do we need the environment.sh or iphostmap info on the k8s cluster machines?

# validate the user data
if [ ${#MASTER_IPS[@]} != ${#MASTER_HOSTS[@]} ]; then
    echo "The numbers of IPs and hosts for masters don't match in USERDATA"
    exit 1
fi

if [ ${#WORKER_IPS[@]} != ${#WORKER_HOSTS[@]} ]; then
    echo "The numbers of IPs and hosts for nodes don't match in USERDATA"
    exit 1
fi

setiphostmap_scenario1() {
  # MASTWR and WORKER are on exact same hosts
  cat > /opt/k8s/work/iphostinfo << EOF
  declare -A iphostmap

  MASTER_WORKER_SEPERATED=false

  iphostmap=( `for i in ${!MASTER_IPS[@]}
  do
    echo -n "[${MASTER_IPS[$i]}]=${MASTER_HOSTS[$i]} "
  done` )
EOF
}

setiphostmap_scenario2() {
  # MASTWR and WORKER are completely on different hosts
  cat > /opt/k8s/work/iphostinfo << EOF
  declare -A iphostmap

  MASTER_WORKER_SEPERATED=true

  iphostmap=( `
  for i in ${!MASTER_IPS[@]}
  do
    echo -n "[${MASTER_IPS[$i]}]=${MASTER_HOSTS[$i]} "
  done
  for i in ${!WORKER_IPS[@]}
  do
    echo -n "[${WORKER_IPS[$i]}]=${WORKER_HOSTS[$i]} "
  done
` )
EOF
}

# in our configuration, we only handle two scenarios:
# 1) the master and node are same
# 2) or they are totally different. We don't want combination
#      meaning a portion of machines acting master AND node. That is too confusing

readarray -t sorted_master_ips < <(printf '%s\n' "${MASTER_IPS[@]}"|sort)
readarray -t sorted_worker_ips < <(printf '%s\n' "${WORKER_IPS[@]}"|sort)

readarray -t sorted_master_hosts < <(printf '%s\n' "${MASTER_HOSTS[@]}"|sort)
readarray -t sorted_worker_hosts < <(printf '%s\n' "${WORKER_HOSTS[@]}"|sort)

# echo "sorted master ip is: ${sorted_master_ips[@]}"
# echo "sorted node ip is: ${sorted_worker_ips[@]}"
if [ "$sorted_master_ips" = "$sorted_worker_ips" ]; then
   #echo "same"
   if [  "$sorted_master_hosts" != "$sorted_worker_hosts" ]; then
       echo "IP addressed match, but hosts don't in USERDATA. I cannot proceed"
       exit 1
   else
       mkdir -p /opt/k8s/work
       setiphostmap_scenario1
   fi
else
   # echo not exactly same
   # now we need to make sure tere is no commo value(s) 
   commonips=$(join <(printf %s\\n "${sorted_master_ips[@]}" ) <(printf %s\\n "${sorted_worker_ips[@]}") )
   commonhosts=$(join <(printf %s\\n "${sorted_master_hosts[@]}" ) <(printf %s\\n "${sorted_worker_hosts[@]}") )
   # the result is a string, not array.
   # if there is any common value, then we will exit
   if [ x"$commonips" != "x" ]; then
       echo "The master and node are either exactly same or totally different. We don't handle the situation partially combined"
       exit 1
   elif [  x"$commonhosts" != "x" ]; then
       echo "There seems duplicated hostname in USERDATA. I cannot proceed" 
       exit 1
   else
       # now we proceed
       mkdir -p /opt/k8s/work
       setiphostmap_scenario2
   fi
fi

# the genearted iphostmap in the code would not be duplicated even if the MASTER_IPS and WORKER_IPS are same
# the iphostmap is mainly for /etc/hosts entry as we need to know the mapping.
# and in the scenarion that we need to copy something cross-board when no need to worry about the role of the hosts
# 

## need to get unique IPs (in case master and nodes are same)
## then we don't need to install packages or copy multiple times on same IP 
#unique_ips=`printf "%s\n" ${IP_MASTERS[@]}  ${IP_MASTERS[@]}  |sort -u`
## unique_ips is a string, not array
