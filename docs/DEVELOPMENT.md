# CPTM8 Development Guide

**Date:** November 19, 2025
**Last Updated:** November 19, 2025
**Version:** 1.0

## Overview

This guide provides comprehensive instructions for setting up a local development environment, managing Kubernetes resources, and following best practices for CPTM8 platform development.

## Prerequisites

### Required Tools

#### 1. Container Runtime
- **Docker Desktop** 4.25+ (macOS/Windows) or **Docker Engine** 24.0+ (Linux)
- Minimum resources: 4 CPU cores, 8GB RAM, 20GB disk space
- Enable Kubernetes in Docker Desktop (optional)

```bash
# Verify Docker installation
docker --version  # Should be 24.0+
docker info | grep "Server Version"

# Check resource allocation
docker system info | grep -E "CPUs|Total Memory"
```

#### 2. Kubernetes Development Tools
- **kubectl** 1.28+
- **kind** (Kubernetes in Docker) 0.20+
- **kustomize** 5.0+
- **Helm** 3.13+

```bash
# Install kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
kind version

# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
kustomize version

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

#### 3. Cloud CLI Tools (for staging/production)

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# Configure AWS credentials
aws configure
# AWS Access Key ID: [your key]
# AWS Secret Access Key: [your secret]
# Default region name: eu-south-2
# Default output format: json

# eksctl (EKS cluster management)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```

#### 4. Development Utilities
- **git** 2.40+
- **jq** 1.6+ (JSON processor)
- **yq** 4.30+ (YAML processor)
- **age** 1.1+ (encryption for SOPS)

```bash
# Install jq
sudo apt-get install jq -y
jq --version

# Install yq
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /tmp/yq
sudo install /tmp/yq /usr/local/bin/yq
yq --version

# Install age (for SOPS encryption)
wget https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
tar -xzf age-v1.1.1-linux-amd64.tar.gz
sudo mv age/age /usr/local/bin/
sudo mv age/age-keygen /usr/local/bin/
age --version

# Install SOPS
wget https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
sops --version
```

### Optional Tools

```bash
# k9s - Kubernetes CLI dashboard
wget https://github.com/derailed/k9s/releases/download/v0.28.2/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
k9s version

# kubectx/kubens - Context and namespace switching
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# stern - Multi-pod log tailing
wget https://github.com/stern/stern/releases/download/v1.28.0/stern_1.28.0_linux_amd64.tar.gz
tar -xzf stern_1.28.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/
stern --version

# kubetail - Alternative log tailing
curl -LO https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
chmod +x kubetail
sudo mv kubetail /usr/local/bin/

# kubecolor - Colorized kubectl output
go install github.com/hidetatz/kubecolor/cmd/kubecolor@latest
alias kubectl="kubecolor"
```

## Local Development Setup

### 1. Clone Repository

```bash
# Clone the Kubernetes configuration repository
cd ~/Documents/Self-Employed/Securetivity/CPT/
git clone <repository-url> Kubernetes
cd Kubernetes

# Verify structure
ls -la
# Expected: bases/ overlays/ docs/ CLAUDE.md README.md
```

### 2. Create Kind Cluster

```bash
# Create Kind cluster configuration
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cptm8-dev
nodes:
- role: control-plane
  extraPortMappings:
  # Frontend services
  - containerPort: 30000
    hostPort: 3000
    protocol: TCP  # DashboardM8
  - containerPort: 30001
    hostPort: 4000
    protocol: TCP  # SocketM8

  # API services
  - containerPort: 30002
    hostPort: 8000
    protocol: TCP  # ASMM8
  - containerPort: 30003
    hostPort: 8001
    protocol: TCP  # NAABUM8
  - containerPort: 30004
    hostPort: 8002
    protocol: TCP  # KATANAM8
  - containerPort: 30005
    hostPort: 8003
    protocol: TCP  # NUM8

  # Data services
  - containerPort: 30010
    hostPort: 5432
    protocol: TCP  # PostgreSQL
  - containerPort: 30011
    hostPort: 27017
    protocol: TCP  # MongoDB
  - containerPort: 30012
    hostPort: 5672
    protocol: TCP  # RabbitMQ
  - containerPort: 30013
    hostPort: 15672
    protocol: TCP  # RabbitMQ Management

  # Observability
  - containerPort: 30020
    hostPort: 9200
    protocol: TCP  # OpenSearch
  - containerPort: 30021
    hostPort: 3010
    protocol: TCP  # Grafana

  # Resource configuration
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "environment=development,tier=local"

  # Mount host directories for development
  extraMounts:
  - hostPath: /tmp/cptm8-data
    containerPath: /data
  - hostPath: /tmp/cptm8-logs
    containerPath: /logs
EOF

# Create the cluster
kind create cluster --config kind-config.yaml

# Verify cluster creation
kubectl cluster-info --context kind-cptm8-dev
kubectl get nodes

# Expected output:
# NAME                      STATUS   ROLES           AGE   VERSION
# cptm8-dev-control-plane   Ready    control-plane   1m    v1.28.0
```

