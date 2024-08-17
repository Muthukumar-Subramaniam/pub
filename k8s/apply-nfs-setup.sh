#!/bin/bash
cd /scripts_by_muthu/muthuks-server/k8s
kubectl apply -f nfs-pv-web-share.yaml
kubectl apply -f nfs-pvc-web-share.yaml
