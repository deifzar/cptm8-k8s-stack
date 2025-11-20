# 🚀 CPTM8 Staging Environment Guide - Cloud Kubernetes Migration

## 📋 Executive Summary

This guide transitions your CPTM8 platform from local Kind development to a **production-grade staging environment** on cloud Kubernetes (AWS EKS, GCP GKE, or Azure AKS). We'll build on your existing architecture while introducing cloud-native patterns, monitoring, security hardening, and CI/CD automation.

## 🏗️ Staging Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    STAGING ENVIRONMENT                          │
├─────────────────────────────────────────────────────────────────┤
│ 🌐 Cloud Provider: AWS/GCP/Azure                               │
│ 🎯 Cluster: Managed Kubernetes (EKS/GKE/AKS)                   │
│ 🔐 Namespace: cptm8-staging (isolated from dev/prod)           │
│ 💾 Storage: Cloud persistent disks (auto-provisioned)          │
│ 🌍 Networking: Cloud Load Balancer + Ingress with SSL/TLS      │
│ 📊 Monitoring: Prometheus + Grafana                            │
│ 📝 Logging: Vector → OpenSearch (existing)                     │
│ 🔄 CI/CD: GitHub Actions + Helm                                │
│ 🛡️ Security: Network Policies + Pod Security Standards         │
└─────────────────────────────────────────────────────────────────┘
```

## 📊 Phase 1: Cloud Infrastructure Setup

### 1.1 Choose Your Cloud Provider

Based on your requirements (AWS S3 usage, no vendor lock-in preference), I recommend **AWS EKS** for staging, but I'll provide options for all major providers.

#### **Option A: AWS EKS (Recommended)**

```bash
# Install eksctl CLI tool
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster with managed node group
eksctl create cluster \
  --profile <profile>
  --name cptm8-staging \
  --region us-east-1 \
  --version 1.28 \
  --nodegroup-name staging-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed \
  --with-oidc \
  --ssh-access \
  --ssh-public-key ~/.ssh/id_rsa.pub \
  --alb-ingress-access \
  --full-ecr-access

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cptm8-staging
```

#### **Option B: Google GKE**

```bash
# Create GKE cluster
gcloud container clusters create cptm8-staging \
  --zone us-central1-a \
  --num-nodes 3 \
  --node-locations us-central1-a,us-central1-b \
  --machine-type n2-standard-2 \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 5 \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-stackdriver-kubernetes \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing

# Get credentials
gcloud container clusters get-credentials cptm8-staging --zone us-central1-a
```

#### **Option C: Azure AKS**

```bash
# Create resource group
az group create --name cptm8-staging-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group cptm8-staging-rg \
  --name cptm8-staging \
  --node-count 3 \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --vm-set-type VirtualMachineScaleSets \
  --load-balancer-sku standard \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 5

# Get credentials
az aks get-credentials --resource-group cptm8-staging-rg --name cptm8-staging
```

### 1.2 Verify Cluster Access

```bash
# Check cluster connection
kubectl cluster-info
kubectl get nodes

# Create staging namespace
kubectl create namespace cptm8-staging

# Set default namespace for convenience
kubectl config set-context --current --namespace=cptm8-staging
```

## 📁 Phase 2: Directory Structure for Staging

Create a staging-specific overlay structure using Kustomize:

```bash
# Reorganize your Kubernetes directory for multi-environment support
cd /home/deifzar/Documents/Self-Employed/Securetivity/CPT/Kubernetes

# Create base and overlays structure
mkdir -p base overlays/{dev,staging,prod}

# Move common resources to base
mv deployments base/
mv services base/
mv configmaps base/
mv secrets base/

# Create base kustomization.yaml
cat > base/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployments/postgresql.yaml
  - deployments/mongodb.yaml
  - deployments/rabbitmq.yaml
  - deployments/opensearch.yaml
  - deployments/vector.yaml
  - deployments/orchestratorm8.yaml
  - deployments/asmm8.yaml
  - deployments/naabum8.yaml
  - deployments/katanam8.yaml
  - deployments/num8.yaml
  - deployments/reportingm8.yaml
  - deployments/dashboardm8.yaml
  - deployments/socketm8.yaml
  - services/database-services.yaml
  - services/backend-services.yaml
  - services/frontend-services.yaml
  - configmaps/common-config.yaml
EOF

