# DBmarlin Server on Kubernetes

Kustomize layout for deploying DBmarlin Server to Kubernetes as a StatefulSet,
with overlays for common cloud providers.

## Layout

```bash
k8s/
├── base/                      # PVC + LoadBalancer Service (shared by all overlays)
├── components/
│   ├── statefulset/           # StatefulSet + headless Service (self-configuring init container)
│   ├── size-*/                # Optional: profile size (env var + CPU/memory), xsmall..xlarge
│   ├── nonroot/               # Optional: run everything as UID 1001 (restricted PSS clusters)
│   ├── service-aws-nlb-internal/ # Internal NLB (default in stateful-eks)
│   ├── service-aws-nlb-internet/ # Optional: internet-facing NLB annotation
│   └── service-nodeport/      # Optional: NodePort instead of LoadBalancer (no LB cost)
└── overlays/
    ├── stateful-localpath     # local-path StorageClass (kubeadm/Proxmox labs)
    ├── stateful-eks           # gp3 (AWS EKS)
    ├── stateful-aks           # managed-csi (Azure AKS)
    ├── stateful-gke           # standard-rwo (Google GKE)
    ├── stateful-civo          # civo-volume (Civo)
    ├── stateful-openshift     # ibmc-vpc-block-10iops-tier (IBM Cloud ROKS / OpenShift)
    └── dev                    # emptyDir (no PVC), local registry image
storage/                       # Optional StorageClass / PersistentVolume examples
```

## Quick start

```bash
# from this directory
./server-k8s-deploy.sh stateful-localpath

# or directly with kubectl
kubectl apply -k k8s/overlays/stateful-localpath
```

## Profile size (DBMARLIN_SIZE)

