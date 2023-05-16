# DBmarlin Dockerfiles 

Build Docker images of DBmarlin Server and DBmarlin Agent so they can be run in containers.

> ⚠️ **Warning** - The DBmarlin Server Docker image is only intended for trying out DBmarlin quickly and not for continuous production monitoring. Currently there is no way to upgrade it without loosing your monitoring data.
> 

The DBmarlin Agent Docker image can be used for production monitoring.

# Pre-built images
If you want to deploy these images without building them from the Dockerfiles here, you can pull them from Docker Hub Registry. 
```bash
docker pull dbmarlin/dbmarlin-agent:latest
docker pull dbmarlin/dbmarlin-server:latest
```

# Build your own image
## How to build the DBmarlin Server 
You need to pass in a valid DBmarlin version tag. E.g. 3.4.0
```bash
cd docker/server-docker && ./build.sh [tag] && cd ..
```
## How to build the DBmarlin Agent
```bash
cd docker/agent-docker && ./build.sh [tag] && cd ..
```
# Docker Compose
To start 1x DBmarlin server and 2x DBmarlin images there is an example docker-compose.yaml file
```bash
cd docker && docker-compose up
```

# Kubernetes Deployment
## Run the DBmarlin Server in Kubernetes
Make sure you are in the correct namespace and the run the wrapper scripts which create a Deployment with a single Pod and one Service.
```bash
kubens [namespace]
cd k8s/server-k8s && server-k8s-deploy.sh
cd k8s/server-k8s && server-k8s-service.sh
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
Make sure you are in the correct namespace and the run the wrapper script which create a Deployment with a single Pod.
```bash
kubens [namespace]
cd k8s/agent-k8s && agent-k8s-deploy.sh
```