# Create staging overlay
cat > overlays/staging/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cptm8-staging

bases:
  - ../../base

patchesStrategicMerge:
  - patches/resource-limits.yaml
  - patches/replicas.yaml
  - patches/storage.yaml

configMapGenerator:
  - name: staging-config
    literals:
      - ENVIRONMENT=staging
      - LOG_LEVEL=info

secretGenerator:
  - name: staging-secrets
    envs:
      - secrets.env

images:
  - name: 123456789012.dkr.ecr.us-east-1.amazonaws.com/cptm8/asmm8
    newTag: staging-latest
  # Add all your images here

replicas:
  - name: dashboardm8
    count: 2
  - name: socketm8
    count: 2
  - name: asmm8
    count: 2
EOF
```

## 🔧 Phase 3: Cloud Storage Configuration

### 3.1 Dynamic Storage Provisioning

Create cloud-specific StorageClasses:

**AWS EBS StorageClass:**
```yaml
# overlays/staging/storage/storageclass-aws.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: staging-gp3-retain
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  throughput: "250"
  iops: "3000"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
```

**GCP Persistent Disk StorageClass:**
```yaml
# overlays/staging/storage/storageclass-gcp.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: staging-pd-ssd-retain
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
```

### 3.2 Update StatefulSets for Cloud Storage

```yaml
# overlays/staging/patches/storage.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresqlm8
spec:
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: staging-gp3-retain  # Cloud storage class
      resources:
        requests:
          storage: 50Gi  # Larger for staging
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb-primary
spec:
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: staging-gp3-retain
      resources:
        requests:
          storage: 100Gi
```

## 🌐 Phase 4: Networking & Ingress

### 4.1 Install AWS Load Balancer Controller (AWS Only)

```bash
# Install AWS Load Balancer Controller for better integration
eksctl utils associate-iam-oidc-provider --cluster=cptm8-staging --approve

# Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

# Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=cptm8-staging \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::123456789012:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install using Helm
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cptm8-staging \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 4.2 Configure Ingress with SSL/TLS

```yaml
# overlays/staging/ingress/ingress-staging.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cptm8-ingress
  namespace: cptm8-staging
  annotations:
    # AWS ALB annotations
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/healthcheck-path: /health
    
    # Security headers
    alb.ingress.kubernetes.io/actions.ssl-redirect: |
      {"Type": "redirect", "RedirectConfig": {"Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}
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
  - host: api-staging.cptm8.net
    http:
      paths:
      - path: /socket
        pathType: Prefix
        backend:
          service:
            name: socketm8-service
            port:
              number: 4000
  tls:
  - hosts:
    - dashboard-staging.cptm8.net
    - api-staging.cptm8.net
```

## 📊 Phase 5: Monitoring & Observability

### 5.1 Deploy Prometheus & Grafana

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
cat > prometheus-values-staging.yaml <<EOF
grafana:
  adminPassword: "ChangeMeSecurePassword123!"
  ingress:
    enabled: true
    hosts:
      - grafana-staging.cptm8.net
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana-staging.cptm8.net
  persistence:
    enabled: true
    storageClassName: staging-gp3-retain
    size: 10Gi

prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: staging-gp3-retain
          resources:
            requests:
              storage: 50Gi

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: staging-gp3-retain
          resources:
            requests:
              storage: 10Gi
EOF

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f prometheus-values-staging.yaml
```

### 5.2 Configure Application Metrics

Update your Go services to expose Prometheus metrics:

```go
// Add to your Go services
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

func setupMetrics(router *mux.Router) {
    // Create custom metrics
    httpDuration := prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_duration_seconds",
            Help: "Duration of HTTP requests in seconds",
        },
        []string{"path", "method", "status"},
    )
    
    prometheus.MustRegister(httpDuration)
    
    // Expose metrics endpoint
    router.Handle("/metrics", promhttp.Handler())
}
```

Add ServiceMonitor for Prometheus scraping:

```yaml
# overlays/staging/monitoring/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cptm8-apps
  namespace: cptm8-staging
spec:
  selector:
    matchLabels:
      tier: application
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## 🔐 Phase 6: Security Hardening

### 6.1 Network Policies