### 3. Set Up Local Container Registry (Optional)

```bash
# Create local registry for development images
docker run -d -p 5001:5000 --name kind-registry registry:2

# Connect registry to Kind network
docker network connect kind kind-registry

# Configure Kind to use local registry
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5001"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
```

### 4. Deploy Base Infrastructure

```bash
# Create namespace
kubectl create namespace cptm8-dev

# Set as default namespace
kubens cptm8-dev

# Deploy data tier first (PostgreSQL, MongoDB, RabbitMQ, OpenSearch)
echo "Deploying PostgreSQL..."
kubectl apply -k bases/postgres/
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

echo "Deploying MongoDB..."
kubectl apply -k bases/mongodb/
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=300s

echo "Deploying RabbitMQ..."
kubectl apply -k bases/rabbitmq/
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s

echo "Deploying OpenSearch..."
kubectl apply -k bases/opensearch/
kubectl wait --for=condition=ready pod -l app=opensearch --timeout=300s

# Verify data tier
kubectl get pods -l tier=data
kubectl get pvc
kubectl get services

# Expected: All pods running, PVCs bound, services created
```

### 5. Deploy Application Services

```bash
# Deploy in dependency order
echo "Deploying ASMM8..."
kubectl apply -k bases/asmm8/
kubectl wait --for=condition=ready pod -l app=asmm8 --timeout=180s

echo "Deploying NAABUM8..."
kubectl apply -k bases/naabum8/
kubectl wait --for=condition=ready pod -l app=naabum8 --timeout=180s

echo "Deploying KATANAM8..."
kubectl apply -k bases/katanam8/
kubectl wait --for=condition=ready pod -l app=katanam8 --timeout=180s

echo "Deploying NUM8..."
kubectl apply -k bases/num8/
kubectl wait --for=condition=ready pod -l app=num8 --timeout=180s

echo "Deploying OrchestratorM8..."
kubectl apply -k bases/orchestratorm8/
kubectl wait --for=condition=ready pod -l app=orchestratorm8 --timeout=180s

echo "Deploying ReportingM8..."
kubectl apply -k bases/reportingm8/
kubectl wait --for=condition=ready pod -l app=reportingm8 --timeout=180s

# Verify application tier
kubectl get pods -l tier=application
kubectl get services -l tier=application
```

### 6. Deploy Frontend Services

```bash
echo "Deploying DashboardM8..."
kubectl apply -k bases/dashboardm8/
kubectl wait --for=condition=ready pod -l app=dashboardm8 --timeout=180s

echo "Deploying SocketM8..."
kubectl apply -k bases/socketm8/
kubectl wait --for=condition=ready pod -l app=socketm8 --timeout=180s

# Verify frontend tier
kubectl get pods -l tier=frontend
kubectl get services -l tier=frontend
```

### 7. Deploy Observability Stack

```bash
echo "Deploying Vector..."
kubectl apply -k bases/vector/
kubectl wait --for=condition=ready pod -l app=vector --timeout=120s

# Verify observability
kubectl get daemonset vector
kubectl get pods -l app=vector
```

### 8. Verify Deployment

```bash
# Check all pods are running
kubectl get pods --all-namespaces

# Check services
kubectl get services

# Check persistent volumes
kubectl get pv,pvc

# Port-forward for local access (in separate terminals)
kubectl port-forward svc/dashboardm8 3000:3000 &
kubectl port-forward svc/socketm8 4000:4000 &
kubectl port-forward svc/asmm8 8000:8000 &
kubectl port-forward svc/postgres 5432:5432 &
kubectl port-forward svc/rabbitmq 15672:15672 &

# Access services
echo "DashboardM8: http://localhost:3000"
echo "SocketM8: ws://localhost:4000"
echo "ASMM8 API: http://localhost:8000"
echo "PostgreSQL: localhost:5432"
echo "RabbitMQ Management: http://localhost:15672 (guest/guest)"
```

