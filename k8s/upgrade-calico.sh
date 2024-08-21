#!/bin/bash
## https://docs.tigera.io/calico/latest/operations/upgrading/kubernetes-upgrade 
v_calico_version="3.28.1"
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/projectcalico/calico/v${v_calico_version}/manifests/calico.yaml
