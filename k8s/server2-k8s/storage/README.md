# DBmarlin Kubernetes - storage options

This contains different storage options. Working with local storage to start with.

```bash
# from this directory
kubectl apply -k k8s/overlays/standalone-localpath
```

For the StatefulSet version:

```bash
kubectl apply -k k8s/overlays/stateful-localpath
```

## Important assumptions

- The DBmarlin image contains `/dbmarlin-install/dbmarlin`.
- DBmarlin runs from `/opt/dbmarlin`.
- The preserved files are currently assumed to be:
  - `/opt/dbmarlin/.htpasswd`
  - `/opt/dbmarlin/nginx/conf/auth.conf`
  - `/opt/dbmarlin/nginx/conf/ssl.conf`
- The PVC is mounted at `/opt/dbmarlin`.
- The local lab uses the `local-path` StorageClass.

Adjust the preserved file paths if your image stores them elsewhere.

## Suggested workflow

1. Install local-path provisioner if needed.
2. Apply one overlay.
3. Verify DBmarlin starts.
4. Change the image tag in the overlay patch.
5. Re-apply the overlay to test an upgrade.

```bash
kubectl apply -k k8s/overlays/standalone-localpath
kubectl get pods,pvc,svc
```
