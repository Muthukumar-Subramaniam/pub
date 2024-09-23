#!/bin/bash
cd /scripts_by_muthu/server/k8s
kubectl delete -f nfs-pvc-web-share.yaml
kubectl delete -f nfs-pv-web-share.yaml
