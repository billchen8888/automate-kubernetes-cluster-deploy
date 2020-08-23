# kubernetes cluster stack deplyment automation (on Centos 7)

I try to write a wrapper script to automate the steps listed in https://github.com/opsnull/follow-me-install-kubernetes-cluster. So far I am at the step 08-2, but I run into some issues. In the author's tutorial, the master and worker nodes are on the same machines, and my scripts try to cover the scenarios that the master and worker nodes are on different machines. But if we set the same IPs and hosts for MASTER and Worker, the script will handle that too.

Now I run into some issue on step 06-04...If the master and worker are on different machines, the script hangs on step 06-4 for csr to be ready. The scrupt does work when we set the master and worker on the same machines. I need some help to troubleshoot the kubernetes issue. If you can help, please email me bill_j_chen@yahoo.com

How to use this package

1) clone the package to a machine. This machine should be not a master or node in the k8s cluster
2) make sure this machine can ssh to all k8s machines without passwd
3) edit USERDATA, put your IP and hosts in the file
4) run deploy_k8s_stack.sh as root

this script is tested on centos 7 on AWS with standrad centos 7 AMI.

we run the script on one box which is not a member of the k8s cluster member
if we want to run on a box which is a member of k8s cluster, then we need to COMMENT OUT the "init 6" in the 01.sh
and then manually reboot the nodes.  The reason is that 01.sh will reboot all the k8s nodes after the kernel update.  When
the box we run script is a member if the cluster, the reboot will interrupt the script.

we NEED to run the wrapper script as root on the central box, as we need to create /opt/k8s/ etc, and I
didn't use sudo for the local box

we call the box where we run the script "central box"
the prequisite is:
 1) the central box has the same OS as the member of k8s cluster, as we will compile nginx and destribute the binary
 2) the central box can ssh to all k8s nodes  as root without passwd

we need to give values in USERDATA

in the USERDATA,   we can set the input like the following
# EXAMPLE 1: (MASTER and WORKER are on exactly same machines)
MASTER_IPS=(10.10.1.1 10.10.1.2 10.10.1.3)
MASTER_HOSTS=(host1 host2 host3)

WORKER_IPS=(10.10.1.1 10.10.1.2 10.10.1.3)
WORKER_HOSTS=(host11 host2 host3)

-------------------------------

# EXAMPLE 2:  (MASTER and WORKER are completely seperated)
MASTER_IPS=(10.10.1.1 10.10.1.2 10.10.1.3)
MASTER_HOSTS=(host1 host2 host3)

WORKER_IPS=(10.10.1.4 10.10.1.5 10.10.1.6)
WORKER_HOSTS=(host4 host5 host6)
