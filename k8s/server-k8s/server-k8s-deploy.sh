#!/bin/bash

# Resolve the directory this script lives in so it can be run from anywhere
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
overlays_dir="${script_dir}/k8s/overlays"

# Check for required parameter
if [ -z "$1" ] || [ ! -d "${overlays_dir}/$1" ]; then
    echo "Usage: [DBMARLIN_SIZE=<XSmall|Small|Medium|Large|XLarge>] [DBMARLIN_SERVICE=nodeport] $0 <overlay>"
    echo "Available overlays:"
    ls -1 "${overlays_dir}"
    exit 1
fi

overlay="$1"

# DBMARLIN_SIZE selects a size-* component that sets the profile passed to
# configure.sh and the matching CPU/memory requests/limits. Disk is NOT changed
# automatically (PVCs cannot shrink and not every StorageClass can expand) -
# we only warn below if the PVC looks too small for the profile.
size_component=""
if [ -n "${DBMARLIN_SIZE}" ]; then
    case "$(echo "${DBMARLIN_SIZE}" | tr '[:upper:]' '[:lower:]')" in
        xsmall) DBMARLIN_SIZE="XSmall" ;;
        small)  DBMARLIN_SIZE="Small" ;;
        medium) DBMARLIN_SIZE="Medium" ;;
        large)  DBMARLIN_SIZE="Large" ;;
        xlarge) DBMARLIN_SIZE="XLarge" ;;
        *)
            echo "Invalid DBMARLIN_SIZE '${DBMARLIN_SIZE}' (valid: XSmall, Small, Medium, Large, XLarge)"
            exit 1
            ;;
    esac
    size_component="size-$(echo "${DBMARLIN_SIZE}" | tr '[:upper:]' '[:lower:]')"
fi

# DBMARLIN_SERVICE=nodeport switches the service from LoadBalancer to NodePort,
# which avoids the cost of a cloud load balancer on test clusters.
service_component=""
if [ -n "${DBMARLIN_SERVICE}" ]; then
    case "$(echo "${DBMARLIN_SERVICE}" | tr '[:upper:]' '[:lower:]')" in
        nodeport)     service_component="service-nodeport" ;;
        loadbalancer) ;; # the default - nothing to add
        *)
            echo "Invalid DBMARLIN_SERVICE '${DBMARLIN_SERVICE}' (valid: LoadBalancer, NodePort)"
            exit 1
            ;;
    esac
fi

# Build a throwaway overlay that layers the selected components on top of the
# chosen overlay, so the env vars and manifests always change together.
target="${overlays_dir}/${overlay}"
if [ -n "${size_component}" ] || [ -n "${service_component}" ]; then
    tmp_overlay=$(mktemp -d "${overlays_dir}/.override.XXXXXX")
    trap 'rm -rf "${tmp_overlay}"' EXIT
    {
        cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../${overlay}
components:
EOF
        [ -n "${size_component}" ] && echo "  - ../../components/${size_component}"
        [ -n "${service_component}" ] && echo "  - ../../components/${service_component}"
    } > "${tmp_overlay}/kustomization.yaml"
    target="${tmp_overlay}"
fi

# Recommended minimum disk per profile (Gi) - see the DBmarlin hardware requirements
recommended_disk_gi() {
    case "$1" in
        XSmall) echo 20 ;;
        Small)  echo 100 ;;
        Medium) echo 400 ;;
        Large)  echo 1000 ;;
        XLarge) echo 2000 ;;
    esac
}

# Convert a Kubernetes quantity (Gi/Ti/Mi) to Gi; empty output = unknown unit
to_gi() {
    case "$1" in
        *Ti) echo $(( ${1%Ti} * 1024 )) ;;
        *Gi) echo "${1%Gi}" ;;
        *Mi) echo $(( ${1%Mi} / 1024 )) ;;
        *)   echo "" ;;
    esac
}

# Render once and apply the same manifest that we checked. A rendering failure
# must not be mistaken for a dev overlay without persistent storage.
if ! rendered_manifest=$(kubectl kustomize "${target}"); then
    echo "Unable to render overlay '${overlay}'; nothing has been applied." >&2
    exit 1
