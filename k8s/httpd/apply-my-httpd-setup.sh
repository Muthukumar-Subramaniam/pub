#!/bin/bash
cd /scripts_by_muthu/muthuks-server/k8s/httpd
kubectl apply -f httpd-deployment.yaml 
kubectl apply -f httpd-service.yaml 