```yaml
# overlays/staging/security/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: cptm8-staging
spec:
  podSelector:
    matchLabels:
      tier: application
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    - podSelector:
        matchLabels:
          app: orchestratorm8
    ports:
    - port: 8000
      protocol: TCP
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - port: 5432
      protocol: TCP
    - port: 27017
      protocol: TCP
    - port: 5672
      protocol: TCP
  - to:
    - podSelector:
        matchLabels:
          tier: search
    ports:
    - port: 9200
      protocol: TCP
  - to:  # Allow external HTTPS for APIs
    - namespaceSelector: {}
    ports:
    - port: 443
      protocol: TCP
  - to:  # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - port: 53
      protocol: UDP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: cptm8-staging
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: application
    - podSelector:
        matchLabels:
          tier: frontend
```

### 6.2 Pod Security Standards

```yaml
# overlays/staging/security/pod-security.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cptm8-staging
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 6.3 Security Context for Pods

```yaml
# overlays/staging/patches/security-context.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: asmm8
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /home/appuser/.cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```

## 🚀 Phase 7: CI/CD Pipeline

### 7.1 GitHub Actions Workflow

```yaml
# .github/workflows/staging-deploy.yml
name: Deploy to Staging

on:
  push:
    branches:
      - staging
  workflow_dispatch:

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 123456789012.dkr.ecr.us-east-1.amazonaws.com
  EKS_CLUSTER: cptm8-staging

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-get-login@v1

    - name: Build and push Docker images
      run: |
        # Build and push each service
        for service in asmm8 naabum8 katanam8 num8 reportingm8 orchestratorm8; do
          docker build -t $ECR_REGISTRY/cptm8/$service:staging-$GITHUB_SHA ./services/$service
          docker push $ECR_REGISTRY/cptm8/$service:staging-$GITHUB_SHA
          docker tag $ECR_REGISTRY/cptm8/$service:staging-$GITHUB_SHA $ECR_REGISTRY/cptm8/$service:staging-latest
          docker push $ECR_REGISTRY/cptm8/$service:staging-latest
        done

    - name: Update kubeconfig
      run: |
        aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.EKS_CLUSTER }}

    - name: Install Kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/

    - name: Update image tags in Kustomization
      run: |
        cd Kubernetes/overlays/staging
        for service in asmm8 naabum8 katanam8 num8 reportingm8 orchestratorm8; do
          kustomize edit set image $ECR_REGISTRY/cptm8/$service:staging-$GITHUB_SHA
        done

    - name: Deploy to staging
      run: |
        cd Kubernetes/overlays/staging
        kustomize build . | kubectl apply -f -
        
    - name: Wait for rollout
      run: |
        kubectl rollout status deployment -n cptm8-staging --timeout=10m

    - name: Run smoke tests
      run: |
        # Test health endpoints
        for service in asmm8 naabum8 katanam8 num8 reportingm8; do
          kubectl exec -n cptm8-staging deployment/$service -- curl -f http://localhost:8000/health || exit 1
        done
        
        # Test frontend
        kubectl exec -n cptm8-staging deployment/dashboardm8 -- curl -f http://localhost:3000/signin || exit 1
```

### 7.2 Helm Chart Structure (Alternative to Kustomize)

```yaml
# helm/cptm8/Chart.yaml
apiVersion: v2
name: cptm8
description: CPTM8 Security Platform
type: application
version: 0.1.0
appVersion: "1.0"

dependencies:
  - name: postgresql
    version: 12.1.0
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: mongodb
    version: 13.6.0
    repository: https://charts.bitnami.com/bitnami
    condition: mongodb.enabled
  - name: rabbitmq
    version: 11.9.0
    repository: https://charts.bitnami.com/bitnami
    condition: rabbitmq.enabled

# helm/cptm8/values-staging.yaml
global:
  environment: staging
  storageClass: staging-gp3-retain

postgresql:
  enabled: true
  auth:
    postgresPassword: ${POSTGRES_PASSWORD}
  primary:
    persistence:
      size: 50Gi

mongodb:
  enabled: true
  auth:
    rootPassword: ${MONGODB_ROOT_PASSWORD}
  persistence:
    size: 100Gi

microservices:
  asmm8:
    replicas: 2
    image:
      tag: staging-latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"
```

## 🔄 Phase 8: Zero-Downtime Deployment Strategies

### 8.1 Rolling Update Configuration

```yaml
# overlays/staging/patches/deployment-strategy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # One extra pod during update
      maxUnavailable: 0  # Zero downtime
  minReadySeconds: 30    # Wait before considering pod ready
  progressDeadlineSeconds: 600