fi

# Read the profile from dbmarlin-copy, including size components in the overlay.
# This reads kubectl kustomize's canonical YAML output, not the source YAML.
effective_size=$(printf '%s\n' "${rendered_manifest}" | awk '
    function save_profile() {
        if (container_name == "dbmarlin-copy") result = profile
    }
    /^---$/ {
        if (in_init) save_profile()
        stateful = selected = in_init = in_size = 0
        container_name = profile = ""
    }
    /^kind:/ { stateful = ($2 == "StatefulSet") }
    stateful && /^  name:/ { selected = ($2 == "dbmarlin-server") }
    stateful && selected {
        if ($0 ~ /^      initContainers:$/) { in_init = 1; next }
        if (in_init && $0 ~ /^      [a-zA-Z]/) {
            save_profile(); in_init = 0
        }
        if (in_init && $0 ~ /^      - /) {
            save_profile(); container_name = profile = ""; in_size = 0
        }
        if (in_init && $0 ~ /^        name:/) container_name = $2
        if (in_init && $0 ~ /^        - name:/) in_size = ($3 == "DBMARLIN_SIZE")
        if (in_init && in_size && $0 ~ /^          value:/) {
            profile = $2; gsub(/["\047]/, "", profile); in_size = 0
        }
    }
    END { if (in_init) save_profile(); print result }
')
required_gi=$(recommended_disk_gi "${effective_size}")
if [ -z "${required_gi}" ]; then
    echo "Cannot determine a supported DBMARLIN_SIZE from the rendered dbmarlin-copy container; nothing has been applied." >&2
    exit 1
fi

# The PVC as it will be applied
pvc_storage=$(printf '%s\n' "${rendered_manifest}" | awk '
    /^kind: PersistentVolumeClaim$/ { inpvc = 1 }
    /^---$/ { inpvc = 0 }
    inpvc && $1 == "storage:" { print $2; exit }
')

if [ -z "${pvc_storage}" ]; then
    echo "Note: overlay '${overlay}' has no PVC (ephemeral storage) - skipping disk size check."
else
    pvc_gi=$(to_gi "${pvc_storage}")
    if [ -n "${pvc_gi}" ] && [ "${pvc_gi}" -lt "${required_gi}" ]; then
        echo "WARNING: the PVC requests ${pvc_storage} but the ${effective_size} profile recommends at least ${required_gi}Gi."
        echo "         Edit k8s/base/pvc.yaml before a first install, or expand the existing PVC"
        echo "         if your StorageClass supports volume expansion (PVCs can never shrink)."
    fi
fi

# Get current context and namespace
current_context=$(kubectl config current-context)
current_namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
current_namespace=${current_namespace:-default} # default to 'default' if no namespace is set

echo "Current Kubernetes context: $current_context"
echo "Current Kubernetes namespace: $current_namespace"

# Warn if a PVC already exists in the cluster and is below the recommendation
# (skipped for overlays that don't use a PVC, e.g. dev)
existing_pvc=""
if [ -n "${pvc_storage}" ]; then
    existing_pvc=$(kubectl get pvc dbmarlin-pvc -o jsonpath='{.status.capacity.storage}' 2>/dev/null)
fi
if [ -n "${existing_pvc}" ]; then
    existing_gi=$(to_gi "${existing_pvc}")
    if [ -n "${existing_gi}" ] && [ "${existing_gi}" -lt "${required_gi}" ]; then
        echo "WARNING: the existing PVC 'dbmarlin-pvc' is ${existing_pvc} but the ${effective_size} profile"
        echo "         recommends at least ${required_gi}Gi. Expand it if your StorageClass supports it."
    fi
fi

# Confirm with the user
read -r -p "Are these settings correct? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Please set the correct context and namespace then run the script again."
    exit 1
fi

echo "Deploying overlay '$overlay' with DBMARLIN_SIZE=${effective_size}..."
printf '%s\n' "${rendered_manifest}" | kubectl apply -f -
