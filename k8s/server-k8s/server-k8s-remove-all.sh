#!/bin/bash

# Check for required parameter
if [ -z "$1" ]; then
    echo "Usage: $0 <prod|dev>"
    exit 1
fi

# Set the environment based on the parameter
env="$1"

if [[ "$env" != "prod" && "$env" != "dev" ]]; then
    echo "Invalid parameter. Please specify either 'prod' or 'dev'."
    exit 1
fi

# Get current context and namespace
current_context=$(kubectl config current-context)
current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
current_namespace=${current_namespace:-default} # default to 'default' if no namespace is set

echo "Current Kubernetes context: $current_context"
echo "Current Kubernetes namespace: $current_namespace"

# Confirm with the user
read -p "Are these settings correct? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Please set the correct context and namespace then run the script again."
    exit 1
fi

# Proceed with your script
echo "Proceeding with the script..."

# Add your script logic here, using the provided environment
kubectl delete -k "k8s/$env"

