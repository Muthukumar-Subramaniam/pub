#!/bin/bash
cd /scripts_by_muthu/server/k8s/httpd
kubectl delete -f httpd-service.yaml 
kubectl delete -f httpd-deployment.yaml 