## Development Workflows

### 1. Building and Deploying Application Changes

#### Go Microservices (ASMM8, NAABUM8, etc.)

```bash
# Navigate to service directory
cd ../ASMM8  # or other service

# Build Docker image
docker build -t asmm8:dev .

# Tag for local registry (if using)
docker tag asmm8:dev localhost:5001/asmm8:dev
docker push localhost:5001/asmm8:dev

# Or load directly into Kind cluster
kind load docker-image asmm8:dev --name cptm8-dev

# Update Kubernetes deployment
cd ../Kubernetes
kubectl set image deployment/asmm8 asmm8=asmm8:dev

# Or apply with updated manifests
kubectl apply -k bases/asmm8/

# Watch rollout
kubectl rollout status deployment/asmm8

# Verify deployment
kubectl get pods -l app=asmm8
kubectl describe pod -l app=asmm8 | grep Image

# Check logs
kubectl logs -f deployment/asmm8
```

#### Frontend Services (DashboardM8, SocketM8)

```bash
# Navigate to frontend directory
cd ../DashboardM8

# Install dependencies
npm install

# Run locally for rapid development
npm run dev
# Access at http://localhost:3000

# Build production image
docker build -t dashboardm8:dev .

# Deploy to Kind
kind load docker-image dashboardm8:dev --name cptm8-dev
kubectl set image deployment/dashboardm8 dashboardm8=dashboardm8:dev
kubectl rollout status deployment/dashboardm8
```

### 2. Configuration Changes

#### Update ConfigMaps

```bash
# Edit ConfigMap
kubectl edit configmap asmm8-config

# Or update from file
kubectl create configmap asmm8-config --from-file=config.yaml --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to pick up changes
kubectl rollout restart deployment/asmm8

# Watch restart
kubectl rollout status deployment/asmm8
```

#### Update Secrets

```bash
# Create secret from literal values
kubectl create secret generic asmm8-secret \
  --from-literal=db-password='newpassword' \
  --from-literal=api-key='newapikey' \
  --dry-run=client -o yaml | kubectl apply -f -

# Or from files
kubectl create secret generic asmm8-secret \
  --from-file=db-password=./db-password.txt \
  --from-file=api-key=./api-key.txt \
  --dry-run=client -o yaml | kubectl apply -f -

# SOPS encrypted secrets
sops -d overlays/dev/secrets/asmm8-secret.yaml | kubectl apply -f -

# Restart pods
kubectl rollout restart deployment/asmm8
```

### 3. Database Management

#### PostgreSQL

```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -- psql -U cpt_dbuser -d cptm8

# Run SQL commands
SELECT * FROM cptm8domain;
SELECT * FROM cptm8hostname LIMIT 10;

# Exit
\q

# Execute SQL from file
kubectl exec -i postgres-0 -- psql -U cpt_dbuser -d cptm8 < schema.sql

# Backup database
kubectl exec -t postgres-0 -- pg_dump -U cpt_dbuser cptm8 > backup-$(date +%Y%m%d).sql

# Restore database
kubectl exec -i postgres-0 -- psql -U cpt_dbuser cptm8 < backup-20251119.sql

# Check replication status (if using replicas)
kubectl exec postgres-0 -- psql -U cpt_dbuser -c "SELECT * FROM pg_stat_replication;"
```

#### MongoDB

```bash
# Connect to MongoDB
kubectl exec -it mongodb-0 -- mongosh

# Switch to database
use cptm8

# Query collections
db.scan_results.find().limit(5)
db.audit_logs.countDocuments()

# Exit
exit

# Backup MongoDB
kubectl exec mongodb-0 -- mongodump --archive --gzip --db cptm8 > mongodb-backup-$(date +%Y%m%d).gz

# Restore MongoDB
kubectl exec -i mongodb-0 -- mongorestore --archive --gzip --db cptm8 < mongodb-backup-20251119.gz

# Check replica set status
kubectl exec mongodb-0 -- mongosh --eval "rs.status()"
```

#### RabbitMQ

