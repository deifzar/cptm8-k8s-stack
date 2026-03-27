# CPTM8 Helm Cloud Deployment Guide

This guide covers deploying CPTM8 to cloud Kubernetes environments using Helm:
- **AWS EKS** (Elastic Kubernetes Service)
- **Azure AKS** (Azure Kubernetes Service)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS EKS Deployment](#aws-eks-deployment)
3. [Azure AKS Deployment](#azure-aks-deployment)
4. [Production Considerations](#production-considerations)
5. [Secrets Management](#secrets-management)
6. [Monitoring & Observability](#monitoring--observability)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Common Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| kubectl | 1.28+ | Kubernetes CLI |
| Helm | 3.12+ | Package manager |
| SOPS | 3.8+ | Secrets encryption |
| age | 1.1+ | Encryption keys |

### AWS-Specific

| Tool | Purpose |
|------|---------|
| AWS CLI v2 | AWS authentication |
| eksctl | EKS cluster management |

```bash
# Configure AWS CLI
aws configure
aws sts get-caller-identity

# Install eksctl
brew install eksctl
```

### Azure-Specific

| Tool | Purpose |
|------|---------|
| Azure CLI | Azure authentication |
| kubelogin | AKS authentication |

```bash
# Login to Azure
az login
az account set --subscription <subscription-id>

# Install kubelogin
brew install Azure/kubelogin/kubelogin
```

---

## AWS EKS Deployment

### 1. Connect to EKS Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region eu-south-2 \
  --name cptm8-staging-cluster

# Verify connection
kubectl get nodes
kubectl cluster-info
```

### 2. Create Staging Values File

Create `values-staging-aws.yaml`:

```yaml
# values-staging-aws.yaml
# AWS EKS Staging Environment Configuration

global:
  environment: staging

  # AWS ECR Registry
  imageRegistry: 507745009364.dkr.ecr.eu-south-2.amazonaws.com
  imageTag: staging-latest
  imagePullPolicy: Always

  imagePullSecrets:
    - name: ecr-registry-secret

  # EBS storage class
  storageClass: cptm8-staging-ebs

  # Production-grade resources
  resources:
    scanner:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    frontend:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    database:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"

# Namespace
namespace:
  create: true
  resourceQuota:
    enabled: true
    requests.cpu: "8"
    requests.memory: "16Gi"
    limits.cpu: "16"
    limits.memory: "32Gi"

# AWS Configuration
config:
  aws:
    accountId: "507745009364"
    region: "eu-south-2"

  frontend:
    dashboardUrl: "https://dashboard-staging.cptm8.net"
    socketUrl: "https://socket-staging.cptm8.net"
    cloudProvider: "AWS"

  reporting:
    awsBucketRegion: "eu-south-2"
    awsBucketName: "cptm8-staging-reports"

# Storage - AWS EBS
storage:
  awsEBSStorageClass:
    create: true
    provisioner: ebs.csi.aws.com
    reclaimPolicy: Retain
    parameters:
      type: gp3
      encrypted: "true"
      iops: "3000"
      throughput: "125"

# Databases - Production sizing
postgresql:
  enabled: true
  persistence:
    size: 100Gi
    storageClass: cptm8-staging-ebs
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"

mongodb:
  enabled: true
  persistence:
    dataSize: 50Gi
    configSize: 5Gi
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"

opensearch:
  enabled: true
  nodeCount: 3
  persistence:
    size: 100Gi
  javaOpts: "-Xms2g -Xmx2g"
  resources:
    requests:
      memory: "4Gi"
      cpu: "1000m"

# Ingress - AWS ALB
ingress:
  enabled: true
  className: alb
  alb:
    scheme: internet-facing
    targetType: ip
    certificateArn: "arn:aws:acm:eu-south-2:507745009364:certificate/xxxxx"
    healthcheckPath: /health
  hosts:
    - host: dashboard-staging.cptm8.net
      paths:
        - path: /
          serviceName: dashboardm8-service
          servicePort: 3000
    - host: socket-staging.cptm8.net
      paths:
        - path: /
          serviceName: socketm8-service
          servicePort: 4000

# NodePort disabled for cloud
nodePort:
  enabled: false

# Network policies enabled
networkPolicies:
  enabled: true

# Vector logging with CloudWatch option
vector:
  enabled: true
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"

# ECR Token Refresher
cronjobs:
  ecrTokenRefresher:
    enabled: true
    schedule: "0 */8 * * *"
    image: amazon/aws-cli:2.13.0
  acrTokenRefresher:
    enabled: false

# Autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
```

### 3. Create Secrets with SOPS

```bash
# Create age key (first time only)
age-keygen -o ~/.sops/age-key.txt

# Create secrets file
cat > values-secrets-staging-aws.yaml << 'EOF'
secrets:
  method: sops
  data:
    postgresql:
      rootPassword: "your-secure-password"
      userPassword: "your-secure-password"
    mongodb:
      rootPassword: "your-secure-password"
      userPassword: "your-secure-password"
    rabbitmq:
      password: "your-secure-password"
    opensearch:
      adminPassword: "your-secure-password"
    application:
      authSecret: "your-nextauth-secret-64-chars"
    smtp:
      username: "ses-smtp-user"
      password: "ses-smtp-password"
    aws:
      s3AccessKey: "AKIAXXXXXXXX"
      s3SecretKey: "your-s3-secret"
      ecrAccessKeyId: "AKIAXXXXXXXX"
      ecrSecretAccessKey: "your-ecr-secret"
    google:
      clientId: "your-google-client-id"
      clientSecret: "your-google-client-secret"
EOF

# Encrypt with SOPS
export SOPS_AGE_KEY_FILE=~/.sops/age-key.txt
sops -e -i values-secrets-staging-aws.yaml
```

### 4. Deploy to AWS EKS

```bash
# Create namespace first
kubectl create namespace cptm8-staging

# Install with Helm
helm install cptm8 helm/cptm8 \
  --namespace cptm8-staging \
  -f helm/cptm8/values-staging-aws.yaml \
  -f <(sops -d values-secrets-staging-aws.yaml) \
  --wait \
  --timeout 10m

# Verify deployment
kubectl get pods -n cptm8-staging
kubectl get ingress -n cptm8-staging
```

### 5. Verify AWS Resources

```bash
# Check ALB is created
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'cptm8')]"

# Get ALB DNS
kubectl get ingress cptm8-ingress -n cptm8-staging \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check EBS volumes
aws ec2 describe-volumes \
  --filters "Name=tag:kubernetes.io/cluster/cptm8-staging-cluster,Values=owned"
```

---

## Azure AKS Deployment

### 1. Connect to AKS Cluster

```bash
# Get credentials
az aks get-credentials \
  --resource-group cptm8-staging-rg \
  --name cptm8-staging-aks \
  --overwrite-existing

# Verify connection
kubectl get nodes
kubectl cluster-info
```

### 2. Create Staging Values File

Create `values-staging-azure.yaml`:

```yaml
# values-staging-azure.yaml
# Azure AKS Staging Environment Configuration

global:
  environment: staging

  # Azure ACR Registry
  imageRegistry: cptm8staging.azurecr.io
  imageTag: staging-latest
  imagePullPolicy: Always

  imagePullSecrets:
    - name: acr-registry-secret

  # Azure Disk storage class
  storageClass: cptm8-staging-azure-premium

  # Production-grade resources
  resources:
    scanner:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    frontend:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"

# Azure Configuration
config:
  azure:
    subscriptionId: "your-subscription-id"
    resourceGroup: "cptm8-staging-rg"
    acrName: "cptm8staging"

  frontend:
    dashboardUrl: "https://dashboard-staging.cptm8.net"
    socketUrl: "https://socket-staging.cptm8.net"
    cloudProvider: "Azure"

# Storage - Azure Disk
storage:
  azureDiskPremiumStorageClass:
    create: true
    provisioner: disk.csi.azure.com
    reclaimPolicy: Retain
    parameters:
      skuName: Premium_LRS
      networkAccessPolicy: AllowPrivate
      enableBursting: "true"

# Databases
postgresql:
  enabled: true
  persistence:
    size: 100Gi
    storageClass: cptm8-staging-azure-premium

mongodb:
  enabled: true
  persistence:
    dataSize: 50Gi

opensearch:
  enabled: true
  nodeCount: 3
  persistence:
    size: 100Gi

# Ingress - NGINX with cert-manager
ingress:
  enabled: true
  className: nginx
  certManager:
    enabled: true
    clusterIssuer: letsencrypt-prod
    email: admin@cptm8.net
    createClusterIssuers: true
  rateLimit:
    enabled: true
    rps: "100"
    connections: "50"
  hosts:
    - host: dashboard-staging.cptm8.net
      paths:
        - path: /
          serviceName: dashboardm8-service
          servicePort: 3000
    - host: socket-staging.cptm8.net
      paths:
        - path: /
          serviceName: socketm8-service
          servicePort: 4000
  tls:
    - hosts:
        - dashboard-staging.cptm8.net
        - socket-staging.cptm8.net
      secretName: cptm8-tls-secret

# NodePort disabled
nodePort:
  enabled: false

# Network policies enabled
networkPolicies:
  enabled: true

# ACR Token Refresher (if not using managed identity)
cronjobs:
  ecrTokenRefresher:
    enabled: false
  acrTokenRefresher:
    enabled: true
    schedule: "0 */8 * * *"
    image: mcr.microsoft.com/azure-cli:2.53.0

# RBAC for ACR
rbac:
  serviceAccounts:
    acrTokenRefresher:
      create: true
      name: acr-token-refresher
  roles:
    acrTokenRefresher:
      create: true
```

### 3. Install NGINX Ingress Controller (If not installed)

```bash
# Add NGINX Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### 4. Deploy to Azure AKS

```bash
# Create namespace
kubectl create namespace cptm8-staging

# Deploy
helm install cptm8 helm/cptm8 \
  --namespace cptm8-staging \
  -f helm/cptm8/values-staging-azure.yaml \
  -f <(sops -d values-secrets-staging-azure.yaml) \
  --wait \
  --timeout 10m

# Verify deployment
kubectl get pods -n cptm8-staging
kubectl get ingress -n cptm8-staging
kubectl get certificate -n cptm8-staging  # Check TLS cert status
```

### 5. Configure DNS

```bash
# Get Load Balancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Create DNS records pointing to this IP:
# - dashboard-staging.cptm8.net → <LB_IP>
# - socket-staging.cptm8.net → <LB_IP>
```

---

## Production Considerations

### High Availability

```yaml
# Production values additions
scanners:
  asmm8:
    replicaCount: 3
  naabum8:
    replicaCount: 3
  # ... all services with 3+ replicas

frontend:
  dashboardm8:
    replicaCount: 3
  socketm8:
    replicaCount: 3

# Pod Disruption Budgets
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

### Resource Limits

```yaml
global:
  resources:
    scanner:
      requests:
        memory: "1Gi"
        cpu: "1000m"
      limits:
        memory: "2Gi"
        cpu: "2000m"
```

### Database Backups

For production, use managed database services:
- **AWS**: RDS PostgreSQL, DocumentDB, Amazon OpenSearch Service
- **Azure**: Azure Database for PostgreSQL, Cosmos DB, Azure OpenSearch

---

## Secrets Management

### Option 1: SOPS (Recommended for GitOps)

```bash
# Encrypt secrets file
sops -e values-secrets.yaml > values-secrets.enc.yaml

# Decrypt and use in Helm
helm upgrade cptm8 helm/cptm8 \
  -f <(sops -d values-secrets.enc.yaml)
```

### Option 2: External Secrets Operator

```yaml
# values.yaml
secrets:
  method: external-secrets
  externalSecrets:
    enabled: true
    secretStore: aws-secrets-manager  # or azure-key-vault
    refreshInterval: 1h
```

### Option 3: Helm Secrets Plugin

```bash
# Install plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Use encrypted values
helm secrets upgrade cptm8 helm \
  -f values-secrets.enc.yaml
```

---

## Monitoring & Observability

### Prometheus & Grafana

```bash
# Install kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Vector to Cloud Logging

AWS CloudWatch:
```yaml
vector:
  cloudwatch:
    enabled: true
    region: eu-south-2
    logGroup: /cptm8/staging/application
```

Azure Monitor:
```yaml
vector:
  azureMonitor:
    enabled: true
    workspaceId: "your-workspace-id"
```

---

## Troubleshooting

### Check Release Status

```bash
helm status cptm8 -n cptm8-staging
helm history cptm8 -n cptm8-staging
```

### Debug Failed Deployment

```bash
# Get failed pods
kubectl get pods -n cptm8-staging | grep -v Running

# Describe failing pod
kubectl describe pod <pod-name> -n cptm8-staging

# Check logs
kubectl logs <pod-name> -n cptm8-staging --previous
```

### Rollback on Failure

```bash
# Rollback to last working version
helm rollback cptm8 -n cptm8-staging

# Or specific version
helm rollback cptm8 2 -n cptm8-staging
```

### Common Issues

1. **ALB not creating**: Check AWS Load Balancer Controller is installed
2. **Certificate pending**: Verify DNS is configured, check cert-manager logs
3. **PVC pending**: Verify StorageClass exists and CSI driver is installed
4. **Image pull errors**: Check registry credentials and token refresher

---

## Next Steps

- [Values Reference](./values-reference.md) - Complete configuration options
- [Helm Quickstart](./helm-quickstart.md) - Quick command reference
- [CI/CD Pipeline Guide](../cicd-pipeline-guide.md) - Automated deployments