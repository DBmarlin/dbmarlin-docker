#!/bin/bash

kubectl delete deployment dbmarlin-server
kubectl delete service dbmarlin-service
kubectl delete pvc dbmarlin-pvc
kubectl delete pv dbmarlin-pv