```

### 8.2 Canary Deployment with Flagger

```bash
# Install Flagger for progressive delivery
helm repo add flagger https://flagger.app
helm install flagger flagger/flagger \
  --namespace=flagger-system \
  --create-namespace \
  --set prometheus.install=true \
  --set meshProvider=nginx

# Create Canary resource
cat > overlays/staging/canary/dashboardm8-canary.yaml <<EOF
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: dashboardm8
  namespace: cptm8-staging
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dashboardm8
  service:
    port: 3000
  analysis:
    interval: 1m
    threshold: 10
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
  webhooks:
    - name: smoke-test
      url: http://flagger-loadtester.test/
      timeout: 30s
      metadata:
        type: smoke
        cmd: "curl -f http://dashboardm8-canary.cptm8-staging:3000/health"
EOF
```

## 📈 Phase 9: Autoscaling Configuration

### 9.1 Horizontal Pod Autoscaler (HPA)

```yaml
# overlays/staging/autoscaling/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: asmm8-hpa
  namespace: cptm8-staging
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: asmm8
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15
      selectPolicy: Max
```

### 9.2 Vertical Pod Autoscaler (VPA)

```yaml
# overlays/staging/autoscaling/vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: vector-vpa
  namespace: cptm8-staging
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vector
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: vector
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 2Gi
      controlledResources: ["cpu", "memory"]
```

### 9.3 Cluster Autoscaler

```bash
# For EKS
eksctl create iamserviceaccount \
  --cluster=cptm8-staging \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::123456789012:policy/ClusterAutoscalerPolicy \
  --override-existing-serviceaccounts \
  --approve

# Deploy cluster autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Edit deployment to add cluster name
kubectl -n kube-system edit deployment.apps/cluster-autoscaler
# Add: --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/cptm8-staging
```

## 🎯 Phase 10: Staging Deployment Checklist

### Pre-deployment Checklist
- [ ] Cloud cluster created and accessible
- [ ] Storage classes configured
- [ ] Ingress controller installed
- [ ] SSL certificates configured
- [ ] Monitoring stack deployed
- [ ] Network policies applied
- [ ] RBAC configured
- [ ] Secrets encrypted and deployed
- [ ] CI/CD pipeline configured
- [ ] Backup strategy in place

### Deployment Commands

```bash
# 1. Deploy SOPS-encrypted secrets
sops -d overlays/staging/secrets/secrets-staging.encrypted.yaml | kubectl apply -f -

# 2. Deploy storage classes
kubectl apply -f overlays/staging/storage/

# 3. Deploy using Kustomize
cd overlays/staging
kustomize build . | kubectl apply -f -

# 4. Monitor deployment
kubectl get pods -n cptm8-staging -w
kubectl get events -n cptm8-staging --sort-by='.lastTimestamp'

# 5. Verify all services
for service in asmm8 naabum8 katanam8 num8 reportingm8 orchestratorm8; do
  echo "Testing $service..."
  kubectl exec -n cptm8-staging deployment/$service -- curl -f http://localhost:8000/health
done

# 6. Check ingress
kubectl get ingress -n cptm8-staging
curl -I https://dashboard-staging.cptm8.net
```

## 📊 Staging Environment Monitoring

### Key Metrics to Monitor

```yaml
# Create Grafana dashboard for CPTM8
apiVersion: v1
kind: ConfigMap
metadata:
  name: cptm8-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "CPTM8 Staging Environment",
        "panels": [
          {
            "title": "Pod CPU Usage",
            "targets": [
              {
                "expr": "rate(container_cpu_usage_seconds_total{namespace=\"cptm8-staging\"}[5m])"
              }
            ]
          },
          {
            "title": "Pod Memory Usage",
            "targets": [
              {
                "expr": "container_memory_working_set_bytes{namespace=\"cptm8-staging\"}"
              }
            ]
          },
          {
            "title": "HTTP Request Rate",
            "targets": [
              {
                "expr": "rate(http_requests_total{namespace=\"cptm8-staging\"}[5m])"
              }
            ]
          },
          {
            "title": "Database Connections",
            "targets": [
              {
                "expr": "pg_stat_activity_count{namespace=\"cptm8-staging\"}"
              }
            ]
          }
        ]
      }
    }
```

### Alert Rules

```yaml
# overlays/staging/monitoring/alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cptm8-alerts
  namespace: cptm8-staging