```bash
# Access RabbitMQ Management UI
kubectl port-forward svc/rabbitmq 15672:15672
# Open http://localhost:15672 (guest/guest)

# List queues via CLI
kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages consumers

# List exchanges
kubectl exec rabbitmq-0 -- rabbitmqctl list_exchanges name type durable

# List bindings
kubectl exec rabbitmq-0 -- rabbitmqctl list_bindings

# Purge queue
kubectl exec rabbitmq-0 -- rabbitmqctl purge_queue qasmm8

# Check cluster status
kubectl exec rabbitmq-0 -- rabbitmqctl cluster_status

# Check node health
kubectl exec rabbitmq-0 -- rabbitmq-diagnostics check_running
kubectl exec rabbitmq-0 -- rabbitmq-diagnostics check_local_alarms
```

### 4. Monitoring and Debugging

#### View Logs

```bash
# Single pod logs
kubectl logs -f asmm8-5d7c8b6f4-xyz12

# All pods for a deployment
kubectl logs -f deployment/asmm8

# Previous container logs (after crash)
kubectl logs asmm8-5d7c8b6f4-xyz12 --previous

# Multi-pod logs with stern
stern asmm8

# Logs with timestamps
kubectl logs asmm8-5d7c8b6f4-xyz12 --timestamps

# Logs from specific time range
kubectl logs asmm8-5d7c8b6f4-xyz12 --since=1h
kubectl logs asmm8-5d7c8b6f4-xyz12 --since-time=2025-11-19T10:00:00Z

# Follow logs from multiple containers
kubetail asmm8

# Save logs to file
kubectl logs deployment/asmm8 > asmm8-logs-$(date +%Y%m%d-%H%M%S).log
```

#### Debug Pods

```bash
# Describe pod for events
kubectl describe pod asmm8-5d7c8b6f4-xyz12

# Execute commands in running pod
kubectl exec -it asmm8-5d7c8b6f4-xyz12 -- /bin/sh

# Check environment variables
kubectl exec asmm8-5d7c8b6f4-xyz12 -- env | sort

# Check filesystem
kubectl exec asmm8-5d7c8b6f4-xyz12 -- ls -la /app

# Copy files from pod
kubectl cp asmm8-5d7c8b6f4-xyz12:/app/config.yaml ./config-from-pod.yaml

# Copy files to pod
kubectl cp ./local-config.yaml asmm8-5d7c8b6f4-xyz12:/tmp/config.yaml

# Port forward for debugging
kubectl port-forward asmm8-5d7c8b6f4-xyz12 9999:8000
curl http://localhost:9999/health

# Create debug container (Ephemeral Containers)
kubectl debug -it asmm8-5d7c8b6f4-xyz12 --image=busybox --target=asmm8
```

#### Resource Usage

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods
kubectl top pods --containers
kubectl top pods -l app=asmm8

# Resource requests vs limits
kubectl describe nodes | grep -A5 "Allocated resources"

# Check resource quotas
kubectl describe resourcequota -n cptm8-dev

# Check limit ranges
kubectl describe limitrange -n cptm8-dev
```

#### Network Debugging

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgres

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://asmm8:8000/health

# Check network policies
kubectl get networkpolicies
kubectl describe networkpolicy default-deny-all

# Test service endpoints
kubectl get endpoints asmm8
kubectl describe service asmm8

# Check ingress
kubectl get ingress
kubectl describe ingress cptm8-ingress
```

### 5. Testing

#### Unit Tests

```bash
# Run tests locally before building
cd ../ASMM8
go test ./... -v
go test ./pkg/db8 -v -cover
go test -race ./...

# Run specific test
go test -v -run TestGetAllDomain ./pkg/db8

# Generate coverage report
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
```

#### Integration Tests

```bash
# Deploy test environment
kubectl apply -k overlays/dev/

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all --timeout=300s

# Run integration tests
cd ../ASMM8/tests
go test -v -tags=integration ./...

# Or use external test suite
cd ../Kubernetes/tests
./run-integration-tests.sh
```

#### End-to-End Tests

```bash
# Deploy full stack
kubectl apply -k overlays/dev/

# Run E2E tests
cd tests/e2e
npm install
npm run test:e2e

# Or with specific tests
npm run test:e2e -- --spec "scan-workflow.spec.js"
```

### 6. Cleanup and Reset

```bash
# Delete specific service
kubectl delete -k bases/asmm8/

# Delete all resources in namespace
kubectl delete all --all -n cptm8-dev

# Delete namespace (removes everything)
kubectl delete namespace cptm8-dev

# Delete and recreate namespace
kubectl delete namespace cptm8-dev
kubectl create namespace cptm8-dev

# Complete cluster reset
kind delete cluster --name cptm8-dev
kind create cluster --config kind-config.yaml

# Clean up Docker images
docker system prune -a --volumes
```

