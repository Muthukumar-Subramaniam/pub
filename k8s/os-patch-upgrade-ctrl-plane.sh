#!/bin/bash
v_ctrl_plane_node="k8s-cp1"
apt update
kubectl drain ${v_ctrl_plane_node} --ignore-daemonsets --delete-emptydir-data
kubectl get nodes
kubectl get pods --all-namespaces
apt upgrade
reboot
kubectl get nodes
watch kubectl get pods --all-namespaces
kubectl uncordon ${v_ctrl_plane_node}
kubectl get nodes
watch kubectl get pods --all-namespaces
