#!/bin/bash
clear
cd /scripts_by_muthu/muthuks-server/k8s
./nginx/delete-my-nginx-setup.sh
./httpd/delete-my-httpd-setup.sh
./delete-cifs-setup.sh
./delete-nfs-setup.sh

echo -e "\nExecuting : kubectl get all\n"
kubectl get all
echo ""
