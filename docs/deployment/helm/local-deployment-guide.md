# CPTM8 Helm Local Development Deployment Guide

This guide provides comprehensive instructions for deploying CPTM8 on a local **Kind (Kubernetes in Docker)** cluster using Helm.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Kind Cluster Setup](#kind-cluster-setup)
4. [Helm Chart Structure](#helm-chart-structure)
5. [Configuration](#configuration)
6. [Deployment](#deployment)
7. [Verification](#verification)
8. [Accessing Applications](#accessing-applications)
9. [Development Workflow](#development-workflow)
10. [Upgrading & Rollback](#upgrading--rollback)
11. [Troubleshooting](#troubleshooting)
12. [Cleanup](#cleanup)

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Docker | 20.10+ | [Install Docker](https://docs.docker.com/get-docker/) |
| Kind | 0.20+ | `brew install kind` or [Kind Install](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| kubectl | 1.28+ | `brew install kubectl` |
| Helm | 3.12+ | `brew install helm` |

### Verify Installation

```bash
# Check all tools are installed
docker --version
kind --version
kubectl version --client
helm version
```

---

## Quick Start

For experienced users, here's the fastest path to deployment:

```bash
# 1. Create Kind cluster with port mappings
cat <<EOF | kind create cluster --name cptm8-dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 3000
    protocol: TCP
  - containerPort: 30001
    hostPort: 4000
    protocol: TCP
  - containerPort: 30672
    hostPort: 15672
    protocol: TCP
EOF

# 2. Deploy CPTM8 with Helm
helm install cptm8 helm/cptm8 -n cptm8-dev --create-namespace

# 3. Wait for pods
kubectl wait --for=condition=Ready pods --all -n cptm8-dev --timeout=300s

# 4. Access applications
open http://localhost:3000      # Dashboard
open http://localhost:4000      # Socket.io
open http://localhost:15672     # RabbitMQ Management
```

---

## Kind Cluster Setup

### Create Kind Configuration

Create a file `kind-config.yaml`:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cptm8-dev
nodes:
- role: control-plane
  extraPortMappings:
  # Dashboard (Next.js)
  - containerPort: 30000
    hostPort: 3000
    protocol: TCP
  # Socket.io
  - containerPort: 30001
    hostPort: 4000
    protocol: TCP
  # RabbitMQ Management
  - containerPort: 30672
    hostPort: 15672
    protocol: TCP
  # OpenSearch Dashboards (optional)
  - containerPort: 30561
    hostPort: 5601
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
```

### Create the Cluster

```bash
# Create cluster from config
kind create cluster --config kind-config.yaml

# Verify cluster is running
kubectl cluster-info --context kind-cptm8-dev

# Set kubectl context
kubectl config use-context kind-cptm8-dev
```

### Load Local Images (Optional)

If you have locally built images:

```bash
# Load images into Kind
kind load docker-image cptm8/dashboardm8:dev-latest --name cptm8-dev
kind load docker-image cptm8/socketm8:dev-latest --name cptm8-dev
kind load docker-image cptm8/asmm8:dev-latest --name cptm8-dev
# ... repeat for all images
```

---

## Helm Chart Structure

```
helm/cptm8/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values (dev environment)
├── values-staging-aws.yaml # AWS EKS staging values
├── values-staging-azure.yaml # Azure AKS staging values
├── templates/
│   ├── _helpers.tpl        # Template helpers
│   ├── _go-scanner.tpl     # Go service templates
│   ├── _frontend.tpl       # Frontend service templates
│   ├── _init-container.tpl # Init container templates
│   ├── _probes.tpl         # Health probe templates
│   ├── _security-context.tpl # Security context templates
│   ├── namespace.yaml
│   ├── configmaps/         # ConfigMaps
│   ├── secrets/            # Secrets
│   ├── storage/            # StorageClasses, PVs, PVCs
│   ├── databases/          # PostgreSQL, MongoDB, RabbitMQ, OpenSearch
│   ├── deployments/        # Scanners, Frontend
│   ├── services/           # All services
│   ├── jobs/               # CronJobs, Init Jobs
│   ├── rbac/               # ServiceAccounts, Roles
│   ├── security/           # NetworkPolicies
│   ├── ingress/            # Ingress resources
│   ├── vector/             # Vector log aggregation
│   └── NOTES.txt           # Post-install instructions
```

---

## Configuration

### Understanding values.yaml

The `values.yaml` file contains all configurable options. Key sections:

```yaml
# Global settings
global:
  environment: dev           # dev, staging, prod
  imageRegistry: ""          # Empty for local, ECR/ACR for cloud
  imageTag: dev-latest
  imagePullPolicy: IfNotPresent

# Namespace
namespace:
  create: true

# Services configuration
scanners:
  asmm8:
    enabled: true
    replicaCount: 1
    port: 8000
  # ... other scanners

frontend:
  dashboardm8:
    enabled: true
    port: 3000
  socketm8:
    enabled: true
    port: 4000

# Databases
postgresql:
  enabled: true
  persistence:
    size: 30Gi

# NodePort (dev only)
nodePort:
  enabled: true
  dashboard:
    port: 30000
  socket:
    port: 30001

# Secrets (inline for dev)
secrets:
  method: inline
  data:
    postgresql:
      rootPassword: ""  # Auto-generated if empty
```

### Create Local Values Override (Optional)

For custom local settings, create `values-local.yaml`:

```yaml
# values-local.yaml
global:
  environment: dev
  imagePullPolicy: Never  # Use local images only

# Reduce resource requests for local development
global:
  resources:
    scanner:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "250m"

# Disable features not needed locally
vector:
  enabled: false  # Disable if not testing logging

networkPolicies:
  enabled: false  # Disable for easier debugging
```

---

## Deployment

### Install the Chart

```bash
# Basic installation (uses default values.yaml)
helm install cptm8 helm/cptm8 \
  --namespace cptm8-dev \
  --create-namespace

# With custom values file
helm install cptm8 helm/cptm8 \
  --namespace cptm8-dev \
  --create-namespace \
  -f helm/cptm8/values-local.yaml

# With inline value overrides
helm install cptm8 helm/cptm8 \
  --namespace cptm8-dev \
  --create-namespace \
  --set global.environment=dev \
  --set vector.enabled=false
```

### Watch Deployment Progress

```bash
# Watch pods come up
kubectl get pods -n cptm8-dev -w

# In another terminal, watch events
kubectl get events -n cptm8-dev --sort-by='.lastTimestamp' -w
```

### Deployment Order

Helm deploys resources in this order:
1. Namespace
2. StorageClasses, PVs
3. ConfigMaps, Secrets
4. RBAC (ServiceAccounts, Roles)
5. PVCs
6. StatefulSets (databases)
7. Deployments (applications)
8. Services
9. Jobs/CronJobs (via hooks)
10. Ingress, NetworkPolicies

---

## Verification

### Check All Resources

```bash
# Get all resources in namespace
kubectl get all -n cptm8-dev

# Check specific resource types
kubectl get pods -n cptm8-dev
kubectl get services -n cptm8-dev
kubectl get pvc -n cptm8-dev
kubectl get configmaps -n cptm8-dev
kubectl get secrets -n cptm8-dev
```

### Verify Pod Health

```bash
# Wait for all pods to be ready
kubectl wait --for=condition=Ready pods --all -n cptm8-dev --timeout=300s

# Check pod status
kubectl get pods -n cptm8-dev -o wide

# Check for any issues
kubectl get pods -n cptm8-dev | grep -v Running
```

### Check Logs

```bash
# Dashboard logs
kubectl logs -f deploy/dashboardm8 -n cptm8-dev

# Scanner logs
kubectl logs -f deploy/asmm8 -n cptm8-dev

# Database logs
kubectl logs -f statefulset/postgresql -n cptm8-dev

# Init container logs (if pod is initializing)
kubectl logs <pod-name> -c init-configs -n cptm8-dev
```

### Verify Services

```bash
# List all services
kubectl get svc -n cptm8-dev

# Test internal DNS resolution
kubectl run test-dns --rm -it --image=busybox --restart=Never -n cptm8-dev -- \
  nslookup postgresql-service.cptm8-dev.svc.cluster.local

# Test service connectivity
kubectl run test-curl --rm -it --image=curlimages/curl --restart=Never -n cptm8-dev -- \
  curl -s http://dashboardm8-service:3000/health
```

---

## Accessing Applications

### Via NodePort (Default for Dev)

| Application | URL | Description |
|-------------|-----|-------------|
| Dashboard | http://localhost:3000 | Next.js frontend |
| Socket.io | http://localhost:4000 | WebSocket server |
| RabbitMQ | http://localhost:15672 | Management UI (guest/guest) |

### Via Port-Forward (Alternative)

```bash
# Dashboard
kubectl port-forward svc/dashboardm8-service 3000:3000 -n cptm8-dev

# Socket.io
kubectl port-forward svc/socketm8-service 4000:4000 -n cptm8-dev

# PostgreSQL (for database tools)
kubectl port-forward svc/postgresql-service 5432:5432 -n cptm8-dev

# MongoDB
kubectl port-forward svc/mongodb-primary-service 27017:27017 -n cptm8-dev

# OpenSearch Dashboards
kubectl port-forward svc/opensearch-dashboards-service 5601:5601 -n cptm8-dev
```

---

## Development Workflow

### Making Configuration Changes

```bash
# Edit values and upgrade
vim helm/cptm8/values.yaml
helm upgrade cptm8 helm/cptm8 -n cptm8-dev

# Or use --set for quick changes
helm upgrade cptm8 helm/cptm8 -n cptm8-dev \
  --set scanners.asmm8.replicaCount=2
```

### Restarting Services

```bash
# Restart a specific deployment
kubectl rollout restart deploy/dashboardm8 -n cptm8-dev

# Restart all deployments
kubectl rollout restart deploy -n cptm8-dev
```

### Viewing Rendered Templates

```bash
# Render all templates without installing
helm template cptm8 helm/cptm8 -n cptm8-dev

# Render specific template
helm template cptm8 helm/cptm8 -n cptm8-dev \
  --show-only templates/deployments/scanners.yaml

# Render with custom values
helm template cptm8 helm/cptm8 -n cptm8-dev \
  -f values-local.yaml \
  --show-only templates/configmaps/cptm8-config.yaml
```

### Debugging Templates

```bash
# Dry-run with debug output
helm install cptm8 helm/cptm8 -n cptm8-dev --dry-run --debug

# Lint the chart
helm lint helm/cptm8

# Validate against cluster
helm template cptm8 helm/cptm8 | kubectl apply --dry-run=server -f -
```

---

## Upgrading & Rollback

### Upgrade Release

```bash
# Upgrade with new values
helm upgrade cptm8 helm/cptm8 -n cptm8-dev -f values-local.yaml

# Upgrade and wait for completion
helm upgrade cptm8 helm/cptm8 -n cptm8-dev --wait --timeout 5m

# Upgrade with atomic (auto-rollback on failure)
helm upgrade cptm8 helm/cptm8 -n cptm8-dev --atomic --timeout 5m
```

### View Release History

```bash
# List releases
helm list -n cptm8-dev

# View release history
helm history cptm8 -n cptm8-dev
```

### Rollback

```bash
# Rollback to previous revision
helm rollback cptm8 -n cptm8-dev

# Rollback to specific revision
helm rollback cptm8 2 -n cptm8-dev

# Rollback and wait
helm rollback cptm8 -n cptm8-dev --wait --timeout 5m
```

---

## Troubleshooting

### Common Issues

#### Pods Stuck in Pending

```bash
# Check PVC status
kubectl get pvc -n cptm8-dev

# Check StorageClass
kubectl get sc

# Describe pending pod
kubectl describe pod <pod-name> -n cptm8-dev
```

**Solution**: Ensure StorageClass provisioner is available. For Kind, the default `rancher.io/local-path` should work.

#### Pods in CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n cptm8-dev --previous

# Check events
kubectl describe pod <pod-name> -n cptm8-dev
```

**Common causes**:
- Missing secrets or configmaps
- Database not ready
- Permission issues (security context)

#### Image Pull Errors

```bash
# Check pod events
kubectl describe pod <pod-name> -n cptm8-dev | grep -A5 Events

# For local images, load into Kind
kind load docker-image <image-name> --name cptm8-dev
```

#### Database Connection Issues

```bash
# Verify database pods are running
kubectl get pods -l tier=data -n cptm8-dev

# Check secrets exist
kubectl get secret postgresql-secrets -n cptm8-dev -o yaml

# Test connectivity
kubectl exec -it deploy/dashboardm8 -n cptm8-dev -- \
  nc -zv postgresql-service 5432
```

### Debug Commands

```bash
# Execute into a pod
kubectl exec -it deploy/dashboardm8 -n cptm8-dev -- /bin/sh

# Check environment variables
kubectl exec deploy/dashboardm8 -n cptm8-dev -- env | sort

# View mounted configs
kubectl exec deploy/asmm8 -n cptm8-dev -- cat /app/configs/configuration.yaml

# Network debugging
kubectl run netshoot --rm -it --image=nicolaka/netshoot -n cptm8-dev -- /bin/bash
```

---

## Cleanup

### Uninstall Release

```bash
# Uninstall (keeps PVCs)
helm uninstall cptm8 -n cptm8-dev

# Delete namespace and all resources
kubectl delete namespace cptm8-dev
```

### Delete Kind Cluster

```bash
# Delete cluster
kind delete cluster --name cptm8-dev

# Verify deletion
kind get clusters
```

### Full Cleanup

```bash
# Complete cleanup script
helm uninstall cptm8 -n cptm8-dev 2>/dev/null || true
kubectl delete namespace cptm8-dev --wait=false 2>/dev/null || true
kind delete cluster --name cptm8-dev 2>/dev/null || true
docker volume prune -f

echo "Cleanup complete!"
```

---

## Next Steps

- [Cloud Deployment Guide](./cloud-deployment-guide.md) - Deploy to AWS EKS or Azure AKS
- [Values Reference](./values-reference.md) - Complete values.yaml documentation
- [Helm Quickstart](./helm-quickstart.md) - Quick reference commands