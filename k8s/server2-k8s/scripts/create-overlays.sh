#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="k8s/overlays"

OVERLAYS=(
  standalone-localpath
  standalone-gke
  standalone-aks
  standalone-eks
  stateful-localpath
  stateful-gke
  stateful-aks
  stateful-eks
)

for overlay in "${OVERLAYS[@]}"; do
  mkdir -p "${BASE_DIR}/${overlay}"

  mode="deployment"
  if [[ "${overlay}" == stateful-* ]]; then
    mode="statefulset"
  fi

  storage_class="local-path"
  if [[ "${overlay}" == *-gke ]]; then
    storage_class="standard-rwo"
  elif [[ "${overlay}" == *-aks ]]; then
    storage_class="managed-csi"
  elif [[ "${overlay}" == *-eks ]]; then
    storage_class="gp3"
  fi

  cat > "${BASE_DIR}/${overlay}/kustomization.yaml" <<KUSTOMIZE
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base
  - ../../components/${mode}

patches:
  - path: storageclass-patch.yaml
  - path: image-patch.yaml
KUSTOMIZE

  cat > "${BASE_DIR}/${overlay}/storageclass-patch.yaml" <<PATCH
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbmarlin-pvc
spec:
  storageClassName: ${storage_class}
PATCH

  if [[ "${mode}" == "deployment" ]]; then
    cat > "${BASE_DIR}/${overlay}/image-patch.yaml" <<PATCH
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dbmarlin-server
spec:
  template:
    spec:
      initContainers:
        - name: dbmarlin-init
          image: dbmarlin/dbmarlin-server:latest
      containers:
        - name: dbmarlin-server
          image: dbmarlin/dbmarlin-server:latest
PATCH
  else
    cat > "${BASE_DIR}/${overlay}/image-patch.yaml" <<PATCH
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: dbmarlin-server
spec:
  template:
    spec:
      initContainers:
        - name: dbmarlin-init
          image: dbmarlin/dbmarlin-server:latest
      containers:
        - name: dbmarlin-server
          image: dbmarlin/dbmarlin-server:latest
PATCH
  fi

done

echo "Created DBmarlin Kustomize overlays under ${BASE_DIR}"
