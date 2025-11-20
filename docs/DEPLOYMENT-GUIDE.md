# 🚀 CPTM8 Kubernetes Deployment Guide - Kind Local Development

## 🎯 Purpose

This guide provides step-by-step instructions for deploying your CPTM8 platform on **Kind (Kubernetes in Docker)** for local development. Kind is perfect for learning Kubernetes without cloud costs.

> **💡 Learning Note**: Kind creates a real Kubernetes cluster inside Docker containers, giving you production-like experience locally.

## 🔧 Step 1: Kind Setup

### **Install Kind**
```bash
# Download Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version
```

### **Create Your Cluster**
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
  - containerPort: 80
    hostPort: 80
  - containerPort: 443  
    hostPort: 443
  - containerPort: 30080
    hostPort: 3000
  - containerPort: 30081
    hostPort: 4000
  - containerPort: 30672
    hostPort: 15672
EOF

# Switch to your cluster context
kubectl cluster-info --context kind-cptm8-dev
kubectl get nodes --context kind-cptm8-dev
```

> **🎓 Learning Note**: `extraPortMappings` allows external access to your services - essential for frontend applications.

### **Install NGINX Ingress**
```bash
# Install NGINX Ingress Controller (required for domain routing)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## 📦 Step 2: Deploy Your Platform

### **Prepare Environment**
```bash
# Create your isolated namespace
kubectl create namespace cptm8-dev

# Apply your encrypted secrets (SOPS magic!)
sops -d secrets/secrets-dev.encrypted.yaml | kubectl apply -f -

### Make sure you have set up the environment variables or located the key file in the expected location

```

> **🔐 Security Note**: SOPS keeps your secrets encrypted in git but decrypts them only during deployment.
> **🔑 RBAC Note**: The RBAC configuration creates necessary ServiceAccounts (like `vector-sa`, `ecr-token-refresher`) that pods need to run with proper permissions.
> **🤖 ECR Automation**: The RBAC configuration includes a CronJob that automatically refreshes the ECR authentication token every 8 hours, eliminating manual token management.

### **🚀 Option 1: One-Command Deployment (Recommended)**

```bash
# Deploy everything in correct dependency order with Kustomize
kubectl apply -k .

# IMPORTANT: Manually trigger ECR token refresh for first-time deployment
# (The CronJob won't run until the first scheduled time - 8 hours from now)
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-initial -n cptm8-dev

# Wait for token refresh to complete (should take 10-20 seconds)
kubectl wait --for=condition=complete job/ecr-token-initial -n cptm8-dev --timeout=60s

# Verify the ECR secret was created successfully
kubectl get secret ecr-registry-secret -n cptm8-dev

# IMPORTANT: Initialize MongoDB replica set (run ONCE after MongoDB is ready)
# Wait for MongoDB pod to be ready first
kubectl wait --for=condition=ready pod -l app=mongodb-primary -n cptm8-dev --timeout=300s

# Run the MongoDB initialization job
kubectl apply -f jobs/mongodb-init-job-dev.yaml

# Wait for MongoDB initialization to complete (should take 30-60 seconds)
kubectl wait --for=condition=complete job/mongodb-init -n cptm8-dev --timeout=120s

# Verify MongoDB initialization was successful
kubectl logs -n cptm8-dev job/mongodb-init --tail=30

# Watch the deployment progress
kubectl get pods -n cptm8-dev -w
```

> **🎓 Learning Note**: Your `kustomization.yaml` manages deployment order automatically:
> 1. RBAC (ServiceAccounts, Roles, RoleBindings)
> 2. Storage (StorageClasses, PersistentVolumes)
> 3. ConfigMaps (application configuration)
> 4. Services (networking)
> 5. Infrastructure (PostgreSQL, RabbitMQ, MongoDB)
> 6. Search (OpenSearch cluster)
> 7. Backend services (microservices)
> 8. Frontend (dashboards)
> 9. Logging (Vector)
> 10. Ingress (external access)
> 11. CronJobs (ECR token refresh every 8 hours)
>
> **MongoDB Initialization**: The MongoDB init job (`jobs/mongodb-init-job-dev.yaml`) is run **manually** after MongoDB is ready. This job initializes the replica set, creates admin user, and sets up the application database. It only needs to run once per cluster setup.

### **🔧 Option 2: Manual Step-by-Step (Educational)**

If you want to understand the deployment process step-by-step:

