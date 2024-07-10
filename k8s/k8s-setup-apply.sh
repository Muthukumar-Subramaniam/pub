#!/bin/bash
clear
cd /scripts_by_muthu/muthuks-server/k8s
./apply-nfs-setup.sh
./apply-cifs-setup.sh
./httpd/apply-my-httpd-setup.sh
./nginx/apply-my-nginx-setup.sh

echo -e "\nExecuting : kubectl get all\n"
kubectl get all
echo ""
