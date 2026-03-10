# 🚀 CPTM8 Kubernetes Local Development Environment Guide

This guide provides comprehensive instructions for deploying your CPTM8 platform on **Kind (Kubernetes in Docker)** for local development using the <ins>*base + overlay file structure*</ins>. Kind creates a real Kubernetes cluster inside Docker containers, giving you production-like experience without cloud costs.

---

## 📋 Table of Contents

1. [Executive Summary](#-executive-summary)
2. [Local Architecture Overview](#-local-architecture-overview)
3. [Prerequisites](#-prerequisites)
4. [Kind Cluster Setup](#-kind-cluster-setup)
5. [Directory Structure](#-directory-structure)
6. [Secrets Management (SOPS)](#-secrets-management-sops)
7. [Deployment](#-deployment)
8. [Verification & Health Checks](#-verification--health-checks)
9. [Accessing Applications](#-accessing-applications)
10. [Daily Development Workflow](#-daily-development-workflow)
11. [Live Configuration Updates](#-live-configuration-updates)
12. [Debugging & Troubleshooting](#-debugging--troubleshooting)
13. [Database Operations](#-database-operations)
14. [Log Management](#-log-management)
15. [Resource Management](#-resource-management)
16. [Cleanup & Reset](#-cleanup--reset)
17. [Environment Comparison](#-environment-comparison)
18. [Next Steps](#-next-steps)

---

## 📋 Executive Summary

The local development environment provides:

- **Zero-cost Kubernetes cluster** running on your local machine
- **Production-like architecture** with the same manifests used in staging/production
- **Fast iteration cycles** for development and testing
- **Full stack deployment** including databases, message queues, and observability
- **SOPS encryption** for secure secret management
- **Kustomize-based deployment** for consistent, repeatable deployments

---

## 🏗️ Local Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL DEVELOPMENT ENVIRONMENT                 │
├─────────────────────────────────────────────────────────────────┤
│ 🐳 Runtime: Docker Desktop / Docker Engine                      │
│ 🎯 Cluster: Kind (Kubernetes in Docker)                         │
│ 🔐 Namespace: cptm8-dev                                         │
│ 💾 Storage: Local hostPath / emptyDir volumes                   │
│ 🌍 Networking: NodePort + Kind extraPortMappings                │
│ 📝 Logging: Vector → OpenSearch (local)                         │
│ 🔄 Deployment: Kustomize (kubectl apply -k .)                   │
│ 🔑 Secrets: SOPS with age encryption                            │
└─────────────────────────────────────────────────────────────────┘
```

### Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         LOCALHOST                                │
└───────────────────────────┬─────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            │ Kind extraPortMappings        │
            │ :3000 → :30080 (Dashboard)    │
            │ :4000 → :30081 (Socket.io)    │
            │ :15672 → :30672 (RabbitMQ)    │
            └───────────────┬───────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
┌─────────────────────┐         ┌─────────────────────┐
│     FRONTEND        │         │     BACKEND         │
│  ┌───────────────┐  │         │  ┌───────────────┐  │
│  │ dashboardm8   │  │         │  │    asmm8      │  │
│  │ (Next.js)     │  │         │  │   naabum8     │  │
│  │ Port: 3000    │  │         │  │   katanam8    │  │
│  ├───────────────┤  │         │  │    num8       │  │
│  │  socketm8     │  │         │  │ orchestratorm8│  │
│  │ (Socket.io)   │  │         │  │ reportingm8   │  │
│  │ Port: 4000    │  │         │  └───────────────┘  │
│  └───────────────┘  │         └──────────┬──────────┘
└─────────────────────┘                    │
                                           │
            ┌──────────────────────────────┼──────────────────────────────┐
            ▼                              ▼                              ▼
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│     DATABASES       │     │     MESSAGE QUEUE   │     │      SEARCH         │
│  ┌───────────────┐  │     │  ┌───────────────┐  │     │  ┌───────────────┐  │
│  │  PostgreSQL   │  │     │  │   RabbitMQ    │  │     │  │  OpenSearch   │  │
│  │  (StatefulSet)│  │     │  │  (StatefulSet)│  │     │  │  (StatefulSet)│  │
│  │  Port: 5432   │  │     │  │  Port: 5672   │  │     │  │  Port: 9200   │  │
│  ├───────────────┤  │     │  │  Mgmt: 15672  │  │     │  └───────────────┘  │
│  │   MongoDB     │  │     │  └───────────────┘  │     └─────────────────────┘
│  │  (StatefulSet)│  │     └─────────────────────┘
│  │  Port: 27017  │  │
│  └───────────────┘  │
└─────────────────────┘
```

---

## 🔧 Prerequisites

### Required Software

| Software | Version | Purpose | Installation |
|----------|---------|---------|--------------|
| **Docker** | 20.10+ | Container runtime | [docs.docker.com](https://docs.docker.com/get-docker/) |
| **kubectl** | 1.28+ | Kubernetes CLI | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| **Kind** | 0.20+ | Local Kubernetes | See below |
| **SOPS** | 3.8+ | Secret encryption | [github.com/getsops/sops](https://github.com/getsops/sops) |
| **age** | 1.1+ | Encryption backend | [github.com/FiloSottile/age](https://github.com/FiloSottile/age) |

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 4 cores | 8 cores |
| **RAM** | 8 GB | 16 GB |
| **Disk** | 20 GB free | 50 GB free |
| **Docker Memory** | 6 GB allocated | 10 GB allocated |

### Install Kind

```bash
# Linux (amd64)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# macOS (Intel)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# macOS (Apple Silicon)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version
```

### Install SOPS and age

```bash
# SOPS (Linux)
curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x sops-v3.8.1.linux.amd64
sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops

# age (Linux)
sudo apt install age  # Debian/Ubuntu
# or
brew install age      # macOS

# Verify installations
sops --version
age --version
```

---

## 🎯 Kind Cluster Setup

### Create Cluster Configuration

The Kind cluster configuration defines port mappings that allow external access to services:

```bash
# Create cluster with frontend port mappings
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cptm8-dev
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  # Frontend access
  - containerPort: 30080
    hostPort: 3000
    protocol: TCP
  - containerPort: 30081
    hostPort: 4000
    protocol: TCP
  # RabbitMQ Management
  - containerPort: 30672
    hostPort: 15672
    protocol: TCP
  # Ingress (optional)
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

### Verify Cluster Creation

```bash
# Check cluster info
kubectl cluster-info --context kind-cptm8-dev

# Verify node is ready
kubectl get nodes --context kind-cptm8-dev

# Expected output:
# NAME                      STATUS   ROLES           AGE   VERSION
# cptm8-dev-control-plane   Ready    control-plane   1m    v1.28.0
```

### Install NGINX Ingress Controller (Optional)

If you want to use Ingress resources for routing:

```bash
# Install NGINX Ingress Controller for Kind
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

---

## 📁 Directory Structure

The repository uses Kustomize base/overlay pattern:

```
Kubernetes/
├── base/                              # Environment-agnostic base templates
│   ├── kustomization.yaml             # Base kustomization
│   ├── RBAC/
│   │   └── rbac.yaml                  # ServiceAccounts, Roles, RoleBindings
│   ├── deployments/
│   │   ├── postgresql.yaml            # Database StatefulSets
│   │   ├── mongodb.yaml
│   │   ├── rabbitmq.yaml
│   │   ├── opensearch.yaml
│   │   ├── asmm8.yaml                 # Microservice Deployments
│   │   ├── naabum8.yaml
│   │   ├── katanam8.yaml
│   │   ├── num8.yaml
│   │   ├── orchestratorm8.yaml
│   │   ├── reportingm8.yaml
│   │   ├── dashboardm8.yaml           # Frontend Deployments
│   │   ├── socketm8.yaml
│   │   └── vector.yaml                # Observability
│   ├── services/
│   │   └── services.yaml              # All ClusterIP services
│   └── jobs/
│       ├── cronjob.yaml               # ECR token refresher
│       └── mongodb-init-job.yaml      # MongoDB initialization
│
├── overlays/
│   └── dev/                           # Local development overlay
│       ├── kustomization.yaml
│       ├── configmaps/                # Dev-specific ConfigMaps
│       ├── secrets/                   # SOPS-encrypted secrets
│       ├── storage/                   # Local StorageClass, PVs
│       ├── services/                  # NodePort services
│       ├── patches/                   # Resource limit patches
│       ├── security/                  # Network policies
│       └── ingress/                   # Optional ingress rules
│
├── kustomization.yaml                 # Root kustomization (deploy from here)
├── namespaces.yaml                    # Namespace definitions
└── docs/
    └── deployment/
        └── local-deployment-guide.md  # This file
```

### Root Kustomization

The root `kustomization.yaml` orchestrates the deployment order:

```yaml
# kustomization.yaml (simplified)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # 1. Namespaces and RBAC
  - namespaces.yaml
  - RBAC/rbac-dev.yaml

  # 2. Storage
  - storage/storageclass-dev.yaml

  # 3. ConfigMaps
  - configmaps/

  # 4. Services
  - services/services-dev.yaml

  # 5. Databases (StatefulSets)
  - deployments/postgresql-dev.yaml
  - deployments/mongodb-dev.yaml
  - deployments/rabbitmq-dev.yaml

  # 6. Search
  - deployments/opensearch-dev.yaml

  # 7. Backend services
  - deployments/orchestratorm8-dev.yaml
  - deployments/asmm8-dev.yaml
  # ... other services

  # 8. Frontend
  - deployments/dashboardm8-dev.yaml
  - deployments/socketm8-dev.yaml

  # 9. Observability
  - deployments/vector-dev.yaml

  # 10. Jobs
  - jobs/cronjob-dev.yaml
```

---

## 🔐 Secrets Management (SOPS)

### Setup SOPS with age

```bash
# Generate age key pair (one-time setup)
age-keygen -o key.txt

# The key.txt file should look like:
# # created: 2024-01-01T00:00:00Z
# # public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Set environment variable
export SOPS_AGE_KEY_FILE=$(pwd)/key.txt

# Or source the provided script
source environment_vars_setup.sh
```

### Create .sops.yaml Configuration

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Encrypt/Decrypt Secrets

```bash
# Encrypt a secret file
sops -e secrets/secrets-dev.yaml > secrets/secrets-dev.encrypted.yaml

# Decrypt and view
sops -d secrets/secrets-dev.encrypted.yaml

# Edit encrypted file in place
sops secrets/secrets-dev.encrypted.yaml

# Apply decrypted secrets to cluster
sops -d secrets/secrets-dev.encrypted.yaml | kubectl apply -f -
```

> **⚠️ Security:** Never commit `key.txt` or unencrypted secrets to git. Add them to `.gitignore`.

---

## 🚀 Deployment

### Option 1: One-Command Deployment (Recommended)

```bash
# 1. Ensure you're in the correct directory
cd /path/to/Kubernetes

# 2. Set SOPS environment
export SOPS_AGE_KEY_FILE=$(pwd)/key.txt
# or: source environment_vars_setup.sh

# 3. Apply secrets first
sops -d secrets/secrets-dev.encrypted.yaml | kubectl apply -f -

# 4. Deploy everything with Kustomize
kubectl apply -k .

# 5. Trigger initial ECR token refresh (for private images)
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-initial -n cptm8-dev
kubectl wait --for=condition=complete job/ecr-token-initial -n cptm8-dev --timeout=60s

# 6. Wait for MongoDB to be ready
kubectl wait --for=condition=ready pod -l app=mongodb-primary -n cptm8-dev --timeout=300s

# 7. Initialize MongoDB replica set
kubectl apply -f jobs/mongodb-init-job-dev.yaml
kubectl wait --for=condition=complete job/mongodb-init -n cptm8-dev --timeout=120s

# 8. Watch deployment progress
kubectl get pods -n cptm8-dev -w
```

### Option 2: Step-by-Step Deployment (Educational)

```bash
# 1. RBAC (creates ServiceAccounts needed by pods)
kubectl apply -f RBAC/rbac-dev.yaml

# 2. Apply secrets
sops -d secrets/secrets-dev.encrypted.yaml | kubectl apply -f -

# 3. Trigger ECR token refresh
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-initial -n cptm8-dev
kubectl wait --for=condition=complete job/ecr-token-initial -n cptm8-dev --timeout=60s

# 4. Storage and ConfigMaps
kubectl apply -f storage/storageclass-dev.yaml
kubectl apply -f configmaps/
kubectl apply -f services/services-dev.yaml

# 5. Databases
kubectl apply -f deployments/postgresql-dev.yaml
kubectl apply -f deployments/mongodb-dev.yaml
kubectl apply -f deployments/rabbitmq-dev.yaml

# Wait for databases
kubectl wait --for=condition=ready pod -l app=postgresqlm8 -n cptm8-dev --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb-primary -n cptm8-dev --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n cptm8-dev --timeout=300s

# 6. Initialize MongoDB
kubectl apply -f jobs/mongodb-init-job-dev.yaml
kubectl wait --for=condition=complete job/mongodb-init -n cptm8-dev --timeout=120s

# 7. OpenSearch
kubectl apply -f deployments/opensearch-dev.yaml
kubectl wait --for=condition=ready pod -l app=opensearch-node1 -n cptm8-dev --timeout=600s

# 8. Vector (logging)
kubectl apply -f deployments/vector-dev.yaml

# 9. Backend microservices
kubectl apply -f deployments/orchestratorm8-dev.yaml
kubectl apply -f deployments/asmm8-dev.yaml
kubectl apply -f deployments/naabum8-dev.yaml
kubectl apply -f deployments/katanam8-dev.yaml
kubectl apply -f deployments/num8-dev.yaml
kubectl apply -f deployments/reportingm8-dev.yaml

# 10. Frontend applications
kubectl apply -f deployments/dashboardm8-dev.yaml
kubectl apply -f deployments/socketm8-dev.yaml

# 11. NodePort services for external access
kubectl apply -f services/frontend-nodeport-dev.yaml
```

### Deployment Order Rationale

| Order | Component | Reason |
|-------|-----------|--------|
| 1 | RBAC | Creates ServiceAccounts required by pods |
| 2 | Secrets | Credentials needed by all services |
| 3 | Storage | PVCs need StorageClass to provision |
| 4 | ConfigMaps | Configuration loaded by deployments |
| 5 | Services | DNS names available before pods start |
| 6 | Databases | Backend services depend on these |
| 7 | MongoDB Init | Configures replica set and creates DB |
| 8 | OpenSearch | Log storage for Vector |
| 9 | Vector | Log aggregation (needs OpenSearch) |
| 10 | Backend | Connects to databases and queues |
| 11 | Frontend | Connects to backend services |

---

## ✅ Verification & Health Checks

### Check All Resources

```bash
# Get comprehensive overview
kubectl get pods,svc,pvc,jobs -n cptm8-dev

# Expected: All pods Running, all PVCs Bound, jobs Completed
```

### Verify Pod Health

```bash
# Check all pods are running
kubectl get pods -n cptm8-dev -o wide

# Check for any issues
kubectl get pods -n cptm8-dev | grep -v Running
```

### Test Service Health Endpoints

```bash
# Test backend health endpoints
kubectl exec -n cptm8-dev deployment/asmm8 -- curl -sf http://localhost:8000/health
kubectl exec -n cptm8-dev deployment/naabum8 -- curl -sf http://localhost:8001/health
kubectl exec -n cptm8-dev deployment/katanam8 -- curl -sf http://localhost:8002/health
kubectl exec -n cptm8-dev deployment/num8 -- curl -sf http://localhost:8003/health

# Test readiness (checks dependencies)
kubectl exec -n cptm8-dev deployment/asmm8 -- curl -sf http://localhost:8000/ready
```

### Verify Database Connectivity

```bash
# PostgreSQL
kubectl exec -n cptm8-dev statefulset/postgresqlm8 -- pg_isready -U cptm8_user -d cptm8

# MongoDB
kubectl exec -n cptm8-dev mongodb-primary-0 -- mongosh --eval "rs.status()" --quiet

# RabbitMQ
kubectl exec -n cptm8-dev statefulset/rabbitmq-0 -- rabbitmq-diagnostics ping
```

### Verify ECR Token Automation

```bash
# Check CronJob is scheduled
kubectl get cronjob -n cptm8-dev ecr-token-refresher

# Verify secret exists
kubectl get secret -n cptm8-dev ecr-registry-secret

# Check recent job history
kubectl get jobs -n cptm8-dev | grep ecr-token
```

---

## 🌐 Accessing Applications

### NodePort Access (Recommended for Development)

```bash
# Apply NodePort services
kubectl apply -f services/frontend-nodeport-dev.yaml

# Verify services
kubectl get svc -n cptm8-dev | grep nodeport
```

### Access URLs

| Application | URL | Description |
|-------------|-----|-------------|
| **Dashboard** | http://localhost:3000 | Next.js web interface |
| **Socket.io** | http://localhost:4000 | Real-time WebSocket server |
| **RabbitMQ Management** | http://localhost:15672 | Queue management UI |

### Test Connectivity

```bash
# Test dashboard
curl -s http://localhost:3000 | head -5

# Test socket.io
curl -s http://localhost:4000/socket.io/

# RabbitMQ (default: guest/guest)
curl -s -u guest:guest http://localhost:15672/api/overview | jq .
```

### Port Forwarding (Alternative)

For services without NodePort:

```bash
# PostgreSQL
kubectl port-forward -n cptm8-dev svc/postgresql-service 5432:5432 &

# OpenSearch
kubectl port-forward -n cptm8-dev svc/opensearch-service 9200:9200 &

# Access any service
kubectl port-forward -n cptm8-dev deployment/asmm8 8000:8000 &
```

---

## 🛠️ Daily Development Workflow

### Restart After Code Changes

```bash
# Restart a single deployment
kubectl rollout restart deployment/asmm8 -n cptm8-dev

# Watch rollout progress
kubectl rollout status deployment/asmm8 -n cptm8-dev

# Restart all backend services
kubectl rollout restart deployment -n cptm8-dev -l tier=application

# Restart all frontend services
kubectl rollout restart deployment -n cptm8-dev -l tier=frontend
```

### View Logs

```bash
# Stream logs from a deployment
kubectl logs -f deployment/asmm8 -n cptm8-dev

# Logs with timestamps
kubectl logs -f deployment/asmm8 -n cptm8-dev --timestamps

# Logs from all pods with a label
kubectl logs -l app=asmm8 -n cptm8-dev --all-containers --tail=50

# Previous container logs (after crash)
kubectl logs deployment/asmm8 -n cptm8-dev --previous
```

### Execute Commands in Pods

```bash
# Get a shell
kubectl exec -it deployment/asmm8 -n cptm8-dev -- /bin/sh

# Run a single command
kubectl exec -n cptm8-dev deployment/asmm8 -- env | grep DATABASE

# Copy files
kubectl cp local-file.txt cptm8-dev/asmm8-xxxx:/app/
kubectl cp cptm8-dev/asmm8-xxxx:/app/output.log ./output.log
```

### Scale Deployments

```bash
# Scale up
kubectl scale deployment asmm8 --replicas=3 -n cptm8-dev

# Scale down
kubectl scale deployment asmm8 --replicas=1 -n cptm8-dev

# Check current replicas
kubectl get deployment asmm8 -n cptm8-dev -o jsonpath='{.spec.replicas}'
```

---

## ⚙️ Live Configuration Updates

### Architecture

```
ConfigMap (Source of Truth)
    ↓ Init Container Copies
emptyDir (Writable Storage)
    ↓ subPath Mounts
/app/configs/ (Application Config Directory)
```

### Option 1: Quick Live Edit (Ephemeral)

Changes are lost when pod restarts. Good for testing.

```bash
# Edit configuration directly
kubectl exec -it deployment/asmm8 -n cptm8-dev -- vi /app/configs/subfinderconfig.yaml

# Copy local file to pod
kubectl cp ./subfinderconfig.yaml cptm8-dev/asmm8-<pod-name>:/app/configs/

# Verify changes
kubectl exec deployment/asmm8 -n cptm8-dev -- cat /app/configs/subfinderconfig.yaml
```

### Option 2: Persistent Change (Survives Restart)

Changes persist across restarts. Good for permanent updates.

```bash
# Edit ConfigMap
kubectl edit configmap configuration-template-asmm8 -n cptm8-dev

# Restart deployment to apply
kubectl rollout restart deployment/asmm8 -n cptm8-dev

# Verify changes persisted
kubectl exec deployment/asmm8 -n cptm8-dev -- cat /app/configs/subfinderconfig.yaml
```

### Update ConfigMap from File

```bash
# Replace ConfigMap with new files
kubectl create configmap configuration-template-asmm8 \
  --from-file=subfinderconfig.yaml=./configs/subfinderconfig.yaml \
  --from-file=configuration_template.yaml=./configs/configuration_template.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart to apply
kubectl rollout restart deployment/asmm8 -n cptm8-dev
```

---

## 🔍 Debugging & Troubleshooting

### Pod Not Starting

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n cptm8-dev

# Check init container logs
kubectl logs <pod-name> -n cptm8-dev -c fix-app-ownership

# Check main container logs
kubectl logs <pod-name> -n cptm8-dev
```

### Image Pull Errors

```bash
# Check for ImagePullBackOff
kubectl describe pod <pod-name> -n cptm8-dev | grep -A5 "ImagePullBackOff"

# Verify ECR secret exists
kubectl get secret ecr-registry-secret -n cptm8-dev

# Manually refresh ECR token
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-manual -n cptm8-dev
```

### Service Discovery Issues

```bash
# Check service endpoints
kubectl get endpoints -n cptm8-dev

# Verify DNS resolution from a pod
kubectl exec -n cptm8-dev deployment/asmm8 -- nslookup postgresql-service

# Test service connectivity
kubectl exec -n cptm8-dev deployment/asmm8 -- curl -sf http://rabbitmq-service:15672
```

### Database Connection Issues

```bash
# Check PostgreSQL connectivity
kubectl exec -n cptm8-dev deployment/asmm8 -- \
  pg_isready -h postgresql-service -p 5432 -U cptm8_user

# Check environment variables
kubectl exec -n cptm8-dev deployment/asmm8 -- env | grep -E "(DATABASE|POSTGRESQL)"

# Test MongoDB connection
kubectl exec -n cptm8-dev deployment/dashboardm8 -- env | grep PMG_DATABASE_URL
```

### Common Issues & Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Pod CrashLoopBackOff** | Repeated restarts | Check `kubectl logs --previous` |
| **ImagePullBackOff** | Can't pull image | Refresh ECR token, check secret |
| **Pending PVC** | PVC not bound | Check StorageClass exists |
| **DNS resolution fails** | Service not found | Check service exists, namespace correct |
| **MongoDB init failed** | Job failed | Delete job and re-run |

---

## 🗄️ Database Operations

### PostgreSQL

```bash
# Connect to PostgreSQL shell
kubectl exec -it -n cptm8-dev statefulset/postgresqlm8 -- \
  psql -U cptm8_user -d cptm8

# Run a query
kubectl exec -n cptm8-dev statefulset/postgresqlm8 -- \
  psql -U cptm8_user -d cptm8 -c "SELECT * FROM cptm8domain LIMIT 5;"

# Backup database
kubectl exec -n cptm8-dev statefulset/postgresqlm8 -- \
  pg_dump -U cptm8_user cptm8 > backup.sql
```

### MongoDB

```bash
# Connect to MongoDB shell
kubectl exec -it -n cptm8-dev mongodb-primary-0 -- mongosh

# Check replica set status
kubectl exec -n cptm8-dev mongodb-primary-0 -- \
  mongosh --eval "rs.status()" --quiet

# List databases
kubectl exec -n cptm8-dev mongodb-primary-0 -- \
  mongosh --eval "db.adminCommand('listDatabases')" --quiet

# Re-run MongoDB init job (if needed)
kubectl delete job mongodb-init -n cptm8-dev --ignore-not-found
kubectl apply -f jobs/mongodb-init-job-dev.yaml
kubectl wait --for=condition=complete job/mongodb-init -n cptm8-dev --timeout=120s
```

### RabbitMQ

```bash
# List queues
kubectl exec -n cptm8-dev statefulset/rabbitmq-0 -- \
  rabbitmqadmin list queues

# List exchanges
kubectl exec -n cptm8-dev statefulset/rabbitmq-0 -- \
  rabbitmqadmin list exchanges

# Check cluster status
kubectl exec -n cptm8-dev statefulset/rabbitmq-0 -- \
  rabbitmqctl cluster_status
```

### OpenSearch

```bash
# Check cluster health
kubectl exec -n cptm8-dev deployment/vector -- \
  curl -s http://opensearch-service:9200/_cluster/health | jq .

# List indices
kubectl exec -n cptm8-dev deployment/vector -- \
  curl -s http://opensearch-service:9200/_cat/indices?v
```

---

## 📊 Log Management

### View Aggregated Logs (OpenSearch)

```bash
# Port forward OpenSearch
kubectl port-forward -n cptm8-dev svc/opensearch-service 9200:9200 &

# Query recent logs
curl -s "http://localhost:9200/cptm8-logs-*/_search?size=10" | jq .

# Search for errors
curl -s "http://localhost:9200/cptm8-logs-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"level":"error"}}}' | jq .
```

### View Vector Logs

```bash
# Check Vector is processing logs
kubectl logs -n cptm8-dev deployment/vector --tail=50

# Check Vector configuration
kubectl exec -n cptm8-dev deployment/vector -- cat /etc/vector/vector.yaml
```

### Direct Pod Logs

```bash
# All logs from tier=application
kubectl logs -l tier=application -n cptm8-dev --all-containers --tail=50 -f

# Specific service with timestamps
kubectl logs -f deployment/asmm8 -n cptm8-dev --timestamps
```

---

## 📈 Resource Management

### View Resource Usage

```bash
# Pod resource usage (requires metrics-server)
kubectl top pods -n cptm8-dev

# Node resource usage
kubectl top nodes

# Describe resource limits
kubectl describe deployment asmm8 -n cptm8-dev | grep -A10 "Limits\|Requests"
```

### Install Metrics Server (for Kind)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for Kind (insecure TLS)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

### Resource Quotas

```bash
# View namespace quota
kubectl describe resourcequota -n cptm8-dev

# View limit ranges
kubectl describe limitrange -n cptm8-dev
```

---

## 🧹 Cleanup & Reset

### Remove Specific Resources

```bash
# Delete a deployment
kubectl delete deployment asmm8 -n cptm8-dev

# Delete all jobs
kubectl delete jobs --all -n cptm8-dev

# Delete PVCs (data will be lost!)
kubectl delete pvc --all -n cptm8-dev
```

### Reset Namespace

```bash
# Delete and recreate namespace (removes everything)
kubectl delete namespace cptm8-dev
kubectl create namespace cptm8-dev

# Redeploy
sops -d secrets/secrets-dev.encrypted.yaml | kubectl apply -f -
kubectl apply -k .
```

### Delete Kind Cluster

```bash
# Complete cleanup - delete entire cluster
kind delete cluster --name cptm8-dev

# Recreate from scratch
# (Follow Kind Cluster Setup section again)
```

### Clean Docker Resources

```bash
# Remove unused Docker resources
docker system prune -f

# Remove all unused volumes (careful!)
docker volume prune -f
```

---

## 📋 Environment Comparison

| Component | Local (Kind) | Staging (Cloud) | Production (Cloud) |
|-----------|-------------|-----------------|-------------------|
| **Cluster** | Single node Kind | 3 nodes (autoscaling) | 5+ nodes (multi-AZ) |
| **Storage** | hostPath/emptyDir | Cloud SSD (50-100GB) | Cloud SSD + backup |
| **Replicas** | 1 per service | 2 per service | 3+ per service |
| **Resources** | Minimal/No limits | Soft limits | Hard limits + VPA |
| **Monitoring** | Basic logs | Prometheus + Grafana | Full observability |
| **Security** | Basic RBAC | Network Policies + PSS | + Falco + OPA + mTLS |
| **Ingress** | NodePort | LoadBalancer + SSL | LB + WAF + CDN |
| **Secrets** | SOPS (local key) | SOPS / Cloud KMS | HashiCorp Vault |
| **CI/CD** | Manual | GitHub Actions | + Approval gates |
| **Backup** | None | Daily snapshots | Continuous + DR |
| **Cost** | $0 | ~$250-450/month | ~$800-1500/month |

---

## 🎯 Next Steps

After successfully deploying locally:

### Explore the Platform
- Open the dashboard at http://localhost:3000
- Monitor RabbitMQ queues at http://localhost:15672
- Check Vector logs flowing to OpenSearch

### Development Tasks
- Try scaling a deployment: `kubectl scale deployment asmm8 --replicas=2 -n cptm8-dev`
- Update a ConfigMap and restart a service
- Add a new API key to the configuration

### Learn More
- Review [kubernetes-architecture-diagram.md](./kubernetes-architecture-diagram.md) for architecture details
- Check [cloud-deployment-guide.md](./cloud-deployment-guide.md) for staging setup
- Explore [FRONTEND-EXPOSURE-GUIDE.md](./FRONTEND-EXPOSURE-GUIDE.md) for advanced networking

---

## 📚 Related Documentation

| Document | Description |
|----------|-------------|
| [Cloud Deployment Guide](./cloud-deployment-guide.md) | Staging/Production on AWS/Azure |
| [Architecture Diagram](./kubernetes-architecture-diagram.md) | Visual architecture overview |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Detailed component specifications |
| [SECURITY_REVIEW.md](./SECURITY_REVIEW.md) | Security audit findings |

---

## 🏆 What You've Accomplished

- ✅ **Local Kubernetes cluster** running your entire platform
- ✅ **Production-like environment** with proper networking and storage
- ✅ **Secure secret management** with SOPS encryption
- ✅ **Health monitoring** with custom endpoints
- ✅ **Real microservices architecture** with service discovery
- ✅ **External access** via NodePort services
- ✅ **One-command deployment** with Kustomize orchestration
- ✅ **Automated ECR authentication** with CronJob token refresh
- ✅ **Live configuration updates** for rapid development
- ✅ **Database management** with PostgreSQL, MongoDB, and RabbitMQ

---

*This local environment mirrors production architecture, allowing you to develop and test with confidence before deploying to cloud environments.*
