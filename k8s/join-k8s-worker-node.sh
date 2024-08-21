#!/bin/bash
v_k8s_host="$1"

f_check_dns_record() {
	if ! nslookup "${1}" &>/dev/null
	then
		echo -e "\nNo such host record \"${1}\" found in ms.local domain ! \n"
		return 1
	else
		return 0
	fi
}


if [[ -z "$1" ]]
then
	while :
	do
		read -p "Please enter the hostname of worker node to join : " v_k8s_host 

		if f_check_dns_record "${v_k8s_host}"
		then
			break
		else
			continue
		fi
	done
else
	if ! f_check_dns_record "${1}"
	then
		exit
	fi
fi


if ! nc -vzw1 ${v_k8s_host} 22 &>/dev/null
then
	echo -e "\nk8s host ${v_k8s_host} seems to be down, Not Reachable via ssh! \n"
        exit
else
	ssh-keygen -R ${v_k8s_host} &>/dev/null

	echo -e "\nChecking the status of containerd container run time . . .\n" 
	if ! ssh -o StrictHostKeyChecking=accept-new root@${v_k8s_host} "systemctl is-active containerd && containerd --version"
	then
		echo -e "Container run time containerd is not running on host ${v_k8s_host}, please check ! \n"
		exit
	fi

	echo -e "\nChecking the status of runc . . .\n"
	if ! ssh -o StrictHostKeyChecking=accept-new root@${v_k8s_host} "runc --version"
	then
		echo -e "runc is not installed, please check ! \n"
		exit
	fi

	echo -e "\nChecking whether kubelet service is enabled . . .\n"
	if ! ssh -o StrictHostKeyChecking=accept-new root@${v_k8s_host} "systemctl is-enabled kubelet"
	then
		echo -e "kubelet service is not enabled on host  ${v_k8s_host}, please check! \n"
		exit
	fi

	v_join_command="$(kubeadm token create --print-join-command)"

	echo -e "\nExecuting join command on the worker node ${v_k8s_host} . . .\n"

        ssh -o StrictHostKeyChecking=accept-new root@${v_k8s_host} "$v_join_command"

	kubectl get nodes
fi

exit
