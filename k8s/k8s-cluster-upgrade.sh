#!/bin/bash
#Link : https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

#Control Plan node
#=================
#Check Current Version details
kubectl get nodes -o wide
kubeadm version
kubectl version
kubelet --version
#Drain the Control Plan node
kubectl drain k8s-cp1  --ignore-daemonsets
kubectl get nodes
kubectl get pods --all-namespaces
apt update
apt-cache madison kubeadm
#1)Upgrade system and kubeadm:
# replace x in 1.30.x-* with the latest patch version
v_k8s_version="1.31.0-1.1"
v_k8s_version_name="v$(echo $v_k8s_version | cut -d "-" -f 1)"
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm="${v_k8s_version}" && \
apt-mark hold kubeadm
#2)Verify that the download works and has the expected version:
kubeadm version
#3)Verify the upgrade plan:
kubeadm upgrade plan
#4)Upgrade kubeadm
kubeadm upgrade apply ${v_k8s_version_name}
#5)Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet="${v_k8s_version}" kubectl="${v_k8s_version}" && \
apt-mark hold kubelet kubectl
#6)Restart the kubelet:
sudo systemctl daemon-reload
sudo systemctl restart kubelet
#7)Uncordon the Control Plan node
kubectl uncordon


#Worker nodes
v_worker_node="k8s-w1"
kubectl drain ${v_worker_node} --ignore-daemonsets
#Once done login to worker node
#1)Upgrade system and kubeadm:
# replace x in 1.30.x-* with the latest patch version
v_k8s_version="1.31.0-1.1"
apt-mark unhold kubeadm && \
apt-get update && apt-get install -y kubeadm="${v_k8s_version}" && \
apt-mark hold kubeadm
#2)Call "kubeadm upgrade"
kubeadm upgrade node
#3)Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl && \
apt-get update && apt-get install -y kubelet="${v_k8s_version}" kubectl="${v_k8s_version}" && \
apt-mark hold kubelet kubectl
#4)Restart the kubelet:
sudo systemctl daemon-reload
sudo systemctl restart kubelet
#5)Uncordon the Control Plan node
#Login back to control plane node
kubectl uncordon ${v_worker_node}


#Verify the status of the cluste
kubectl get nodes -o wide