```bash
# 1. RBAC (must be first - creates ServiceAccounts needed by pods)
kubectl apply -f RBAC/rbca-dev.yaml

# 1b. IMPORTANT: Manually trigger ECR token refresh for first-time deployment
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-initial -n cptm8-dev
kubectl wait --for=condition=complete job/ecr-token-initial -n cptm8-dev --timeout=60s
kubectl get secret ecr-registry-secret -n cptm8-dev

# 2. Storage and configuration
kubectl apply -f storage/storageclass-dev.yaml
kubectl apply -f configmaps/
kubectl apply -f services/services-dev.yaml

# 2. Databases (the foundation)
kubectl apply -f deployments/postgresql-dev.yaml
kubectl apply -f deployments/mongodb-dev.yaml  
kubectl apply -f deployments/rabbitmq-dev.yaml

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgresqlm8 -n cptm8-dev --timeout=300s

# 2b. IMPORTANT: Initialize MongoDB replica set (run ONCE after MongoDB is ready)
kubectl wait --for=condition=ready pod -l app=mongodb-primary -n cptm8-dev --timeout=300s
kubectl apply -f jobs/mongodb-init-job-dev.yaml

# Wait for MongoDB initialization to complete
kubectl wait --for=condition=complete job/mongodb-init -n cptm8-dev --timeout=120s

# Verify MongoDB initialization was successful
kubectl logs -n cptm8-dev job/mongodb-init --tail=20

# 3. Search infrastructure
kubectl apply -f deployments/opensearch-dev.yaml
kubectl wait --for=condition=ready pod -l app=opensearch-node1 -n cptm8-dev --timeout=600s

# 4. Logging
kubectl apply -f deployments/vector-dev.yaml

# 5. Your Go microservices
kubectl apply -f deployments/orchestratorm8-dev.yaml
kubectl apply -f deployments/asmm8-dev.yaml
kubectl apply -f deployments/naabum8-dev.yaml
kubectl apply -f deployments/katanam8-dev.yaml
kubectl apply -f deployments/num8-dev.yaml
kubectl apply -f deployments/reportingm8-dev.yaml

# 6. Frontend applications
kubectl apply -f deployments/dashboardm8-dev.yaml
kubectl apply -f deployments/socketm8-dev.yaml
```

> **⏱️ Tip**: Option 1 (Kustomize) handles all the waiting and dependency management for you!

## 🔍 Step 3: Verify Deployment

### **Check Everything is Running**
```bash
# Get overview of all resources
kubectl get pods,svc,pvc -n cptm8-dev

# Should show all pods as Running or Ready
```

### **Verify ECR Token Automation**
```bash
# Check the CronJob is scheduled
kubectl get cronjob -n cptm8-dev ecr-token-refresher

# Verify ecr-registry-secret exists (should already be created during deployment)
kubectl get secret -n cptm8-dev ecr-registry-secret

# Check the next scheduled run time
kubectl get cronjob -n cptm8-dev ecr-token-refresher -o jsonpath='{.status.lastScheduleTime}'

# View recent CronJob history
kubectl get jobs -n cptm8-dev | grep ecr-token
```

> **🤖 ECR Note**: The CronJob runs every 8 hours automatically. The initial manual job creation (done during deployment) ensures your cluster has ECR credentials immediately without waiting for the first scheduled run.

### **Test Backend Health**
```bash
# Test a Go service health endpoint
kubectl exec -n cptm8-dev deployment/asmm8 -- curl -f http://localhost:8000/health

# Test database connectivity through ready endpoint  
kubectl exec -n cptm8-dev deployment/asmm8 -- curl -f http://localhost:8000/ready
```

> **🎓 Learning Note**: `/health` checks the service itself, `/ready` checks if dependencies are available.

### **Monitor Service Startup**
```bash
# Watch pods come online
kubectl get pods -n cptm8-dev -w

# Check logs if something fails
kubectl logs -f deployment/asmm8 -n cptm8-dev
```

## 🌐 Step 4: Access Your Applications

> **🏗️ Environment Note**: This section covers **development (Kind)** setup. For staging/production, see separate sections below.

### **Option A: Development (Kind) - NodePort Services** ⭐ Recommended

For local development with Kind, use NodePort services that leverage Kind's port mappings:

```bash
# Apply NodePort services (development only)
kubectl apply -f services/frontend-nodeport-dev.yaml

# Verify services are created
kubectl get svc -n cptm8-dev | grep nodeport
# Expected output:
# dashboardm8-nodeport   NodePort   10.x.x.x   <none>   3000:30080/TCP
# socketm8-nodeport      NodePort   10.x.x.x   <none>   4000:30081/TCP
```

**Access your applications:**
```bash
# Dashboard - Next.js frontend
http://localhost:3000

# Socket.io - Real-time server
http://localhost:4000

# Test connectivity
curl -s http://localhost:3000 | head -5
```

> **💡 How it works**: Kind's `extraPortMappings` in cluster config forwards:
> - Host `localhost:3000` → NodePort `30080` → dashboardm8 pod port `3000`
> - Host `localhost:4000` → NodePort `30081` → socketm8 pod port `4000`

