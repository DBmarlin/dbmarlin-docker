#!/bin/bash

# Resolve the directory this script lives in so it can be run from anywhere
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
overlays_dir="${script_dir}/k8s/overlays"

# Check for required parameter
if [ -z "$1" ] || [ ! -d "${overlays_dir}/$1" ]; then
    echo "Usage: $0 <overlay>"
    echo "Available overlays:"
    ls -1 "${overlays_dir}"
    exit 1
fi

overlay="$1"

# Get current context and namespace
current_context=$(kubectl config current-context)
current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
current_namespace=${current_namespace:-default} # default to 'default' if no namespace is set

echo "Current Kubernetes context: $current_context"
echo "Current Kubernetes namespace: $current_namespace"

# Confirm with the user
read -r -p "Are these settings correct? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Please set the correct context and namespace then run the script again."
    exit 1
fi

echo "Removing overlay '$overlay'... (WARNING: this deletes the PVC and its data)"
kubectl delete -k "${overlays_dir}/${overlay}"
