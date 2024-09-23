#!/bin/bash
clear
cd /scripts_by_muthu/server/k8s
./apply-nfs-setup.sh
./apply-cifs-setup.sh
#./httpd/apply-my-httpd-setup.sh
#./nginx/apply-my-nginx-setup.sh
kubectl apply -f ./httpd/httpd-all-in-one.yaml
kubectl apply -f ./nginx/nginx-all-in-one.yaml

echo -e "\nExecuting : kubectl get all\n"
kubectl get all
echo ""