### **Option B: Staging/Production - LoadBalancer or Ingress**

**For cloud deployments (AWS, GCP, Azure):**

```bash
# Option 1: LoadBalancer services (creates cloud load balancer)
kubectl apply -f services/frontend-external-services-[ENV].yaml

# Option 2: Ingress with domain routing (recommended for production)
kubectl apply -f ingress/frontend-ingress-[ENV].yaml
```

> **⚠️ Important**: LoadBalancer services will remain `<pending>` on Kind. Only use in cloud environments.

### **Verify Applications**
```bash
# Check frontend pods
kubectl get pods -n cptm8-dev | grep -E "(dashboardm8|socketm8)"

# Check application logs
kubectl logs -n cptm8-dev -l app=dashboardm8 --tail=20

# Test backend connectivity
kubectl exec -n cptm8-dev deployment/dashboardm8 -- wget -qO- http://localhost:3000
```

> **📖 For more details**: See **FRONTEND-EXPOSURE-GUIDE.md** for:
> - Port forwarding for debugging
> - Custom domain setup with Ingress
> - SSL/TLS configuration for production

## 🛠️ Daily Development Workflow

### **Update a Service**
```bash
# After code changes, restart deployment
kubectl rollout restart deployment/asmm8 -n cptm8-dev

# Watch the rollout
kubectl rollout status deployment/asmm8 -n cptm8-dev
```

### **ECR Image Updates**
```bash
# After pushing new images to ECR, simply restart deployments
# (Token is already valid - CronJob refreshes it every 8 hours)
kubectl rollout restart deployment -n cptm8-dev -l tier=application
kubectl rollout restart deployment -n cptm8-dev -l tier=frontend

# Optional: If token has expired (unlikely), manually refresh it
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-manual -n cptm8-dev
kubectl wait --for=condition=complete job/ecr-token-manual -n cptm8-dev --timeout=60s

# Check next scheduled token refresh
kubectl get cronjob -n cptm8-dev ecr-token-refresher
```

### **Debug Issues**
```bash
# Describe a failing pod
kubectl describe pod <pod-name> -n cptm8-dev

# Check service endpoints
kubectl get endpoints -n cptm8-dev

# View environment variables
kubectl exec -n cptm8-dev deployment/asmm8 -- env | grep POSTGRESQL

# Debug ECR authentication issues
kubectl describe pod <pod-name> -n cptm8-dev | grep -A5 "ImagePullBackOff"
kubectl logs -n cptm8-dev cronjob/ecr-token-refresher --tail=50
```

### **Live Configuration Updates**

Your backend services (asmm8, naabum8, katanam8, num8, reportingm8, orchestratorm8) support live configuration updates using the **ConfigMap Hot-Reload + emptyDir** pattern.

#### **Architecture Overview**

```
ConfigMap (Source of Truth)
    ↓ Init Container Copies
emptyDir (Writable Storage)
    ↓ subPath Mounts
/app/configs/ (Application Config Directory)
```

**What's Writable:**
- `asmm8`: 4 files (configuration.yaml, configuration_template.yaml, subfinderconfig.yaml, subfinderprovider-config.yaml)
- Other services: 2 files (configuration.yaml, configuration_template.yaml)

#### **Option 1: Quick Live Edit** (Lost on Pod Restart)

**Use case:** Testing config changes, debugging, temporary tweaks

```bash
# Edit configuration file directly
kubectl exec -it deployment/asmm8 -n cptm8-dev -- vi /app/configs/subfinderconfig.yaml

# Or use kubectl cp to copy local file
kubectl cp ./subfinderconfig.yaml cptm8-dev/asmm8-<pod-name>:/app/configs/

# Verify changes
kubectl exec deployment/asmm8 -n cptm8-dev -- cat /app/configs/subfinderconfig.yaml

# Reload app if it supports SIGHUP (optional)
kubectl exec deployment/asmm8 -n cptm8-dev -- kill -HUP 1

# Or restart to pick up changes
kubectl rollout restart deployment/asmm8 -n cptm8-dev
```

**⚠️ Important:** Changes made with `kubectl exec` are **ephemeral** - they're lost when the pod restarts.

#### **Option 2: Persistent Change** (Survives Pod Restart)

**Use case:** Permanent configuration updates, production-ready changes