spec:
  groups:
  - name: cptm8.rules
    interval: 30s
    rules:
    - alert: HighCPUUsage
      expr: rate(container_cpu_usage_seconds_total{namespace="cptm8-staging"}[5m]) > 0.8
      for: 5m
      annotations:
        summary: "High CPU usage detected"
        description: "{{ $labels.pod }} CPU usage is above 80%"
    
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="cptm8-staging"}[15m]) > 0
      for: 5m
      annotations:
        summary: "Pod is crash looping"
        description: "{{ $labels.pod }} has restarted {{ $value }} times"
    
    - alert: DatabaseDown
      expr: up{job="postgresql", namespace="cptm8-staging"} == 0
      for: 1m
      annotations:
        summary: "PostgreSQL is down"
        description: "PostgreSQL in staging is not responding"
```

## 💰 Cost Optimization

### Resource Right-Sizing

```bash
# Install Goldilocks for resource recommendations
kubectl create namespace goldilocks
helm install goldilocks fairwinds-stable/goldilocks --namespace goldilocks

# Enable VPA recommendations for namespace
kubectl label ns cptm8-staging goldilocks.fairwinds.com/enabled=true

# View recommendations at http://localhost:8080
kubectl port-forward -n goldilocks svc/goldilocks-dashboard 8080:80
```

### Spot Instances (AWS)

```yaml
# eksctl nodegroup configuration for spot instances
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: cptm8-staging
  region: us-east-1
nodeGroups:
  - name: spot-nodes
    instancesDistribution:
      instanceTypes: ["t3.medium", "t3a.medium", "t2.medium"]
      onDemandPercentageAboveBaseCapacity: 0
      spotInstancePools: 3
    minSize: 2
    maxSize: 10
    desiredCapacity: 3
    labels:
      workload: spot-tolerant
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule
```

## 🔒 Security Scanning

### Container Image Scanning

```bash
# Install Trivy for vulnerability scanning
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace \
  --set="operator.scanJobTimeout=10m" \
  --set="trivy.ignoreUnfixed=true"

# View vulnerability reports
kubectl get vulnerabilityreports -n cptm8-staging
```

### Runtime Security with Falco

```bash
# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true
```

## 📋 Staging vs Production Comparison

| Component | Development (Kind) | Staging (Cloud) | Production (Cloud) |
|-----------|-------------------|-----------------|-------------------|
| **Cluster** | Single node | 3 nodes (autoscaling) | 5+ nodes (multi-AZ) |
| **Storage** | hostPath | Cloud SSD (50-100GB) | Cloud SSD (100GB+) + backup |
| **Replicas** | 1 per service | 2 per service | 3+ per service |
| **Resources** | No limits | Soft limits | Hard limits + VPA |
| **Monitoring** | Basic logs | Prometheus + Grafana | Full observability stack |
| **Security** | Basic RBAC | Network Policies + PSS | + Falco + OPA + mTLS |
| **Ingress** | NodePort | ALB with SSL | ALB + WAF + CDN |
| **CI/CD** | Manual | GitHub Actions | + Approval gates |
| **Backup** | None | Daily snapshots | Continuous + DR |
| **Cost** | $0 | ~$200-300/month | ~$800-1500/month |

## 🎯 Next Steps After Staging

1. **Load Testing**: Use k6 or Locust to test staging environment
2. **Disaster Recovery**: Test backup and restore procedures
3. **Security Audit**: Run penetration tests on staging
4. **Performance Tuning**: Optimize based on monitoring data
5. **Documentation**: Update runbooks and operational procedures
6. **Production Prep**: Plan production rollout with rollback strategies

## 🏆 What You'll Achieve in Staging

✅ **Cloud-native architecture** with managed Kubernetes
✅ **Auto-scaling** at pod and cluster level
✅ **Production-grade monitoring** with Prometheus/Grafana
✅ **Secure networking** with policies and SSL/TLS
✅ **CI/CD automation** with GitHub Actions
✅ **Cost optimization** with spot instances and right-sizing
✅ **Zero-downtime deployments** with rolling updates
✅ **Disaster recovery** with automated backups
✅ **Security hardening** with PSS and vulnerability scanning
✅ **Performance insights** from real cloud environment

---

*This staging environment provides a production-like testing ground while maintaining cost efficiency. It's your proving ground before the final production deployment.*
