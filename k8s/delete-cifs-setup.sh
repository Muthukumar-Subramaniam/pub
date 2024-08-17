#!/bin/bash
cd /scripts_by_muthu/muthuks-server/k8s
kubectl delete -f cifs-pvc-downloads.yaml
kubectl delete -f cifs-pv-downloads.yaml
kubectl delete -f cifs-credentials.yaml
