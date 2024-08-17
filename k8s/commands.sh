#!/bin/bash

#To List pods on a specific node
kubectl get pods --all-namespaces --field-selector spec.nodeName=prod-k8s-cp1.ms.local
kubectl get pods --all-namespaces --field-selector spec.nodeName=prod-k8s-n1.ms.local
kubectl get pods --all-namespaces --field-selector spec.nodeName=prod-k8s-n2.ms.local