## Environment-Specific Deployment

### Development (Kind)

```bash
# Already covered in Local Development Setup above
kubectl apply -k overlays/dev/
```

### Staging (AWS EKS)

```bash
# Create EKS cluster
eksctl create cluster -f eksctl-staging.yaml

# Or manually
eksctl create cluster \
  --name cptm8-staging \
  --region eu-south-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed

# Configure kubectl context
aws eks update-kubeconfig --region eu-south-2 --name cptm8-staging

# Verify connection
kubectl cluster-info
kubectl get nodes

# Deploy NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml

# Wait for load balancer
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Get load balancer DNS
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Configure ECR access
aws ecr get-login-password --region eu-south-2 | docker login --username AWS --password-stdin 507745009364.dkr.ecr.eu-south-2.amazonaws.com

# Create ECR token refresh CronJob
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ecr-token-refresh
  namespace: cptm8-staging
spec:
  schedule: "0 */8 * * *"  # Every 8 hours
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: ecr-refresh-sa
          containers:
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              TOKEN=\$(aws ecr get-login-password --region eu-south-2)
              kubectl delete secret regcred --ignore-not-found
              kubectl create secret docker-registry regcred \\
                --docker-server=507745009364.dkr.ecr.eu-south-2.amazonaws.com \\
                --docker-username=AWS \\
                --docker-password=\${TOKEN}
          restartPolicy: OnFailure
EOF

# Deploy staging environment
kubectl apply -k overlays/staging/

# Verify deployment
kubectl get pods -n cptm8-staging
kubectl get ingress -n cptm8-staging
```

### Production (AWS EKS with HA)

```bash
# Create production EKS cluster
eksctl create cluster \
  --name cptm8-prod \
  --region eu-south-2 \
  --nodegroup-name prod-workers \
  --node-type t3.large \
  --nodes 6 \
  --nodes-min 3 \
  --nodes-max 10 \
  --zones eu-south-2a,eu-south-2b,eu-south-2c \
  --managed

# Configure kubectl context
aws eks update-kubeconfig --region eu-south-2 --name cptm8-prod
kubectx cptm8-prod

# Deploy production environment
kubectl apply -k overlays/prod/

# Verify high availability
kubectl get nodes -o wide
kubectl get pods -n cptm8-prod -o wide

# Check pod distribution across zones
kubectl get pods -n cptm8-prod -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,ZONE:.spec.affinity

# Monitor rollout
kubectl rollout status deployment/asmm8 -n cptm8-prod
```

## Troubleshooting

### Common Issues

#### 1. Pods Stuck in Pending State

```bash
# Check pod events
kubectl describe pod <pod-name>

# Common causes:
# - Insufficient resources
kubectl top nodes
kubectl describe nodes | grep -A5 "Allocated resources"

# - PVC not bound
kubectl get pvc
kubectl describe pvc <pvc-name>

# - Node selector/affinity issues
kubectl get nodes --show-labels
kubectl describe pod <pod-name> | grep -A10 "Node-Selectors\|Affinity"

# Solution: Adjust resource requests or add more nodes
```

#### 2. CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> --previous

# Check events
kubectl describe pod <pod-name>

# Common causes:
# - Application error on startup
# - Missing configuration
# - Failed health checks
# - Resource limits too low

# Debug with increased verbosity
kubectl logs <pod-name> --previous --tail=100

# Temporary fix: Disable liveness probe to investigate
kubectl patch deployment <deployment-name> --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"}]'
```

#### 3. ImagePullBackOff

```bash
# Check pod events
kubectl describe pod <pod-name> | grep -A10 Events

# Common causes:
# - Image doesn't exist
# - Wrong image name/tag
# - Missing imagePullSecrets
# - Registry authentication failure

# Verify image exists
docker pull <image-name>

# Check image pull secrets
kubectl get secrets
kubectl describe secret regcred

# Recreate ECR credentials (AWS)
aws ecr get-login-password --region eu-south-2 | docker login --username AWS --password-stdin 507745009364.dkr.ecr.eu-south-2.amazonaws.com

kubectl delete secret regcred
kubectl create secret docker-registry regcred \
  --docker-server=507745009364.dkr.ecr.eu-south-2.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region eu-south-2)
