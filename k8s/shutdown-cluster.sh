#!/bin/bash
for v_k8s_host in prod-k8s-{cp1,n{1,2}}.ms.local
do
	if ! nc -vzw1 ${v_k8s_host} 22 &>/dev/null
	then
		echo -e "\nk8s host ${v_k8s_host} seems to be down already, Not Reachable! \n"
		continue
	else
		echo -e "\nShutting down k8s host ${v_k8s_host} . . .\n"
		ssh-keygen -R ${v_k8s_host} &>/dev/null
		ssh -o StrictHostKeyChecking=accept-new root@${v_k8s_host} "shutdown -h now" &>/dev/null
	fi
done
