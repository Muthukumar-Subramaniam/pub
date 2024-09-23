#!/bin/bash
clear
cd /scripts_by_muthu/server/k8s
kubectl delete -f ./nginx/nginx-all-in-one.yaml
kubectl delete -f ./httpd/httpd-all-in-one.yaml
#./nginx/delete-my-nginx-setup.sh
#./httpd/delete-my-httpd-setup.sh
./delete-cifs-setup.sh
./delete-nfs-setup.sh

echo -e "\nExecuting : kubectl get all\n"
kubectl get all
echo ""
