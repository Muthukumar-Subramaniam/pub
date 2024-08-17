#!/bin/bash
v_worker_node="prod-k8s-n1"
apt update
kubectl drain ${v_worker_node} --ignore-daemonsets
kubectl get nodes
kubectl get pods --all-namespaces
apt upgrade
reboot
kubectl get nodes
watch kubectl get pods --all-namespaces
kubectl uncordon ${v_worker_node}
kubectl get nodes
watch kubectl get pods --all-namespaces
