# DBmarlin Dockerfiles 

Build Docker images of DBmarlin Server and DBmarlin Agent so they can be run in containers.

> ⚠️ **Warning** - The DBmarlin Server Docker image is only intended for trying out DBmarlin quickly and not for continuous production monitoring. Currently there is no way to upgrade it without losing your monitoring data.

> The DBmarlin Agent Docker image can be used for production monitoring.

# Pre-built images
If you want to deploy these images without building them from the Dockerfiles here, you can pull them from Docker Hub Registry.

```bash
docker pull dbmarlin/dbmarlin-agent:latest
docker pull dbmarlin/dbmarlin-server:latest
```

# Build your own image
## How to build the DBmarlin Server 
You need to pass in a valid DBmarlin version tag. E.g. 4.7.0

```bash
cd docker/server-docker && ./build.sh [tag] && cd ..
```

## How to build the DBmarlin Agent

```bash
cd docker/agent-docker && ./build.sh [tag] && cd ..
```

# Docker Compose
To start 1x DBmarlin server and 2x DBmarlin agents there is an example `docker-compose.yaml` file

```bash
cd docker && docker-compose up
```

# Kubernetes Deployment
## Run the DBmarlin Server in Kubernetes
The wrapper scripts will create a Deployment with a single Pod and one Service. The deploy scripts use **Kustomize** which is a configuration management tool for Kubernetes built-in to `kubectl`. It allows you to customize and manage Kubernetes resources declaratively, without using templates.

You can use the wrapper scripts and pass in an argument of `dev` or `prod` which determines which deployment yaml is used.

### Dev deployment

By passing in `dev` it will use `base/deployment.yaml` and `dev/deployment-patch.yaml` (any customisations should go into `dev/deployment-patch.yaml`). Note that for the Dev deployment, there is no persistence and `/opt/dbmarlin` will be mounted using `emptyDir` which is an ephemeral volume. All data will be lost on a pod restart.

Switch to the correct namespace and context and call the wrapper script.

```bash
cd k8s/server-k8s && server-k8s-deploy.sh dev
```

### Prod deployment

By passing in `prod` it will use `base/deployment.yaml` , `prod/deployment-patch.yaml` and `prod/pvc.yaml` (any customisations should go into `prod/deployment-patch.yaml` and `prod/pvc.yaml`).

To create a persistent volume claim so that `/opt/dbmarlin` will be mounted on the persistent volume, the file `prod/pvc.yaml` will need to be customised to use the `storageClassName` supported by your Kubernetes platform and the volume size should match the [hardware requirements](https://docs.dbmarlin.com/docs/getting-started/server-installation/hardware-requirements/).

Switch to the correct namespace and context and call the wrapper script.

```bash
cd k8s/server-k8s && server-k8s-deploy.sh prod
```

## Run the DBmarlin Agent in Kubernetes

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
