# ☁️ CPTM8 Azure AKS Staging Environment Guide

This guide walks you through deploying the CPTM8 platform to **Azure Kubernetes Service (AKS)**.

---

## 📋 Table of Contents

- [☁️ CPTM8 Azure AKS Staging Environment Guide](#️-cptm8-azure-aks-staging-environment-guide)
  - [📋 Table of Contents](#-table-of-contents)
  - [✅ Prerequisites](#-prerequisites)
  - [🏗️ Phase 1: Azure Infrastructure Setup](#️-phase-1-azure-infrastructure-setup)
    - [1.1 Install Azure CLI](#11-install-azure-cli)
    - [1.2 Login and Set Subscription](#12-login-and-set-subscription)
    - [1.3 Register Required Resource Providers](#13-register-required-resource-providers)
    - [1.4 Create Resource Group](#14-create-resource-group)
    - [1.5 Create Azure Container Registry (ACR)](#15-create-azure-container-registry-acr)
    - [1.6 Push Images to ACR](#16-push-images-to-acr)
      - [Option A: Build and Push from Local Repository (Recommended for Development)](#option-a-build-and-push-from-local-repository-recommended-for-development)
      - [Option B: Pull from AWS ECR and Push to ACR](#option-b-pull-from-aws-ecr-and-push-to-acr)
      - [Option C: Build Images Directly in ACR (No Local Docker Required)](#option-c-build-images-directly-in-acr-no-local-docker-required)
      - [Verify Images in ACR](#verify-images-in-acr)
  - [☸️ Phase 2: Create AKS Cluster](#️-phase-2-create-aks-cluster)
    - [2.1 Create AKS Cluster with System Node Pool](#21-create-aks-cluster-with-system-node-pool)
    - [2.2 Get AKS Credentials](#22-get-aks-credentials)
    - [2.3 Create Staging Namespace](#23-create-staging-namespace)
  - [📦 Phase 3: Install Required Components](#-phase-3-install-required-components)
    - [3.1 Install NGINX Ingress Controller](#31-install-nginx-ingress-controller)
    - [3.2 Install cert-manager for SSL/TLS](#32-install-cert-manager-for-ssltls)
    - [3.3 (Optional) Install Azure Application Gateway Ingress Controller (AGIC)](#33-optional-install-azure-application-gateway-ingress-controller-agic)
  - [🌐 Phase 4: Configure DNS](#-phase-4-configure-dns)
    - [4.1 Get Ingress External IP](#41-get-ingress-external-ip)
    - [4.2 Configure DNS Records](#42-configure-dns-records)
  - [🚀 Phase 5: Deploy CPTM8 Application](#-phase-5-deploy-cptm8-application)
    - [5.1 Configure Secrets](#51-configure-secrets)
    - [5.2 Update Configuration](#52-update-configuration)
    - [5.3 Update Kustomization for Your ACR](#53-update-kustomization-for-your-acr)
    - [5.4 Deploy with Kustomize](#54-deploy-with-kustomize)
    - [5.5 Initialize MongoDB Replica Set](#55-initialize-mongodb-replica-set)
  - [✅ Phase 6: Verify Deployment](#-phase-6-verify-deployment)
    - [6.1 Check All Pods](#61-check-all-pods)
    - [6.2 Verify Services](#62-verify-services)
    - [6.3 Test Health Endpoints](#63-test-health-endpoints)
    - [6.4 Test External Access](#64-test-external-access)
  - [🔷 Phase 7: Azure-Specific Configurations](#-phase-7-azure-specific-configurations)
    - [7.1 Configure Azure Blob Storage for Reports](#71-configure-azure-blob-storage-for-reports)
    - [7.2 Configure Azure Key Vault (Recommended for Secrets)](#72-configure-azure-key-vault-recommended-for-secrets)
    - [7.3 Install External Secrets Operator (for Key Vault Integration)](#73-install-external-secrets-operator-for-key-vault-integration)
  - [📊 Phase 8: Monitoring and Logging](#-phase-8-monitoring-and-logging)
    - [8.1 Azure Monitor (Already Enabled)](#81-azure-monitor-already-enabled)
    - [8.2 Install Prometheus \& Grafana (Optional)](#82-install-prometheus--grafana-optional)
  - [🔄 Phase 9: CI/CD with GitHub Actions](#-phase-9-cicd-with-github-actions)
    - [9.1 Create Service Principal for GitHub Actions](#91-create-service-principal-for-github-actions)
    - [9.2 GitHub Actions Workflow](#92-github-actions-workflow)
  - [🔧 Troubleshooting](#-troubleshooting)
    - [Common Issues](#common-issues)
    - [Useful Commands](#useful-commands)
  - [💰 Cost Optimization](#-cost-optimization)
    - [Reserved Instances](#reserved-instances)
    - [Spot Instances for Non-Critical Workloads](#spot-instances-for-non-critical-workloads)
    - [Scale Down Outside Business Hours](#scale-down-outside-business-hours)
  - [Estimated Monthly Costs (West Europe)](#estimated-monthly-costs-west-europe)
  - [🚀 Next Steps](#-next-steps)
  - [📚 Related Documentation](#-related-documentation)

---

## ✅ Prerequisites

- Azure CLI installed (`az`)
- kubectl installed
- Helm 3.x installed
- SOPS installed (for secret encryption)
- Docker images pushed to Azure Container Registry (ACR)

---

## 🏗️ Phase 1: Azure Infrastructure Setup

### 1.1 Install Azure CLI

```bash
# Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# macOS
brew install azure-cli

# Verify installation
az --version
```

### 1.2 Login and Set Subscription

```bash
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set the subscription to use
az account set --subscription "Your-Subscription-Name-or-ID"

# Verify current subscription
az account show --output table
```

### 1.3 Register Required Resource Providers

Azure subscriptions must have resource providers registered before creating resources. This is a one-time setup per subscription.

```bash
# Register all required resource providers for CPTM8 deployment
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.OperationsManagement

# Check registration status (wait until all show "Registered")
az provider show --namespace Microsoft.ContainerRegistry --query "registrationState" -o tsv
az provider show --namespace Microsoft.ContainerService --query "registrationState" -o tsv
az provider show --namespace Microsoft.Network --query "registrationState" -o tsv
az provider show --namespace Microsoft.Compute --query "registrationState" -o tsv
az provider show --namespace Microsoft.Storage --query "registrationState" -o tsv
az provider show --namespace Microsoft.KeyVault --query "registrationState" -o tsv
az provider show --namespace Microsoft.OperationalInsights --query "registrationState" -o tsv
az provider show --namespace Microsoft.OperationsManagement --query "registrationState" -o tsv

# Or check all at once
az provider list --query "[?registrationState=='Registered'] | [?contains(namespace, 'Container') || contains(namespace, 'Network') || contains(namespace, 'Compute') || contains(namespace, 'Storage') || contains(namespace, 'KeyVault')].{Namespace:namespace, State:registrationState}" -o table
```

> **Note:** Registration typically takes 1-2 minutes per provider. You can proceed once each shows `Registered`.

### 1.4 Create Resource Group

```bash
# Create resource group in your preferred region
# Recommended regions: westeurope, northeurope, uksouth, eastus2
az group create \
  --name cptm8-staging-rg \
  --location westeurope \
  --tags Project=CPTM8 Environment=staging ManagedBy=az-cli
```

### 1.5 Create Azure Container Registry (ACR)

```bash
# Create ACR (Basic tier for staging, Standard/Premium for production)
az acr create \
  --resource-group cptm8-staging-rg \
  --name cptm8acr \
  --sku Basic \
  --admin-enabled false \
  --tags Project=CPTM8 Environment=staging

# Get ACR login server name
ACR_LOGIN_SERVER=$(az acr show --name cptm8acr --query loginServer --output tsv)
echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

### 1.6 Push Images to ACR

You have three options for pushing images to ACR: from your local repository (Option A), from AWS ECR (Option B), or using ACR Build to build directly in Azure (Option C).

#### Option A: Build and Push from Local Repository (Recommended for Development)

This method builds images directly from your local source code and pushes them to ACR.

```bash
# Login to ACR
az acr login --name cptm8acr

# Set your ACR name
ACR_NAME="cptm8acr"

# Navigate to your CPTM8 source code directory
# Adjust this path to match your local setup
cd /path/to/cptm8-source

# Build and push backend services
# Each service should have a Dockerfile in its directory
BACKEND_SERVICES="asmm8 naabum8 katanam8 num8 orchestratorm8 reportingm8"

for service in $BACKEND_SERVICES; do
  echo "Building and pushing $service..."

  # Build the image from local source
  # Adjust the path to your service's Dockerfile location
  docker build -t ${ACR_NAME}.azurecr.io/cptm8-backend/${service}:staging ./services/${service}

  # Push to ACR
  docker push ${ACR_NAME}.azurecr.io/cptm8-backend/${service}:staging

  # Also tag as latest for convenience
  docker tag ${ACR_NAME}.azurecr.io/cptm8-backend/${service}:staging \
    ${ACR_NAME}.azurecr.io/cptm8-backend/${service}:latest
  docker push ${ACR_NAME}.azurecr.io/cptm8-backend/${service}:latest
done

# Build and push frontend services
FRONTEND_SERVICES="dashboardm8 socketm8"

for service in $FRONTEND_SERVICES; do
  echo "Building and pushing $service..."

  docker build -t ${ACR_NAME}.azurecr.io/cptm8-frontend/${service}:staging ./frontend/${service}
  docker push ${ACR_NAME}.azurecr.io/cptm8-frontend/${service}:staging

  docker tag ${ACR_NAME}.azurecr.io/cptm8-frontend/${service}:staging \
    ${ACR_NAME}.azurecr.io/cptm8-frontend/${service}:latest
  docker push ${ACR_NAME}.azurecr.io/cptm8-frontend/${service}:latest
done

# Verify images were pushed
az acr repository list --name ${ACR_NAME} --output table
```

**If your images are already built locally**, you can tag and push them directly:

```bash
# Login to ACR
az acr login --name cptm8acr

ACR_NAME="cptm8acr"

# List your local images to find the correct names
docker images | grep -E "(asmm8|naabum8|katanam8|num8|orchestratorm8|reportingm8|dashboardm8|socketm8)"

# Tag and push each local image
# Replace <local-image-name> with your actual local image name/tag

# Example for a backend service:
docker tag <local-image-name>:latest ${ACR_NAME}.azurecr.io/cptm8-backend/asmm8:staging
docker push ${ACR_NAME}.azurecr.io/cptm8-backend/asmm8:staging

# Example for a frontend service:
docker tag <local-image-name>:latest ${ACR_NAME}.azurecr.io/cptm8-frontend/dashboardm8:staging
docker push ${ACR_NAME}.azurecr.io/cptm8-frontend/dashboardm8:staging

# Automated script if your local images follow a naming convention:
# Adjust the LOCAL_PREFIX to match your local image naming
LOCAL_PREFIX="cptm8"

for service in asmm8 naabum8 katanam8 num8 orchestratorm8 reportingm8; do
  docker tag ${LOCAL_PREFIX}/${service}:latest ${ACR_NAME}.azurecr.io/cptm8-backend/${service}:staging
  docker push ${ACR_NAME}.azurecr.io/cptm8-backend/${service}:staging
done

for service in dashboardm8 socketm8; do
  docker tag ${LOCAL_PREFIX}/${service}:latest ${ACR_NAME}.azurecr.io/cptm8-frontend/${service}:staging
  docker push ${ACR_NAME}.azurecr.io/cptm8-frontend/${service}:staging
done
```

#### Option B: Pull from AWS ECR and Push to ACR

If your images are already in AWS ECR, you can pull and re-push them to ACR:

```bash
# Login to ACR
az acr login --name cptm8acr

# Login to AWS ECR (requires AWS CLI configured)
aws ecr get-login-password --region eu-south-2 | docker login --username AWS --password-stdin 507745009364.dkr.ecr.eu-south-2.amazonaws.com

# Tag and push images from AWS ECR to Azure ACR
SERVICES="asmm8 naabum8 katanam8 num8 orchestratorm8 reportingm8"

for service in $SERVICES; do
  # Pull from ECR
  docker pull 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/$service:staging

  # Tag for ACR
  docker tag 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/$service:staging \
    cptm8acr.azurecr.io/cptm8-backend/$service:staging

  # Push to ACR
  docker push cptm8acr.azurecr.io/cptm8-backend/$service:staging
done

# For frontend services
for service in dashboardm8 socketm8; do
  docker pull 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-frontend/$service:staging
  docker tag 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-frontend/$service:staging \
    cptm8acr.azurecr.io/cptm8-frontend/$service:staging
  docker push cptm8acr.azurecr.io/cptm8-frontend/$service:staging
done
```

#### Option C: Build Images Directly in ACR (No Local Docker Required)

ACR can build images from source code without needing Docker installed locally. This is useful for CI/CD or if you have limited local resources.

```bash
# Build directly in ACR from a Git repository
# ACR will clone the repo, build the image, and store it
az acr build \
  --registry cptm8acr \
  --image cptm8-backend/asmm8:staging \
  --file ./services/asmm8/Dockerfile \
  https://github.com/your-org/cptm8.git#main:services/asmm8

# Or build from a local directory (uploads source to ACR for building)
cd /path/to/cptm8-source/services/asmm8
az acr build \
  --registry cptm8acr \
  --image cptm8-backend/asmm8:staging \
  --file Dockerfile \
  .

# Build all services using ACR Build
cd /path/to/cptm8-source

for service in asmm8 naabum8 katanam8 num8 orchestratorm8 reportingm8; do
  echo "Building $service in ACR..."
  az acr build \
    --registry cptm8acr \
    --image cptm8-backend/${service}:staging \
    --file ./services/${service}/Dockerfile \
    ./services/${service}
done

for service in dashboardm8 socketm8; do
  echo "Building $service in ACR..."
  az acr build \
    --registry cptm8acr \
    --image cptm8-frontend/${service}:staging \
    --file ./frontend/${service}/Dockerfile \
    ./frontend/${service}
done
```

#### Verify Images in ACR

```bash
# List all repositories in ACR
az acr repository list --name cptm8acr --output table

# Show tags for a specific repository
az acr repository show-tags --name cptm8acr --repository cptm8-backend/asmm8 --output table

# Show detailed information about an image
az acr repository show --name cptm8acr --image cptm8-backend/asmm8:staging
```

---

## ☸️ Phase 2: Create AKS Cluster

### 2.1 Create AKS Cluster with System Node Pool

```bash
# Create AKS cluster
az aks create \
  --resource-group cptm8-staging-rg \
  --name cptm8-staging-aks \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin azure \
  --network-policy calico \
  --load-balancer-sku standard \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 6 \
  --zones 1 2 3 \
  --enable-addons monitoring \
  --attach-acr cptm8acr \
  --tags Project=CPTM8 Environment=staging

# This command:
# - Creates a 3-node cluster with Standard_D4s_v3 VMs (4 vCPU, 16GB RAM)
# - Uses managed identity (no service principal management)
# - Enables Azure CNI networking with Calico network policies
# - Enables cluster autoscaler (2-6 nodes)
# - Distributes across 3 availability zones for HA
# - Attaches ACR for seamless image pulling
# - Enables Azure Monitor for containers
# - Instead 'generate-ssh-keys', set you own SSH key: --ssh-key-value ~/.ssh/id_rsa.pub 
```

### 2.2 Get AKS Credentials

```bash
# Get credentials for kubectl
az aks get-credentials \
  --resource-group cptm8-staging-rg \
  --name cptm8-staging-aks \
  --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 2.3 Create Staging Namespace

```bash
# Create namespace
kubectl create namespace cptm8-staging

# Set as default context
kubectl config set-context --current --namespace=cptm8-staging

# Verify
kubectl config view --minify | grep namespace
```

---

## 📦 Phase 3: Install Required Components

### 3.1 Install NGINX Ingress Controller

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.replicaCount=2

# Wait for external IP assignment
kubectl get svc -n ingress-nginx -w
```

### 3.2 Install cert-manager for SSL/TLS

```bash
# Add Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set ingressShim.defaultIssuerName=letsencrypt-prod \
  --set ingressShim.defaultIssuerKind=ClusterIssuer

# Verify installation
kubectl get pods -n cert-manager
```

### 3.3 (Optional) Install Azure Application Gateway Ingress Controller (AGIC)

If you prefer Azure Application Gateway over NGINX:

```bash
# Enable AGIC addon
az aks enable-addons \
  --resource-group cptm8-staging-rg \
  --name cptm8-staging-aks \
  --addons ingress-appgw \
  --appgw-name cptm8-staging-appgw \
  --appgw-subnet-cidr "10.225.0.0/16"
```

---

## 🌐 Phase 4: Configure DNS

### 4.1 Get Ingress External IP

```bash
# Get the external IP of the NGINX ingress controller
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"
```

### 4.2 Configure DNS Records

Add the following DNS records to your domain (cptm8.net):

| Type | Name | Value |
|------|------|-------|
| A | dashboard-staging | `<EXTERNAL_IP>` |
| A | socket-staging | `<EXTERNAL_IP>` |

Or create an Azure DNS Zone:

```bash
# Create DNS Zone
az network dns zone create \
  --resource-group cptm8-staging-rg \
  --name staging.cptm8.net

# Add A records
az network dns record-set a add-record \
  --resource-group cptm8-staging-rg \
  --zone-name staging.cptm8.net \
  --record-set-name dashboard \
  --ipv4-address $EXTERNAL_IP

az network dns record-set a add-record \
  --resource-group cptm8-staging-rg \
  --zone-name staging.cptm8.net \
  --record-set-name socket \
  --ipv4-address $EXTERNAL_IP
```

---

## 🚀 Phase 5: Deploy CPTM8 Application

### 5.1 Configure Secrets

```bash
cd /path/to/Kubernetes/overlays/staging-azure

# Copy and edit secrets
cp secrets/secrets.example.yaml secrets/secrets.yaml

# Edit with your actual values
# IMPORTANT: Use base64 encoding for all values
# echo -n "your-password" | base64

# Encrypt with SOPS
sops -e secrets/secrets.yaml > secrets/secrets.encrypted.yaml

# Remove unencrypted file
rm secrets/secrets.yaml
```

### 5.2 Update Configuration

Edit `configmaps/config.yaml` and update:

1. **ACR Name**: Update `AZURE_ACR_NAME` with your ACR name
2. **Subscription ID**: Update `AZURE_SUBSCRIPTION_ID`
3. **Resource Group**: Update `AZURE_RESOURCE_GROUP`
4. **Domain URLs**: Verify dashboard and socket URLs match your DNS

### 5.3 Update Kustomization for Your ACR

Edit `kustomization.yaml` and update the `images` section with your ACR name:

```yaml
images:
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-frontend/dashboardm8
    newName: YOUR_ACR_NAME.azurecr.io/cptm8-frontend/dashboardm8
    newTag: staging
  # ... update all image references
```

### 5.4 Deploy with Kustomize

```bash
# Validate the kustomization
kubectl kustomize overlays/staging-azure

# Deploy secrets first (decrypt and apply)
sops -d overlays/staging-azure/secrets/secrets.encrypted.yaml | kubectl apply -f -

# Deploy the full stack
kubectl apply -k overlays/staging-azure

# Watch deployment progress
kubectl get pods -n cptm8-staging -w
```

### 5.5 Initialize MongoDB Replica Set

```bash
# Wait for MongoDB pod to be ready
kubectl wait --for=condition=ready pod -l app=mongodb-primary -n cptm8-staging --timeout=300s

# Run MongoDB init job
kubectl apply -f overlays/staging-azure/jobs/mongodb-init-job.yaml

# Check job status
kubectl get jobs -n cptm8-staging
kubectl logs job/mongodb-init -n cptm8-staging
```

---

## ✅ Phase 6: Verify Deployment

### 6.1 Check All Pods

```bash
# All pods should be Running
kubectl get pods -n cptm8-staging

# Check for any issues
kubectl get events -n cptm8-staging --sort-by='.lastTimestamp' | tail -20
```

### 6.2 Verify Services

```bash
# Check services
kubectl get svc -n cptm8-staging

# Check ingress
kubectl get ingress -n cptm8-staging

# Check certificates (if using cert-manager)
kubectl get certificates -n cptm8-staging
```

### 6.3 Test Health Endpoints

```bash
# Test each microservice
for service in asmm8 naabum8 katanam8 num8 reportingm8 orchestratorm8; do
  echo "Testing $service..."
  kubectl exec -n cptm8-staging deployment/$service -- curl -sf http://localhost:8000/health || echo "FAILED"
done

# Test frontend
kubectl exec -n cptm8-staging deployment/dashboardm8 -- curl -sf http://localhost:3000 || echo "Frontend check failed"
```

### 6.4 Test External Access

```bash
# Test HTTPS endpoints (after DNS propagation)
curl -I https://dashboard-staging.cptm8.net
curl -I https://socket-staging.cptm8.net
```

---

## 🔷 Phase 7: Azure-Specific Configurations

### 7.1 Configure Azure Blob Storage for Reports

If using Azure Blob Storage instead of AWS S3:

```bash
# Create storage account
az storage account create \
  --name cptm8reports \
  --resource-group cptm8-staging-rg \
  --location westeurope \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot

# Create container
az storage container create \
  --name reports \
  --account-name cptm8reports \
  --auth-mode login

# Get connection string for secrets
az storage account show-connection-string \
  --name cptm8reports \
  --resource-group cptm8-staging-rg
```

### 7.2 Configure Azure Key Vault (Recommended for Secrets)

```bash
# Create Key Vault
az keyvault create \
  --name cptm8-staging-kv \
  --resource-group cptm8-staging-rg \
  --location westeurope \
  --enable-rbac-authorization

# Get AKS managed identity
AKS_IDENTITY=$(az aks show \
  --resource-group cptm8-staging-rg \
  --name cptm8-staging-aks \
  --query identityProfile.kubeletidentity.objectId -o tsv)

# Grant Key Vault access to AKS
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $AKS_IDENTITY \
  --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/cptm8-staging-rg/providers/Microsoft.KeyVault/vaults/cptm8-staging-kv
```

### 7.3 Install External Secrets Operator (for Key Vault Integration)

```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

# Create SecretStore for Azure Key Vault
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: cptm8-staging
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      vaultUrl: "https://cptm8-staging-kv.vault.azure.net"
EOF
```

---

## 📊 Phase 8: Monitoring and Logging

### 8.1 Azure Monitor (Already Enabled)

Access monitoring via Azure Portal:
1. Navigate to AKS cluster
2. Click "Insights" for container monitoring
3. Click "Logs" for Log Analytics queries

### 8.2 Install Prometheus & Grafana (Optional)

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create values file
cat > prometheus-values-azure.yaml <<EOF
grafana:
  adminPassword: "ChangeMe123!"
  persistence:
    enabled: true
    storageClassName: cptm8-staging-azure-premium
    size: 10Gi
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana-staging.cptm8.net
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana-staging.cptm8.net

prometheus:
  prometheusSpec:
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: cptm8-staging-azure-premium
          resources:
            requests:
              storage: 50Gi
EOF

# Install
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f prometheus-values-azure.yaml
```

---

## 🔄 Phase 9: CI/CD with GitHub Actions

### 9.1 Create Service Principal for GitHub Actions

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "cptm8-github-actions" \
  --role contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/cptm8-staging-rg \
  --sdk-auth

# Save the output JSON - you'll need it for GitHub secrets
```

### 9.2 GitHub Actions Workflow

Create `.github/workflows/deploy-azure-staging.yml`:

```yaml
name: Deploy to Azure AKS Staging

on:
  push:
    branches:
      - staging
  workflow_dispatch:

env:
  AZURE_RESOURCE_GROUP: cptm8-staging-rg
  AKS_CLUSTER_NAME: cptm8-staging-aks
  ACR_NAME: cptm8acr

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: Login to ACR
      run: az acr login --name ${{ env.ACR_NAME }}

    - name: Build and push images
      run: |
        for service in asmm8 naabum8 katanam8 num8 reportingm8 orchestratorm8; do
          docker build -t ${{ env.ACR_NAME }}.azurecr.io/cptm8-backend/$service:staging-${{ github.sha }} ./services/$service
          docker push ${{ env.ACR_NAME }}.azurecr.io/cptm8-backend/$service:staging-${{ github.sha }}
        done

    - name: Get AKS credentials
      run: |
        az aks get-credentials \
          --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
          --name ${{ env.AKS_CLUSTER_NAME }}

    - name: Deploy to AKS
      run: |
        kubectl apply -k Kubernetes/overlays/staging-azure
        kubectl rollout status deployment -n cptm8-staging --timeout=10m
```

---

## 🔧 Troubleshooting

### Common Issues

**1. Resource Provider Not Registered**
```bash
# Error: "The subscription is not registered to use namespace 'Microsoft.ContainerRegistry'"
# Solution: Register the required resource provider
az provider register --namespace Microsoft.ContainerRegistry

# Wait for registration to complete (check status)
az provider show --namespace Microsoft.ContainerRegistry --query "registrationState" -o tsv

# For other resources, register the corresponding provider:
# - AKS: Microsoft.ContainerService
# - Networking: Microsoft.Network
# - VMs: Microsoft.Compute
# - Storage: Microsoft.Storage
# - Key Vault: Microsoft.KeyVault
```

**2. Pods stuck in Pending**
```bash
# Check events
kubectl describe pod <pod-name> -n cptm8-staging

# Common causes:
# - Insufficient resources: Scale up node pool
# - PVC not binding: Check StorageClass exists
```

**3. Image pull errors**
```bash
# Verify ACR integration
az aks check-acr --name cptm8-staging-aks --resource-group cptm8-staging-rg --acr cptm8acr

# If issues, re-attach ACR
az aks update --name cptm8-staging-aks --resource-group cptm8-staging-rg --attach-acr cptm8acr
```

**4. Ingress not working**
```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verify ingress resource
kubectl describe ingress cptm8-ingress -n cptm8-staging
```

**5. SSL certificate issues**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate status
kubectl describe certificate -n cptm8-staging
```

### Useful Commands

```bash
# Get all resources in namespace
kubectl get all -n cptm8-staging

# View logs with follow
kubectl logs -f deployment/asmm8 -n cptm8-staging

# Execute into a pod
kubectl exec -it deployment/dashboardm8 -n cptm8-staging -- /bin/sh

# Port forward for debugging
kubectl port-forward svc/postgresql-service 5432:5432 -n cptm8-staging

# Scale deployment
kubectl scale deployment asmm8 --replicas=3 -n cptm8-staging
```

---

## 💰 Cost Optimization

### Reserved Instances

For staging environments running 24/7, consider Azure Reserved Instances:

```bash
# View pricing
az reservations catalog show \
  --reserved-resource-type VirtualMachines \
  --location westeurope
```

### Spot Instances for Non-Critical Workloads

Add a spot node pool for cost savings:

```bash
az aks nodepool add \
  --resource-group cptm8-staging-rg \
  --cluster-name cptm8-staging-aks \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 2 \
  --node-vm-size Standard_D4s_v3 \
  --labels workload=spot-tolerant

# Add tolerations to pods that can run on spot nodes
```

### Scale Down Outside Business Hours

```bash
# Stop cluster (for non-production)
az aks stop --name cptm8-staging-aks --resource-group cptm8-staging-rg

# Start cluster
az aks start --name cptm8-staging-aks --resource-group cptm8-staging-rg
```

## Estimated Monthly Costs (West Europe)

| Resource | Configuration | Est. Cost/Month |
|----------|--------------|-----------------|
| AKS Cluster | Free tier | $0 |
| Node Pool (3x D4s_v3) | 4 vCPU, 16GB each | ~$350 |
| Premium SSD Storage | 370GB total | ~$50 |
| Azure Load Balancer | Standard | ~$20 |
| Azure Container Registry | Basic | ~$5 |
| Azure Monitor | Basic | ~$25 |
| **Total** | | **~$450/month** |

---

## 🚀 Next Steps

1. **Security Hardening**: Enable Azure Defender for Kubernetes
2. **Backup Strategy**: Configure Velero for cluster backup
3. **Disaster Recovery**: Document recovery procedures
4. **Production Prep**: Create production overlay with multi-region setup

---

## 📚 Related Documentation

- [Staging Environment Overview](../staging-environment-guide.md) - High-level architecture and common patterns
- [AWS EKS Staging Guide](../AWS/aws-staging-guide.md) - Alternative cloud provider deployment
- [Azure Identity Concepts](./azure-identity-concepts.md) - Comprehensive Azure IAM reference (AZ-500/SC-100)
- [Security Review](../SECURITY_REVIEW.md) - Security audit findings and recommendations

---

*Last updated: January 2026*
