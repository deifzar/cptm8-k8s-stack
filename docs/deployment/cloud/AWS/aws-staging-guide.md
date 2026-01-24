# ☁️ CPTM8 AWS EKS Staging Environment Guide

This guide walks you through deploying the CPTM8 platform to **Amazon Elastic Kubernetes Service (EKS)**.

---

## 📋 Table of Contents

- [☁️ CPTM8 AWS EKS Staging Environment Guide](#️-cptm8-aws-eks-staging-environment-guide)
  - [📋 Table of Contents](#-table-of-contents)
  - [✅ Prerequisites](#-prerequisites)
  - [🏗️ Phase 1: AWS Infrastructure Setup](#️-phase-1-aws-infrastructure-setup)
    - [1.1 Install AWS CLI](#11-install-aws-cli)
    - [1.2 Install eksctl](#12-install-eksctl)
    - [1.3 Configure AWS Credentials](#13-configure-aws-credentials)
    - [1.4 Create IAM Roles for EKS](#14-create-iam-roles-for-eks)
    - [1.5 Create Amazon ECR Repositories](#15-create-amazon-ecr-repositories)
    - [1.6 Push Images to ECR](#16-push-images-to-ecr)
  - [☸️ Phase 2: Create EKS Cluster](#️-phase-2-create-eks-cluster)
    - [2.1 Create EKS Cluster Configuration](#21-create-eks-cluster-configuration)
    - [2.2 Create EKS Cluster](#22-create-eks-cluster)
    - [2.3 Update kubeconfig](#23-update-kubeconfig)
    - [2.4 Create Staging Namespace](#24-create-staging-namespace)
  - [📦 Phase 3: Install Required Components](#-phase-3-install-required-components)
    - [3.1 Install AWS Load Balancer Controller](#31-install-aws-load-balancer-controller)
    - [3.2 Install NGINX Ingress Controller (Alternative)](#32-install-nginx-ingress-controller-alternative)
    - [3.3 Install cert-manager for SSL/TLS](#33-install-cert-manager-for-ssltls)
    - [3.4 Create Let's Encrypt ClusterIssuer](#34-create-lets-encrypt-clusterissuer)
  - [🌐 Phase 4: Configure DNS with Route 53](#-phase-4-configure-dns-with-route-53)
    - [4.1 Get Load Balancer DNS Name](#41-get-load-balancer-dns-name)
    - [4.2 Create Route 53 Hosted Zone](#42-create-route-53-hosted-zone)
    - [4.3 Create DNS Records](#43-create-dns-records)
  - [💾 Phase 5: Configure AWS Storage](#-phase-5-configure-aws-storage)
    - [5.1 Install EBS CSI Driver](#51-install-ebs-csi-driver)
    - [5.2 Create StorageClass for EBS GP3](#52-create-storageclass-for-ebs-gp3)
    - [5.3 Configure S3 for Report Storage](#53-configure-s3-for-report-storage)
  - [🔐 Phase 6: Configure AWS Secrets Manager](#-phase-6-configure-aws-secrets-manager)
    - [6.1 Create Secrets in AWS Secrets Manager](#61-create-secrets-in-aws-secrets-manager)
    - [6.2 Install External Secrets Operator](#62-install-external-secrets-operator)
    - [6.3 Create SecretStore for AWS Secrets Manager](#63-create-secretstore-for-aws-secrets-manager)
    - [6.4 Create ExternalSecret Resources](#64-create-externalsecret-resources)
  - [🚀 Phase 7: Deploy CPTM8 Application](#-phase-7-deploy-cptm8-application)
    - [7.1 Configure Secrets (Alternative: SOPS)](#71-configure-secrets-alternative-sops)
    - [7.2 Update Configuration](#72-update-configuration)
    - [7.3 Update Kustomization for Your ECR](#73-update-kustomization-for-your-ecr)
    - [7.4 Deploy with Kustomize](#74-deploy-with-kustomize)
    - [7.5 Initialize MongoDB Replica Set](#75-initialize-mongodb-replica-set)
  - [🌍 Phase 8: Configure Ingress with ALB](#-phase-8-configure-ingress-with-alb)
    - [8.1 Create Ingress Resource for ALB](#81-create-ingress-resource-for-alb)
    - [8.2 Request SSL Certificate from ACM](#82-request-ssl-certificate-from-acm)
  - [✅ Phase 9: Verify Deployment](#-phase-9-verify-deployment)
    - [9.1 Check All Pods](#91-check-all-pods)
    - [9.2 Verify Services](#92-verify-services)
    - [9.3 Test Health Endpoints](#93-test-health-endpoints)
    - [9.4 Test External Access](#94-test-external-access)
  - [📊 Phase 10: Monitoring and Logging](#-phase-10-monitoring-and-logging)
    - [10.1 CloudWatch Container Insights (Already Enabled)](#101-cloudwatch-container-insights-already-enabled)
    - [10.2 Install Prometheus \& Grafana](#102-install-prometheus--grafana)
  - [🔄 Phase 11: CI/CD with GitHub Actions](#-phase-11-cicd-with-github-actions)
    - [11.1 Create IAM User for GitHub Actions](#111-create-iam-user-for-github-actions)
    - [11.2 GitHub Actions Workflow](#112-github-actions-workflow)
  - [🔧 Troubleshooting](#-troubleshooting)
    - [Common Issues](#common-issues)
    - [Useful Commands](#useful-commands)
  - [💰 Cost Optimization](#-cost-optimization)
    - [Spot Instances for Non-Critical Workloads](#spot-instances-for-non-critical-workloads)
    - [Reserved Instances](#reserved-instances)
    - [Scale Down Outside Business Hours](#scale-down-outside-business-hours)
  - [Estimated Monthly Costs (eu-south-2)](#estimated-monthly-costs-eu-south-2)
  - [🚀 Next Steps](#-next-steps)
  - [📚 Related Documentation](#-related-documentation)

---

## ✅ Prerequisites

- AWS CLI installed and configured (`aws`)
- eksctl installed
- kubectl installed
- Helm 3.x installed
- SOPS installed (for secret encryption)
- Docker images pushed to Amazon Elastic Container Registry (ECR)

---

## 🏗️ Phase 1: AWS Infrastructure Setup

### 1.1 Install AWS CLI

```bash
# Ubuntu/Debian
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# macOS
brew install awscli

# Verify installation
aws --version
```

### 1.2 Install eksctl

```bash
# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Verify installation
eksctl version
```

### 1.3 Configure AWS Credentials

```bash
# Configure AWS CLI with your credentials
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-south-2"

# Verify configuration
aws sts get-caller-identity
```

### 1.4 Create IAM Roles for EKS

Before creating the cluster, ensure you have the required IAM roles:

```bash
# Create EKS Cluster Service Role
cat > eks-cluster-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name CPTM8-EKS-Cluster-Service-Role \
  --assume-role-policy-document file://eks-cluster-trust-policy.json

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Service-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# Create EKS Node Role
cat > eks-node-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name CPTM8-EKS-Node-Role \
  --assume-role-policy-document file://eks-node-trust-policy.json

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Node-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Node-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Node-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
```

### 1.5 Create Amazon ECR Repositories

```bash
# Set your AWS account ID and region
AWS_ACCOUNT_ID="507745009364"
AWS_REGION="eu-south-2"

# Create ECR repositories for backend services
BACKEND_SERVICES="asmm8 naabum8 katanam8 num8 orchestratorm8 reportingm8"

for service in $BACKEND_SERVICES; do
  aws ecr create-repository \
    --repository-name cptm8-backend/$service \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true \
    --tags Key=Project,Value=CPTM8 Key=Environment,Value=staging
done

# Create ECR repositories for frontend services
FRONTEND_SERVICES="dashboardm8 socketm8"

for service in $FRONTEND_SERVICES; do
  aws ecr create-repository \
    --repository-name cptm8-frontend/$service \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true \
    --tags Key=Project,Value=CPTM8 Key=Environment,Value=staging
done

# List created repositories
aws ecr describe-repositories --region $AWS_REGION --query 'repositories[?starts_with(repositoryName, `cptm8`)].repositoryName' --output table
```

### 1.6 Push Images to ECR

```bash
# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Set ECR registry URL
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Navigate to your CPTM8 source code directory
cd /path/to/cptm8-source

# Build and push backend services
for service in $BACKEND_SERVICES; do
  echo "Building and pushing $service..."

  # Build the image
  docker build -t ${ECR_REGISTRY}/cptm8-backend/${service}:staging ./services/${service}

  # Push to ECR
  docker push ${ECR_REGISTRY}/cptm8-backend/${service}:staging

  # Also tag as latest
  docker tag ${ECR_REGISTRY}/cptm8-backend/${service}:staging \
    ${ECR_REGISTRY}/cptm8-backend/${service}:latest
  docker push ${ECR_REGISTRY}/cptm8-backend/${service}:latest
done

# Build and push frontend services
for service in $FRONTEND_SERVICES; do
  echo "Building and pushing $service..."

  docker build -t ${ECR_REGISTRY}/cptm8-frontend/${service}:staging ./frontend/${service}
  docker push ${ECR_REGISTRY}/cptm8-frontend/${service}:staging

  docker tag ${ECR_REGISTRY}/cptm8-frontend/${service}:staging \
    ${ECR_REGISTRY}/cptm8-frontend/${service}:latest
  docker push ${ECR_REGISTRY}/cptm8-frontend/${service}:latest
done

# Verify images were pushed
aws ecr list-images --repository-name cptm8-backend/asmm8 --region $AWS_REGION
```

---

## ☸️ Phase 2: Create EKS Cluster

### 2.1 Create EKS Cluster Configuration

Create the eksctl cluster configuration file:

```bash
cat > eksctl-cluster-config.yaml <<'EOF'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: cptm8-staging
  region: eu-south-2
  version: "1.30"

iam:
  withOIDC: true
  serviceRoleARN: arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Service-Role

managedNodeGroups:
  - name: staging-workers
    instanceType: t3.medium
    desiredCapacity: 3
    minSize: 2
    maxSize: 5
    volumeSize: 80
    ssh:
      allow: true
      publicKeyPath: ~/.ssh/id_rsa.pub
    iam:
      instanceRoleARN: arn:aws:iam::507745009364:role/CPTM8-EKS-Node-Role
      attachPolicyARNs: []
    labels:
      role: worker
      environment: staging
      project: cptm8

# Enable CloudWatch logging
cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    logRetentionInDays: 7
EOF
```

### 2.2 Create EKS Cluster

```bash
# Create the cluster (this takes 15-20 minutes)
eksctl create cluster -f eksctl-cluster-config.yaml

# Add tags to the cluster (eksctl v1alpha5 doesn't support tags in config)
aws eks tag-resource \
  --resource-arn arn:aws:eks:eu-south-2:507745009364:cluster/cptm8-staging \
  --tags Project=CPTM8,Environment=staging,ManagedBy=eksctl
```

### 2.3 Update kubeconfig

```bash
# Update kubeconfig to access the cluster
aws eks update-kubeconfig --region eu-south-2 --name cptm8-staging

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 2.4 Create Staging Namespace

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

### 3.1 Install AWS Load Balancer Controller

```bash
# Create IAM OIDC provider for the cluster
eksctl utils associate-iam-oidc-provider --cluster=cptm8-staging --approve

# Download IAM policy for AWS Load Balancer Controller
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create service account for the controller
eksctl create iamserviceaccount \
  --cluster=cptm8-staging \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Add Helm repo and install controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cptm8-staging \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 3.2 Install NGINX Ingress Controller (Alternative)

If you prefer NGINX over AWS ALB:

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller with NLB
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"=true \
  --set controller.replicaCount=2

# Wait for external IP assignment
kubectl get svc -n ingress-nginx -w
```

### 3.3 Install cert-manager for SSL/TLS

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

### 3.4 Create Let's Encrypt ClusterIssuer

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

---

## 🌐 Phase 4: Configure DNS with Route 53

### 4.1 Get Load Balancer DNS Name

```bash
# For AWS Load Balancer Controller (ALB)
ALB_DNS=$(kubectl get ingress -n cptm8-staging -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"

# For NGINX Ingress (NLB)
NLB_DNS=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "NLB DNS: $NLB_DNS"
```

### 4.2 Create Route 53 Hosted Zone

```bash
# Create hosted zone (if you don't have one)
aws route53 create-hosted-zone \
  --name staging.cptm8.net \
  --caller-reference "cptm8-staging-$(date +%s)"

# Get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name staging.cptm8.net \
  --query 'HostedZones[0].Id' \
  --output text | sed 's|/hostedzone/||')
```

### 4.3 Create DNS Records

```bash
# Create A records pointing to the load balancer
cat > route53-records.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "dashboard-staging.cptm8.net",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z1H1FL5HABSF5",
          "DNSName": "${ALB_DNS}",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "socket-staging.cptm8.net",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z1H1FL5HABSF5",
          "DNSName": "${ALB_DNS}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

# Apply the changes
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://route53-records.json
```

> **Note:** Replace `Z1H1FL5HABSF5` with the hosted zone ID for your ALB region. See [AWS ELB Hosted Zone IDs](https://docs.aws.amazon.com/general/latest/gr/elb.html).

---

## 💾 Phase 5: Configure AWS Storage

### 5.1 Install EBS CSI Driver

```bash
# Create IAM role for EBS CSI Driver
eksctl create iamserviceaccount \
  --cluster=cptm8-staging \
  --namespace=kube-system \
  --name=ebs-csi-controller-sa \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# Install EBS CSI Driver addon
aws eks create-addon \
  --cluster-name cptm8-staging \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole

# Verify installation
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

### 5.2 Create StorageClass for EBS GP3

```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cptm8-staging-gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  throughput: "250"
  iops: "3000"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
EOF
```

### 5.3 Configure S3 for Report Storage

```bash
# Create S3 bucket for reports
aws s3api create-bucket \
  --bucket cptm8-staging-reports \
  --region eu-south-2 \
  --create-bucket-configuration LocationConstraint=eu-south-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket cptm8-staging-reports \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket cptm8-staging-reports \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Create IAM policy for S3 access
cat > s3-access-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::cptm8-staging-reports",
        "arn:aws:s3:::cptm8-staging-reports/*"
      ]
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name CPTM8-S3-Reports-Access \
  --policy-document file://s3-access-policy.json
```

---

## 🔐 Phase 6: Configure AWS Secrets Manager

### 6.1 Create Secrets in AWS Secrets Manager

```bash
# Create database credentials secret
aws secretsmanager create-secret \
  --name cptm8/staging/database \
  --description "CPTM8 Staging Database Credentials" \
  --secret-string '{
    "POSTGRES_USER": "cptm8_user",
    "POSTGRES_PASSWORD": "your-secure-password",
    "POSTGRES_DB": "cptm8",
    "MONGODB_ROOT_USER": "admin",
    "MONGODB_ROOT_PASSWORD": "your-mongo-password",
    "MONGODB_DATABASE": "cptm8_chat",
    "RABBITMQ_DEFAULT_USER": "cptm8",
    "RABBITMQ_DEFAULT_PASS": "your-rabbitmq-password"
  }' \
  --tags Key=Project,Value=CPTM8 Key=Environment,Value=staging

# Create application secrets
aws secretsmanager create-secret \
  --name cptm8/staging/application \
  --description "CPTM8 Staging Application Secrets" \
  --secret-string '{
    "JWT_SECRET": "your-jwt-secret",
    "ENCRYPTION_KEY": "your-encryption-key",
    "AWS_ACCESS_KEY_ID": "your-s3-access-key",
    "AWS_SECRET_ACCESS_KEY": "your-s3-secret-key"
  }' \
  --tags Key=Project,Value=CPTM8 Key=Environment,Value=staging
```

### 6.2 Install External Secrets Operator

```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

# Create IAM role for External Secrets
eksctl create iamserviceaccount \
  --cluster=cptm8-staging \
  --namespace=cptm8-staging \
  --name=external-secrets-sa \
  --role-name CPTM8-ExternalSecrets-Role \
  --attach-policy-arn=arn:aws:iam::aws:policy/SecretsManagerReadWrite \
  --approve
```

### 6.3 Create SecretStore for AWS Secrets Manager

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: cptm8-staging
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-south-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
EOF
```

### 6.4 Create ExternalSecret Resources

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secrets
  namespace: cptm8-staging
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: database-secrets
    creationPolicy: Owner
  data:
  - secretKey: POSTGRES_USER
    remoteRef:
      key: cptm8/staging/database
      property: POSTGRES_USER
  - secretKey: POSTGRES_PASSWORD
    remoteRef:
      key: cptm8/staging/database
      property: POSTGRES_PASSWORD
  - secretKey: POSTGRES_DB
    remoteRef:
      key: cptm8/staging/database
      property: POSTGRES_DB
  - secretKey: MONGODB_ROOT_USER
    remoteRef:
      key: cptm8/staging/database
      property: MONGODB_ROOT_USER
  - secretKey: MONGODB_ROOT_PASSWORD
    remoteRef:
      key: cptm8/staging/database
      property: MONGODB_ROOT_PASSWORD
  - secretKey: RABBITMQ_DEFAULT_USER
    remoteRef:
      key: cptm8/staging/database
      property: RABBITMQ_DEFAULT_USER
  - secretKey: RABBITMQ_DEFAULT_PASS
    remoteRef:
      key: cptm8/staging/database
      property: RABBITMQ_DEFAULT_PASS
EOF
```

---

## 🚀 Phase 7: Deploy CPTM8 Application

### 7.1 Configure Secrets (Alternative: SOPS)

If not using AWS Secrets Manager, use SOPS encryption:

```bash
cd /path/to/Kubernetes/overlays/staging-aws

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

### 7.2 Update Configuration

Edit `configmaps/config.yaml` and update:

1. **ECR Registry**: Update image references to your ECR
2. **AWS Region**: Update `AWS_REGION`
3. **S3 Bucket**: Update `AWS_S3_BUCKET`
4. **Domain URLs**: Verify dashboard and socket URLs match your DNS

### 7.3 Update Kustomization for Your ECR

Edit `kustomization.yaml` and update the `images` section:

```yaml
images:
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/asmm8
    newTag: staging
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/naabum8
    newTag: staging
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/katanam8
    newTag: staging
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/num8
    newTag: staging
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/orchestratorm8
    newTag: staging
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/reportingm8
    newTag: staging
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-frontend/dashboardm8
    newTag: staging
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-frontend/socketm8
    newTag: staging
```

### 7.4 Deploy with Kustomize

```bash
# Validate the kustomization
kubectl kustomize overlays/staging-aws

# Deploy secrets first (if using SOPS)
sops -d overlays/staging-aws/secrets/secrets.encrypted.yaml | kubectl apply -f -

# Deploy the full stack
kubectl apply -k overlays/staging-aws

# Watch deployment progress
kubectl get pods -n cptm8-staging -w
```

### 7.5 Initialize MongoDB Replica Set

```bash
# Wait for MongoDB pod to be ready
kubectl wait --for=condition=ready pod -l app=mongodb-primary -n cptm8-staging --timeout=300s

# Run MongoDB init job
kubectl apply -f overlays/staging-aws/jobs/mongodb-init-job.yaml

# Check job status
kubectl get jobs -n cptm8-staging
kubectl logs job/mongodb-init -n cptm8-staging
```

---

## 🌍 Phase 8: Configure Ingress with ALB

### 8.1 Create Ingress Resource for ALB

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cptm8-ingress
  namespace: cptm8-staging
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:eu-south-2:507745009364:certificate/your-cert-arn
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/group.name: cptm8-staging
spec:
  rules:
  - host: dashboard-staging.cptm8.net
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dashboardm8-service
            port:
              number: 3000
  - host: socket-staging.cptm8.net
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: socketm8-service
            port:
              number: 4000
EOF
```

### 8.2 Request SSL Certificate from ACM

```bash
# Request certificate
aws acm request-certificate \
  --domain-name "*.staging.cptm8.net" \
  --validation-method DNS \
  --subject-alternative-names "dashboard-staging.cptm8.net" "socket-staging.cptm8.net" \
  --tags Key=Project,Value=CPTM8

# Get certificate ARN
CERT_ARN=$(aws acm list-certificates --query "CertificateSummaryList[?DomainName=='*.staging.cptm8.net'].CertificateArn" --output text)

# Get DNS validation records and add them to Route 53
aws acm describe-certificate --certificate-arn $CERT_ARN --query 'Certificate.DomainValidationOptions'
```

---

## ✅ Phase 9: Verify Deployment

### 9.1 Check All Pods

```bash
# All pods should be Running
kubectl get pods -n cptm8-staging

# Check for any issues
kubectl get events -n cptm8-staging --sort-by='.lastTimestamp' | tail -20
```

### 9.2 Verify Services

```bash
# Check services
kubectl get svc -n cptm8-staging

# Check ingress
kubectl get ingress -n cptm8-staging

# Check ALB provisioning
kubectl describe ingress cptm8-ingress -n cptm8-staging
```

### 9.3 Test Health Endpoints

```bash
# Test each microservice
for service in asmm8 naabum8 katanam8 num8 reportingm8 orchestratorm8; do
  echo "Testing $service..."
  kubectl exec -n cptm8-staging deployment/$service -- curl -sf http://localhost:8000/health || echo "FAILED"
done

# Test frontend
kubectl exec -n cptm8-staging deployment/dashboardm8 -- curl -sf http://localhost:3000 || echo "Frontend check failed"
```

### 9.4 Test External Access

```bash
# Test HTTPS endpoints (after DNS propagation and certificate validation)
curl -I https://dashboard-staging.cptm8.net
curl -I https://socket-staging.cptm8.net
```

---

## 📊 Phase 10: Monitoring and Logging

### 10.1 CloudWatch Container Insights (Already Enabled)

Access monitoring via AWS Console:
1. Navigate to CloudWatch
2. Click "Container Insights" for EKS monitoring
3. View performance, logs, and metrics

### 10.2 Install Prometheus & Grafana

```bash
# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create values file
cat > prometheus-values-aws.yaml <<EOF
grafana:
  adminPassword: "ChangeMe123!"
  persistence:
    enabled: true
    storageClassName: cptm8-staging-gp3
    size: 10Gi
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/group.name: cptm8-staging
    hosts:
      - grafana-staging.cptm8.net

prometheus:
  prometheusSpec:
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: cptm8-staging-gp3
          resources:
            requests:
              storage: 50Gi
EOF

# Install
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f prometheus-values-aws.yaml
```

---

## 🔄 Phase 11: CI/CD with GitHub Actions

### 11.1 Create IAM User for GitHub Actions

```bash
# Create IAM user
aws iam create-user --user-name cptm8-github-actions

# Create access key
aws iam create-access-key --user-name cptm8-github-actions

# Save the output - you'll need AccessKeyId and SecretAccessKey for GitHub secrets

# Create and attach policy
cat > github-actions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster"
      ],
      "Resource": "arn:aws:eks:eu-south-2:507745009364:cluster/cptm8-staging"
    }
  ]
}
EOF

aws iam put-user-policy \
  --user-name cptm8-github-actions \
  --policy-name CPTM8-GitHubActions-Policy \
  --policy-document file://github-actions-policy.json
```

### 11.2 GitHub Actions Workflow

Create `.github/workflows/deploy-aws-staging.yml`:

```yaml
name: Deploy to AWS EKS Staging

on:
  push:
    branches:
      - staging
  workflow_dispatch:

env:
  AWS_REGION: eu-south-2
  ECR_REGISTRY: 507745009364.dkr.ecr.eu-south-2.amazonaws.com
  EKS_CLUSTER: cptm8-staging

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    - name: Build and push Docker images
      run: |
        for service in asmm8 naabum8 katanam8 num8 reportingm8 orchestratorm8; do
          docker build -t ${{ env.ECR_REGISTRY }}/cptm8-backend/$service:staging-${{ github.sha }} ./services/$service
          docker push ${{ env.ECR_REGISTRY }}/cptm8-backend/$service:staging-${{ github.sha }}
          docker tag ${{ env.ECR_REGISTRY }}/cptm8-backend/$service:staging-${{ github.sha }} \
            ${{ env.ECR_REGISTRY }}/cptm8-backend/$service:staging-latest
          docker push ${{ env.ECR_REGISTRY }}/cptm8-backend/$service:staging-latest
        done

        for service in dashboardm8 socketm8; do
          docker build -t ${{ env.ECR_REGISTRY }}/cptm8-frontend/$service:staging-${{ github.sha }} ./frontend/$service
          docker push ${{ env.ECR_REGISTRY }}/cptm8-frontend/$service:staging-${{ github.sha }}
          docker tag ${{ env.ECR_REGISTRY }}/cptm8-frontend/$service:staging-${{ github.sha }} \
            ${{ env.ECR_REGISTRY }}/cptm8-frontend/$service:staging-latest
          docker push ${{ env.ECR_REGISTRY }}/cptm8-frontend/$service:staging-latest
        done

    - name: Update kubeconfig
      run: |
        aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.EKS_CLUSTER }}

    - name: Deploy to EKS
      run: |
        kubectl apply -k Kubernetes/overlays/staging-aws
        kubectl rollout status deployment -n cptm8-staging --timeout=10m

    - name: Run smoke tests
      run: |
        for service in asmm8 naabum8 katanam8 num8 reportingm8; do
          kubectl exec -n cptm8-staging deployment/$service -- curl -f http://localhost:8000/health || exit 1
        done
```

---

## 🔧 Troubleshooting

### Common Issues

**1. Pods stuck in Pending**
```bash
# Check events
kubectl describe pod <pod-name> -n cptm8-staging

# Common causes:
# - Insufficient resources: Scale up node group
# - PVC not binding: Check EBS CSI Driver is installed
```

**2. Image pull errors**
```bash
# Verify ECR authentication
aws ecr get-login-password --region eu-south-2 | docker login --username AWS --password-stdin 507745009364.dkr.ecr.eu-south-2.amazonaws.com

# Check node IAM role has ECR access
kubectl describe pod <pod-name> -n cptm8-staging | grep -A5 "Events"
```

**3. ALB not provisioning**
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify ingress resource
kubectl describe ingress cptm8-ingress -n cptm8-staging
```

**4. EBS volumes not attaching**
```bash
# Check EBS CSI Driver
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check PVC status
kubectl get pvc -n cptm8-staging
kubectl describe pvc <pvc-name> -n cptm8-staging
```

**5. SSL certificate not working**
```bash
# Check certificate status in ACM
aws acm describe-certificate --certificate-arn $CERT_ARN

# Ensure DNS validation records are in place
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID
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

# Check node group status
eksctl get nodegroup --cluster=cptm8-staging
```

---

## 💰 Cost Optimization

### Spot Instances for Non-Critical Workloads

```bash
# Add spot node group
eksctl create nodegroup \
  --cluster=cptm8-staging \
  --name=spot-workers \
  --node-type=t3.medium \
  --nodes=2 \
  --nodes-min=1 \
  --nodes-max=5 \
  --spot \
  --instance-types=t3.medium,t3a.medium

# Add tolerations to pods that can run on spot nodes
```

### Reserved Instances

For staging environments running 24/7, consider Reserved Instances or Savings Plans:

```bash
# View current usage for recommendations
aws ce get-reservation-purchase-recommendation \
  --service "Amazon Elastic Compute Cloud - Compute"
```

### Scale Down Outside Business Hours

```bash
# Scale down node group
eksctl scale nodegroup \
  --cluster=cptm8-staging \
  --name=staging-workers \
  --nodes=1 \
  --nodes-min=1

# Scale up for work hours
eksctl scale nodegroup \
  --cluster=cptm8-staging \
  --name=staging-workers \
  --nodes=3 \
  --nodes-min=2
```

## Estimated Monthly Costs (eu-south-2)

| Resource | Configuration | Est. Cost/Month |
|----------|--------------|-----------------|
| EKS Cluster | Control plane | ~$73 |
| EC2 Instances (3x t3.medium) | 2 vCPU, 4GB each | ~$90 |
| EBS Storage (gp3) | 300GB total | ~$25 |
| Application Load Balancer | Standard | ~$20 |
| NAT Gateway | Standard | ~$35 |
| Route 53 | Hosted zone + queries | ~$1 |
| CloudWatch Logs | 10GB/month | ~$5 |
| ECR Storage | 10GB | ~$1 |
| **Total** | | **~$250/month** |

---

## 🚀 Next Steps

1. **Security Hardening**: Enable AWS GuardDuty for threat detection
2. **Backup Strategy**: Configure Velero with S3 for cluster backup
3. **Disaster Recovery**: Document recovery procedures
4. **Production Prep**: Create production overlay with multi-AZ setup
5. **Cost Monitoring**: Set up AWS Cost Explorer alerts

---

## 📚 Related Documentation

- [Staging Environment Overview](../staging-environment-guide.md) - High-level architecture and common patterns
- [Azure AKS Staging Guide](../Azure/azure-staging-guide.md) - Alternative cloud provider deployment
- [Azure Identity Concepts](../Azure/azure-identity-concepts.md) - Identity management reference
- [Security Review](../SECURITY_REVIEW.md) - Security audit findings and recommendations

---

*Last updated: January 2026*
