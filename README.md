# kubernetes cluster stack deplyment automation (on Centos 7)

I wrote this wrapper script to automate the steps listed in https://github.com/opsnull/follow-me-install-kubernetes-cluster. In the author's tutorial, the master and worker nodes are on the same machines. My deployment script covers the scenario that the master and worker nodes are on different machines.

How to use this package

1) clone the package to a machine. This machine should be not a master or node in the k8s cluster
2) make sure this machine can ssh to all k8s machines without passwd
3) edit USERDATA, put your IP and hosts in the file
4) run deploy_k8s_stack.sh as root

this script is tested on centos 7 on AWS with standrad centos 7 AMI.

we run the script on one control box which is not a member of the k8s cluster member.
If we want to run on a box which is a member of k8s cluster, then we need to COMMENT OUT the "init 6" in the 01.sh
and then manually reboot the nodes.  The reason is that 01.sh will reboot all the k8s nodes after the kernel update.  When
the box we run script is a member if the cluster, the reboot will interrupt the script.

we NEED to run the wrapper script as root on the central box, as we need to create /opt/k8s/ etc, and I
didn't use sudo for the local box

we call the box where we run the script "central box"
the prequisite is:
 1) the central box has the same OS as the member of k8s cluster, as we will compile nginx and destribute the binary
 2) the central box can ssh to all k8s nodes  as root without passwd

we need to give values in USERDATA

in the USERDATA,   we put the MASTER and WORKER nfo input like the following. Please note, we can put any number of machiens for MASTER or WORKER. 
# EXAMPLE 1: (MASTER and WORKER are on exactly same machines) 
MASTER_IPS=(10.10.1.1 10.10.1.2 10.10.1.3) </br>
MASTER_HOSTS=(host1 host2 host3)   </br>

WORKER_IPS=(10.10.1.1 10.10.1.2 10.10.1.3) </br>
WORKER_HOSTS=(host1 host2 host3)

-------------------------------

# EXAMPLE 2:  (MASTER and WORKER are completely seperated)
MASTER_IPS=(10.10.1.1 10.10.1.2 10.10.1.3) </br>
MASTER_HOSTS=(host1 host2 host3)  </br>

WORKER_IPS=(10.10.1.4 10.10.1.5 10.10.1.6) </br>
WORKER_HOSTS=(host4 host5 host6)

# features to add
We might want to give flexibility that the etcd can run on its own set of machines - not necessarily on the master. At this momeny I cannot make promise yet...not sure when I can get some time to work on this:-)
