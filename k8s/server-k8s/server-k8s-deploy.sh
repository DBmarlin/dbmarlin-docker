#!/bin/bash

kubectl apply -f server-k8s-pv.yaml
kubectl apply -f server-k8s-pvc.yaml
kubectl apply -f server-k8s-deploy.yaml
kubectl apply -f server-k8s-service.yaml