```bash
# 1. Update ConfigMap with new configuration
kubectl edit configmap configuration-template-asmm8 -n cptm8-dev

# 2. Restart deployment to reinitialize from updated ConfigMap
kubectl rollout restart deployment/asmm8 -n cptm8-dev

# 3. Verify changes persisted
kubectl exec deployment/asmm8 -n cptm8-dev -- cat /app/configs/subfinderconfig.yaml

# Alternative: Update ConfigMap from file
kubectl create configmap configuration-template-asmm8 \
  --from-file=subfinderconfig.yaml=./configs/subfinderconfig.yaml \
  --from-file=configuration_template.yaml=./configs/configuration_template.yaml \
  --dry-run=client -o yaml | kubectl apply -f -
```

**✅ Benefit:** Changes persist across pod restarts and are version-controlled in git.

#### **Verify Configuration Setup**

```bash
# Check what files exist in /app/configs
kubectl exec deployment/asmm8 -n cptm8-dev -- ls -la /app/configs/

# Verify wordlists still accessible (Docker image files)
kubectl exec deployment/asmm8 -n cptm8-dev -- ls -la /app/configs/wordlist/

# Test writability
kubectl exec deployment/asmm8 -n cptm8-dev -- sh -c \
  "echo '# test comment' >> /app/configs/subfinderconfig.yaml && echo 'Success!'"

# View init container logs (shows ConfigMap copy)
kubectl logs -n cptm8-dev <pod-name> -c fix-app-ownership
```

#### **Common Use Cases**

**Add new API keys (subfinderprovider-config.yaml):**
```bash
# Quick test (lost on restart)
kubectl exec -it deployment/asmm8 -n cptm8-dev -- vi /app/configs/subfinderprovider-config.yaml

# Permanent (survives restart)
kubectl edit configmap configuration-template-asmm8 -n cptm8-dev
kubectl rollout restart deployment/asmm8 -n cptm8-dev
```

**Adjust tool settings (subfinderconfig.yaml):**
```bash
# Edit configuration
kubectl exec -it deployment/asmm8 -n cptm8-dev -- vi /app/configs/subfinderconfig.yaml

# Test without restart (if app supports hot-reload)
# Otherwise restart: kubectl rollout restart deployment/asmm8 -n cptm8-dev
```

**Update application config (configuration_template.yaml):**
```bash
# This affects what the entrypoint generates into configuration.yaml
kubectl edit configmap configuration-template-asmm8 -n cptm8-dev
kubectl delete pod -l app=asmm8 -n cptm8-dev  # Force restart to regenerate
```

> **🎓 Learning Note**: This pattern gives you the best of both worlds:
> - **Quick live edits** for rapid development/debugging (ephemeral)
> - **ConfigMap updates** for permanent, version-controlled changes (persistent)
> - **Preserves Docker image files** (wordlists) using subPath overlays

### **MongoDB Issues**
```bash
# Check MongoDB replica set status
kubectl exec -n cptm8-dev mongodb-primary-0 -- mongosh --eval "rs.status()" --quiet

# Verify database was created
kubectl exec -n cptm8-dev mongodb-primary-0 -- mongosh --eval "db.adminCommand('listDatabases')" --quiet

# Check if MongoDB init job completed successfully
kubectl get job mongodb-init -n cptm8-dev
kubectl logs -n cptm8-dev job/mongodb-init --tail=50

# If MongoDB init job failed, delete and re-run it
kubectl delete job mongodb-init -n cptm8-dev
kubectl apply -f jobs/mongodb-init-job-dev.yaml
kubectl wait --for=condition=complete job/mongodb-init -n cptm8-dev --timeout=120s

# Test MongoDB connection from dashboardm8
kubectl exec -n cptm8-dev deployment/dashboardm8 -- env | grep PMG_DATABASE_URL
```

## 🧹 Cleanup

### **Remove Everything**
```bash
# Quick cleanup - delete namespace
kubectl delete namespace cptm8-dev

# Complete cleanup - delete cluster
kind delete cluster --name cptm8-dev
```

## 🎯 What You've Accomplished

✅ **Local Kubernetes cluster** running your entire platform
✅ **Production-like environment** with proper networking and storage
✅ **Secure secret management** with SOPS encryption
✅ **Health monitoring** with custom endpoints
✅ **Real microservices architecture** with service discovery
✅ **External access** with NGINX Ingress Controller and custom domains
✅ **One-command deployment** with Kustomize orchestration
✅ **Automated ECR authentication** with CronJob token refresh every 8 hours
✅ **Live configuration updates** with emptyDir + ConfigMap pattern for rapid development

> **🎉 Congratulations!** You've successfully deployed a complex microservices platform on Kubernetes with production-ready patterns. This is exactly how it would work in production, just running locally on Kind.

## 📚 Next Steps

- Review **k8s-migration-guide.md** to understand the concepts you're using
- Check **FRONTEND-EXPOSURE-GUIDE.md** for accessing your web applications
- Try scaling a deployment: `kubectl scale deployment asmm8 --replicas=3 -n cptm8-dev`