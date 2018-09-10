#!/bin/bash
#preambule
echo "Please select by number. "
echo "1. install docker and kubernetes"
echo "2. create cluster, install heapster and dashboard"
read answer
if [ $answer -eq 1 ];then
 echo "Start install docker and kubernetes"
 #0
 echo "set for hostname:"
 read hostname
 echo "start install for $hostname"
 #1
 echo "step 1: sudo apt-get update && sudo apt-get upgrade"
 apt-get update && sudo apt-get upgrade
 #2
 echo "step 2: set hostname"
 hostnamectl set-hostname $hostname
 echo "" > /etc/host_tmp
 while IFS='' read -r line
 do
  if [ `echo $line|grep "127.0.0.1 localhost"|wc -l` -gt 0 ];then
   echo "$line $hostname" >> /etc/host_tmp
  else
   echo "$line" >> /etc/host_tmp
  fi
 done < "/etc/hosts"
 mv /etc/host_tmp /etc/hosts
 #3
 echo "step 3: download and install docker"
 apt-get install apt-transport-https -y
 apt install docker.io -y
 systemctl start docker
 systemctl enable docker
 curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
 #4
 echo "step 4: download and install kubernetes"
 echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
 apt-get update
 apt-get install -y kubelet kubeadm kubectl kubernetes-cni
 #5
 echo "Ready for reboot [y/n]?"
 read answer
 while true;do
  if [ $answer = "y" ] || [ $answer = "Y" ];then
   reboot
   break
  elif [ $answer = "n" ] || [ $answer = "N" ];then
   echo ""
   break
  else
   echo "Please input correct answer"
   read answer
  fi
 done
elif [ $answer -eq 2 ];then
 #1
 echo "Step 1: Start create cluster, install heapster and dashboard"
 echo "Create overlay network"
 kubeadm init --pod-network-cidr 10.244.0.0/16
 echo "USE ABOVE TOKEN TO JOIN MINION INTO THE CLUSTER"
 mkdir -p $HOME/.kube
 cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
 chown $(id -u):$(id -g) $HOME/.kube/config
 #2
 echo "Step 2: Download and deploy flannel"
 kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
 kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml
 #3
 echo "Step 3: Download and deploy heapster"
 kubectl apply --filename https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
 wget https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/standalone/heapster-controller.yaml
 cat heapster-controller.yaml | sed 's/kubernetes.default/kubernetes.default\?useServiceAccount=true\&kubeletHttps=true\&kubeletPort=10250\&insecure=true/g' > heapster-controller-tmp.yaml
 kubectl apply -f heapster-controller-tmp.yaml
 rm heapster-controller.yaml heapster-controller-tmp.yaml
 sleep 10
 kubectl -n kube-system get ClusterRoles/system:heapster -o yaml > heapster-cluster-role-tmp.yaml
 echo "" > heapster-cluster-role.yaml
 while IFS='' read -r line
 do
  if [ `echo $line|grep "  resources:"|wc -l` -gt 0 ];then
   echo "  resources:" >> heapster-cluster-role.yaml
   echo "  - events" >> heapster-cluster-role.yaml
   echo "  - namespaces" >> heapster-cluster-role.yaml
   echo "  - nodes" >> heapster-cluster-role.yaml
   echo "  - nodes/stats" >> heapster-cluster-role.yaml
   echo "  - pods" >> heapster-cluster-role.yaml
   echo "  verbs:" >> heapster-cluster-role.yaml
   echo "  - create" >> heapster-cluster-role.yaml
   echo "  - get" >> heapster-cluster-role.yaml
   echo "  - list" >> heapster-cluster-role.yaml
   echo "  - watch" >> heapster-cluster-role.yaml
   echo "- apiGroups:" >> heapster-cluster-role.yaml
   echo "  - extensions" >> heapster-cluster-role.yaml
   echo "  resources:" >> heapster-cluster-role.yaml
   echo "  - deployments" >> heapster-cluster-role.yaml
   echo "  verbs:" >> heapster-cluster-role.yaml
   echo "  - get" >> heapster-cluster-role.yaml
   echo "  - list" >> heapster-cluster-role.yaml
   echo "  - watch" >> heapster-cluster-role.yaml
  else
   echo "$line" >> heapster-cluster-role.yaml
  fi
 done < "heapster-cluster-role-tmp.yaml"
 kubectl replace --force -f heapster-cluster-role.yaml
 rm heapster-cluster-role.yaml heapster-cluster-role-tmp.yaml
 #4
 echo "Step 4: Download and deploy dashboard"
 wget https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
 echo "  type: NodePort" >> kubernetes-dashboard.yaml
 kubectl apply -f kubernetes-dashboard.yaml
 rm kubernetes-dashboard.yaml
else
 echo "Please give correct answer."
 exit
fi