```

#### 4. MongoDB Replica Set Not Initializing

```bash
# Check MongoDB logs
kubectl logs mongodb-0

# Common issue: Replica set not initialized
# Solution: Manually initialize
kubectl exec -it mongodb-0 -- mongosh --eval 'rs.initiate({
  _id: "rs0",
  members: [
    {_id: 0, host: "mongodb-0.mongodb:27017"},
    {_id: 1, host: "mongodb-1.mongodb:27017"},
    {_id: 2, host: "mongodb-2.mongodb:27017"}
  ]
})'

# Check status
kubectl exec mongodb-0 -- mongosh --eval "rs.status()"

# Check configuration
kubectl exec mongodb-0 -- mongosh --eval "rs.conf()"
```

#### 5. RabbitMQ Cluster Formation Issues

```bash
# Check cluster status
kubectl exec rabbitmq-0 -- rabbitmqctl cluster_status

# Check logs
kubectl logs rabbitmq-0

# Force reset and rejoin
kubectl exec rabbitmq-1 -- rabbitmqctl stop_app
kubectl exec rabbitmq-1 -- rabbitmqctl reset
kubectl exec rabbitmq-1 -- rabbitmqctl join_cluster rabbit@rabbitmq-0
kubectl exec rabbitmq-1 -- rabbitmqctl start_app

# Verify cluster
kubectl exec rabbitmq-0 -- rabbitmqctl cluster_status
```

#### 6. DNS Resolution Failures

```bash
# Test DNS from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Check service
kubectl get svc -n kube-system kube-dns

# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
```

#### 7. Service Not Accessible

```bash
# Check service
kubectl get svc <service-name>
kubectl describe svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# If no endpoints, pods might not match selector
kubectl get pods -l <label-selector>

# Test service from another pod
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://<service-name>:8000/health

# Check network policies
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>
```

### Performance Issues

```bash
# Check resource utilization
kubectl top nodes
kubectl top pods --containers

# Check for resource limits
kubectl describe pod <pod-name> | grep -A10 "Limits\|Requests"

# Check for throttling
kubectl describe pod <pod-name> | grep -i throttl

# Check database connections
kubectl exec postgres-0 -- psql -U cpt_dbuser -c "SELECT count(*) FROM pg_stat_activity;"

# Check RabbitMQ queue lengths
kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages consumers

# Enable profiling (if supported)
kubectl port-forward <pod-name> 6060:6060
curl http://localhost:6060/debug/pprof/
```

## Best Practices

### 1. Git Workflow

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
# ...

# Commit with descriptive messages
git add .
git commit -m "feat: add health check endpoint to ASMM8

- Implement /health endpoint
- Add database connectivity check
- Update Kubernetes liveness probe"

# Push to remote
git push origin feature/new-feature

# Create pull request
# Review, test, merge
```

### 2. Configuration Management

```bash
# Use Kustomize overlays for environment-specific configs
# Never commit secrets in plain text
# Use SOPS for encrypted secrets

# Encrypt secret
sops -e -i overlays/staging/secrets/asmm8-secret.yaml

# Decrypt for editing
sops overlays/staging/secrets/asmm8-secret.yaml

# Decrypt and apply
sops -d overlays/staging/secrets/asmm8-secret.yaml | kubectl apply -f -
```

### 3. Resource Management

```yaml
# Always define resource requests and limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Use HorizontalPodAutoscaler for production
# Define PodDisruptionBudgets for high availability
# Use appropriate StorageClass for workload type
```

### 4. Security

```bash
# Scan images before deployment
trivy image asmm8:v1.0.0

# Use non-root containers
# Drop all capabilities
# Use read-only root filesystem
# Enable Pod Security Standards

# Validate manifests
kubectl apply --dry-run=server -k overlays/staging/
kubesec scan bases/asmm8/deployment.yaml
```

### 5. Monitoring

```bash
# Always implement health checks
# Use meaningful log levels
# Include trace IDs for distributed tracing
# Monitor resource usage
# Set up alerts for critical metrics
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [CPTM8 ARCHITECTURE.md](./ARCHITECTURE.md)
- [CPTM8 SECURITY.md](./SECURITY.md)

## Conclusion

This development guide provides a comprehensive foundation for working with the CPTM8 Kubernetes infrastructure. Following these workflows and best practices will ensure consistent, reliable deployments across all environments while maintaining security and operational excellence.

For additional help, refer to the troubleshooting section, architecture documentation, or reach out to the platform team.
