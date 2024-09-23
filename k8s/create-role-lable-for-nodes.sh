#!/bin/bash
var_worker_node_role_name="${1}"
var_worker_node_role_name="${var_worker_node_role_name:-worker-bee}"
var_remove_role_name="${2}"

for var_k8s_node in $(kubectl get nodes --no-headers | grep -i -v 'control-plane' | awk '{ print $1 }')
do
	if [[ "${var_remove_role_name}" == "--remove" ]]
	then
		kubectl label node "${var_k8s_node}" node-role.kubernetes.io/"${var_worker_node_role_name}"-
	else
		kubectl label node "${var_k8s_node}" node-role.kubernetes.io/"${var_worker_node_role_name}"=true
	fi
done

kubectl get nodes