All overlays run `configure.sh` with the profile size taken from the `DBMARLIN_SIZE`
env var on the pod (default `Small`). Each profile has matching
[hardware requirements](https://docs.dbmarlin.com/docs/getting-started/server-installation/hardware-requirements/):

| Profile | Monitored instances | CPU | Memory | Recommended disk |
|---------|---------------------|-----|--------|------------------|
| XSmall  | 1                   | 1   | 2Gi    | 20Gi             |
| Small   | <5                  | 1   | 4Gi    | 100Gi            |
| Medium  | <20                 | 2   | 8Gi    | 400Gi            |
| Large   | <50                 | 4   | 16Gi   | 1Ti              |
| XLarge  | <100                | 8   | 32Gi   | 2Ti              |

The `size-*` components set the env var **and** the matching CPU/memory
requests/limits together. To pick a size at deploy time:

```bash
DBMARLIN_SIZE=Medium ./server-k8s-deploy.sh stateful-eks
```

If you apply an overlay directly with `kubectl apply -k`, add the size component
to the overlay's `kustomization.yaml` instead:

```yaml
components:
  - ../../components/statefulset
  - ../../components/size-medium
```

Without a size component, the StatefulSet defaults match the Small profile.

**Disk is not changed automatically.** PVCs can never shrink and not every
StorageClass supports expansion, so size the PVC yourself in `k8s/base/pvc.yaml`
before the first install. The deploy script warns when the PVC (rendered or
already in the cluster) is smaller than the recommendation for the chosen profile.
The check reads the profile from the rendered init container, so it also covers
size components added directly to an overlay. Rendering failures stop deployment.

Changing the size of a running install: re-deploy with the new size, then delete
the pod (`kubectl delete pod dbmarlin-server-0`) so the new resources and
`configure.sh` run take effect.

To remove a deployment (WARNING: deletes the PVC and its data):

```bash
./server-k8s-remove-all.sh stateful-localpath
```

## Exposing the UI (Service)

The base Service is `type: LoadBalancer` on port 9090, so each cloud provisions
its native load balancer.

**AWS EKS:** `stateful-eks` explicitly requests an internal NLB through the
`service-aws-nlb-internal` component. Its private subnets need the
`kubernetes.io/role/internal-elb` tag for subnet discovery. If provisioning is
pending, check subnet tags and controller events; use port-forwarding to reach
DBmarlin while resolving the load balancer setup.

A fresh DBmarlin installation has
[authentication disabled](https://docs.dbmarlin.com/docs/getting-started/access-control/authentication/).
Before enabling public access, configure authentication and HTTPS while the
service is private. To opt in to a public NLB, replace
`../../components/service-aws-nlb-internal` with
`../../components/service-aws-nlb-internet` in the EKS overlay's components list.
The public subnets need the `kubernetes.io/role/elb` tag. Other cloud overlays
still use their platform's LoadBalancer defaults; check exposure before deploying.

For an existing NLB, changing its scheme may require recreating the Service/load
balancer and changes its address. Plan that separately; re-applying these
manifests alone is not proof that an existing public endpoint has become private.

**Avoiding load balancer cost on test clusters:** an NLB costs roughly
$18-30/month depending on region and scheme (internet-facing adds ~$3.65/month
per AZ for public IPv4). To skip it, deploy with a NodePort Service instead:

```bash
DBMARLIN_SERVICE=nodeport ./server-k8s-deploy.sh stateful-eks
```

or add the component to your overlay's `kustomization.yaml`:

```yaml
components:
  - ../../components/statefulset
  - ../../components/service-nodeport
```

Then reach the UI on any node's IP at the allocated port (`kubectl get svc
dbmarlin-service`), provided your node security group / firewall allows it -
or with no open ports at all:

```bash
kubectl port-forward svc/dbmarlin-service 9090:9090
# then browse http://localhost:9090
```

Switching an existing install between LoadBalancer and NodePort is safe: the
cloud load balancer is created or deleted on re-apply and the data is untouched.
Note that re-applying with `type: NodePort` on a Service that was LoadBalancer
keeps the same node port, and switching back provisions a new load balancer
with a new address.

## How it works

All overlays deploy a StatefulSet (`updateStrategy: OnDelete`): the init container
copies the install from the image into `/opt/dbmarlin`, fixes ownership, and runs
`configure.sh` (ports 9090/9080/9070, size via the `DBMARLIN_SIZE` env var, `-u`
for upgrades). Customer-created files on the PVC (`.htpasswd`,
`nginx/conf/auth.conf`, `nginx/conf/ssl.conf`) are not part of the image, so they
survive upgrades untouched. Pod update only happens when you delete the pod,
giving you explicit control over upgrade timing.

A single replica is backed by a shared `dbmarlin-pvc` (ReadWriteOnce). Do not
scale above 1 replica.

The init container runs as root to `chown` the volume. On clusters that enforce
the `restricted` Pod Security Standard, add the `nonroot` component to your
overlay's `kustomization.yaml` (after the statefulset component) to run everything
as the image's dbmarlin user (UID 1001), with `fsGroup` making the volume writable
instead of `chown`:

```yaml
components:
  - ../../components/statefulset
  - ../../components/nonroot
```

Do not combine it with the `stateful-openshift` overlay - OpenShift's restricted
SCC assigns its own arbitrary UID and rejects pods requesting a fixed one; that
overlay already carries its own equivalent patch.

## Upgrading DBmarlin

1. Back up the database and configuration and check the release's upgrade requirements.
2. Edit the `images:` section in your overlay's `kustomization.yaml` and change `newTag`.
3. Re-apply using the same size and service settings as the existing installation.
   Environment overrides are temporary and must be supplied on **every** apply.
   For example, if installed with Medium and NodePort:

   ```bash
   DBMARLIN_SIZE=Medium DBMARLIN_SERVICE=nodeport ./server-k8s-deploy.sh stateful-eks
   ```

   Prefer adding the chosen size/service components to your overlay for a lasting
   configuration. Plain `kubectl apply -k k8s/overlays/<overlay>` is appropriate
   only when all those choices are recorded there. Otherwise it restores the
   overlay defaults, which can reduce resources or create a load balancer.
4. Only after the apply succeeds, delete the pod to trigger the update:
   `kubectl delete pod dbmarlin-server-0`.
5. Check the init-container logs, pod readiness, and existing monitoring data.

## Migrating from the old prod/dev Deployment

The previous layout used `k8s/prod` and `k8s/dev` Deployments. The new layout uses
`k8s/overlays/stateful-*` and `k8s/overlays/dev` StatefulSets. The same procedure
also applies to any experimental `standalone-*` Deployment overlays.

For a persistent production installation, prepare the migration before stopping
the existing server:

1. Back up the database and configuration, and verify the backup can be restored.
2. Inspect the existing claim and running image in the correct context/namespace:

   ```bash
   kubectl get pvc dbmarlin-pvc -o custom-columns=NAME:.metadata.name,CLASS:.spec.storageClassName,REQUEST:.spec.resources.requests.storage,CAPACITY:.status.capacity.storage
   kubectl get deployment dbmarlin-server -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

3. Choose the matching cloud overlay and edit its `storageclass-patch.yaml` to
   preserve the existing claim's storage class. **The old prod default was `gp2`;
   the new EKS default is `gp3`.** Set the EKS patch to `gp2` when reusing a `gp2`
   claim. A bound PVC's storage class cannot be changed in place. Do not delete
   the claim to work around an apply error; moving storage classes requires a
   separate data migration.
4. Set `k8s/base/pvc.yaml` to the existing claim's requested size, including any
   previous expansion. Do not apply the default 20Gi over a larger claim. Plan
   any further expansion separately.
5. Set the overlay image tag to the currently running DBmarlin version, and
   preserve the intended size and service settings. Migrate the workload first;
   upgrade the application version separately. Render the overlay with
   `kubectl kustomize k8s/overlays/<overlay>` and check those settings before applying.

Both workloads reference `dbmarlin-pvc`. `kubectl apply` does not remove the old
Deployment, and ReadWriteOnce does not prevent two pods on the same node from
writing to the volume. Stop and remove the old workload, waiting for its pods to
terminate, before applying the new StatefulSet:

```bash
# Remove only the Deployment and wait for its pods; retain dbmarlin-pvc.
kubectl delete deployment dbmarlin-server --cascade=foreground --wait=true

# Apply the prepared overlay, supplying any size/service overrides as above.
./server-k8s-deploy.sh stateful-eks
```

Do not use `server-k8s-remove-all.sh` for migration: it deletes the PVC too.
If apply fails, inspect the error and existing resources before proceeding;
an apply can create some resources even when another resource is rejected.

After migrating, the pod is named `dbmarlin-server-0` and upgrades require
deleting the pod (see above) rather than happening automatically on re-apply.
Verify readiness and the existing monitoring data before resuming normal use.

The old `dev` overlay used `emptyDir`. Deleting its pod loses its data; export
anything needed before replacing that Deployment with the new dev StatefulSet.

## Storage

Each overlay patches the PVC's `storageClassName`:

| Overlay            | StorageClass                 | Notes                                                                          |
|--------------------|------------------------------|--------------------------------------------------------------------------------|
| stateful-localpath | `local-path`                 | Requires the local-path provisioner                                            |
| stateful-eks       | `gp3`                        | Must exist in the cluster first - see the gp3 examples in `storage/`           |
| stateful-aks       | `managed-csi`                | Built in to AKS                                                                |
| stateful-gke       | `standard-rwo`               | Built in to GKE                                                                |
| stateful-civo      | `civo-volume`                | Built in to Civo                                                               |
| stateful-openshift | `ibmc-vpc-block-10iops-tier` | Built in to IBM Cloud ROKS (VPC); classic clusters use `ibmc-block-gold` etc.  |

The `example-*.yaml` files in `storage/` are examples only - nothing deploys them
automatically. Review, adapt and `kubectl apply -f` them by hand if you need them:

- `example-gp3-storageclass-eks.yaml` - a `gp3` StorageClass for standard EKS
  clusters running the EBS CSI driver add-on (`ebs.csi.aws.com`).
- `example-gp3-storageclass-eks-automode.yaml` - the same for EKS Auto Mode
  clusters, which use a different provisioner (`ebs.csi.eks.amazonaws.com`).
  Apply one or the other, not both - picking the wrong provisioner leaves PVCs
  stuck in `Pending`.
- `example-storageclass-local.yaml` and `example-persistentvolume.yaml` - a manual
  (no-provisioner) StorageClass and node-pinned PersistentVolume for bare-metal
  clusters without a provisioner.

## OpenShift notes (stateful-openshift)

OpenShift's `restricted` SCC runs all containers as an arbitrary non-root UID from
the namespace's assigned range, so the overlay patches the init container to drop
the root `securityContext` and run the copy and `configure.sh` directly as the pod
user - no `chown`/`runuser`, and no extra SCC or service account is needed. Edit
`storageclass-patch.yaml` if your cluster is not IBM Cloud ROKS on VPC. To expose
the UI with an OpenShift Route instead of the LoadBalancer Service:

```bash
oc create route edge dbmarlin --service=dbmarlin-service --port=9090
```

## Important assumptions

- The DBmarlin image contains `/dbmarlin-install/dbmarlin`.
- DBmarlin runs from `/opt/dbmarlin`, which is where the PVC is mounted.
- Tomcat listens on 9080 (probes), nginx on 9090 (Service), PostgreSQL on 9070.

## Suggested test workflow

The dev overlay uses `imagePullPolicy: Always` for both the init and application
containers. After building and pushing a new `localhost:5000/dbmarlin-server:latest`
image, delete the dev pod to use it. The local registry must be reachable when
containers start. Replacing the dev pod deletes its `emptyDir` data.

1. Install the local-path provisioner if needed.
2. Apply one overlay and verify DBmarlin starts: `kubectl get pods,pvc,svc`.
3. Follow the upgrade steps above, retaining size/service settings, and verify
   that monitoring data and authentication settings survive the pod replacement.
