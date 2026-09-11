# DBmarlin Dockerfiles

Build Docker images of DBmarlin Server and DBmarlin Agent so they can be run in containers.

> **Docker persistence:** The supplied Docker run script and Docker Compose example do not configure persistent storage. Removing or replacing the server container deletes its monitoring data. Use these examples for evaluation; preserving data across container replacement requires persistent storage and a tested upgrade procedure. Stopping and restarting the same container retains its data.

The DBmarlin Agent Docker image can be used for production monitoring.

## Pre-built images

If you want to deploy these images without building them from the Dockerfiles here, you can pull them from Docker Hub Registry.

```bash
docker pull dbmarlin/dbmarlin-agent:latest
docker pull dbmarlin/dbmarlin-server:latest
```

## Build your own image

### How to build the DBmarlin Server

You need to pass in a valid DBmarlin version tag. E.g. 6.6.0

```bash
cd docker/server-docker && ./build.sh [tag] && cd ..
```

### How to build the DBmarlin Agent

```bash
cd docker/agent-docker && ./build.sh [tag] && cd ..
```

## Docker Compose

To start 1x DBmarlin server and 2x DBmarlin agents there is an example `docker-compose.yml` file. The server data is stored inside its container; the Docker persistence warning above applies.

```bash
cd docker && docker-compose up
```

## Kubernetes Deployment

### Run the DBmarlin Server in Kubernetes

The DBmarlin server is deployed as a StatefulSet using **Kustomize**, which is a configuration management tool for Kubernetes built-in to `kubectl`. There are overlays for common platforms (local-path, EKS, AKS, GKE, Civo, OpenShift) plus a `dev` overlay with no persistence (`emptyDir` - all data is lost on pod restart).

Switch to the correct namespace and context and call the wrapper script with an overlay name, for example:

```bash
cd k8s/server-k8s && ./server-k8s-deploy.sh stateful-localpath
```

The profile size (`XSmall`, `Small`, `Medium`, `Large` or `XLarge`, default `Small`) can be set with the `DBMARLIN_SIZE` env var - it selects the profile passed to `configure.sh` and sets the matching CPU/memory requests and limits. Disk is not resized automatically; the script warns if the PVC is smaller than the profile recommends.

```bash
DBMARLIN_SIZE=Medium ./server-k8s-deploy.sh stateful-eks
```

See [k8s/server-k8s/README.md](k8s/server-k8s/README.md) for the full list of overlays, storage requirements and upgrade instructions.

### Run the DBmarlin Agent in Kubernetes

Change the env variables in `agent-k8s-deploy.yaml` to suitable values.

```yaml
        env:
        - name: DBMARLIN_AGENT_NAME
          value: "k8s-test-agent"
        - name: DBMARLIN_ARCHIVER_URL
          value: "http://dbmarlin-server/archiver"
        - name: DBMARLIN_API_KEY
```

Switch to the correct namespace and context and then run the wrapper script which create a Deployment with a single Pod.

```bash
cd k8s/agent-k8s && agent-k8s-deploy.sh
```
