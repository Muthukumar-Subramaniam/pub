#!/bin/bash
v_role_name=$1
v_role_name=${v_role_name:-worker-node}

for v_node in $(kubectl get nodes | grep -v ^NAME | awk '{ print $1 }')
do
	if kubectl get node $v_node | awk '{ print $3 }' | grep control-plane &>/dev/null
	then
		continue
	fi

	kubectl label node $v_node node-role.kubernetes.io/${v_role_name}-
done

kubectl get nodes
