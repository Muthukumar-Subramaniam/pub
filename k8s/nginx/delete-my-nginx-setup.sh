#!/bin/bash
cd /scripts_by_muthu/server/k8s/nginx
kubectl delete -f nginx-service.yaml 
kubectl delete -f nginx-deployment.yaml 
