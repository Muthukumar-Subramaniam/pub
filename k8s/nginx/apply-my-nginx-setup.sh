#!/bin/bash
cd /scripts_by_muthu/muthuks-server/k8s/nginx
kubectl apply -f nginx-deployment.yaml 
kubectl apply -f nginx-service.yaml 
