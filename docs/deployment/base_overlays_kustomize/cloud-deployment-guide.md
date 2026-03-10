# 🚀 CPTM8 Kubernetes Staging Environment Deployment Guide

This guide provides a high-level overview for transitioning your CPTM8 platform from local Kind development to a **production-grade staging environment** on cloud Kubernetes using the <ins>*base + overlay file structure*</ins>.

---

## 📋 Table of Contents

1. [Executive Summary](#-executive-summary)
2. [Staging Architecture Overview](#-staging-architecture-overview)
3. [Cloud Provider Selection](#-cloud-provider-selection)
4. [Common Components Across Providers](#-common-components-across-providers)
5. [Directory Structure](#-directory-structure)
6. [Security Hardening](#-security-hardening)
7. [Monitoring & Observability](#-monitoring--observability)
8. [CI/CD Pipeline](#-cicd-pipeline)
9. [Deployment Strategies](#-deployment-strategies)
10. [Autoscaling](#-autoscaling)
11. [Cost Optimization](#-cost-optimization)
12. [Pre-Deployment Checklist](#-pre-deployment-checklist)
13. [Environment Comparison](#-environment-comparison)
14. [Next Steps](#-next-steps)

---

## 📋 Executive Summary

The staging environment bridges the gap between local development and production. It provides:

- **Production-like infrastructure** for realistic testing
- **Cloud-native patterns** for scalability and resilience
- **Security hardening** before production exposure
- **CI/CD automation** for consistent deployments
- **Monitoring and observability** for performance insights

---

## 🏗️ Staging Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    STAGING ENVIRONMENT                          │
├─────────────────────────────────────────────────────────────────┤
│ 🌐 Cloud Provider: AWS / Azure (provider-specific guides)      │
│ 🎯 Cluster: Managed Kubernetes (EKS / AKS)                     │
│ 🔐 Namespace: cptm8-staging (isolated from dev/prod)           │
│ 💾 Storage: Cloud persistent disks (auto-provisioned)          │
│ 🌍 Networking: Cloud Load Balancer + Ingress with SSL/TLS      │
│ 📊 Monitoring: Prometheus + Grafana                            │
│ 📝 Logging: Vector → OpenSearch (existing)                     │
│ 🔄 CI/CD: GitHub Actions + Kustomize                           │
│ 🛡️ Security: Network Policies + Pod Security Standards         │
└─────────────────────────────────────────────────────────────────┘
```

### Service Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LOAD BALANCER (ALB/Azure LB)                 │
│                    + SSL/TLS Termination                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INGRESS CONTROLLER                           │
│                    (NGINX / Cloud-native)                       │
└───────────────────────────┬─────────────────────────────────────┘
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
│  │ Port: 4000    │  │         │  │ Port: 8000    │  │
│  └───────────────┘  │         │  └───────────────┘  │
└─────────────────────┘         └──────────┬──────────┘
                                           │
            ┌──────────────────────────────┼──────────────────────────────┐
            ▼                              ▼                              ▼
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│     DATABASES       │     │     MESSAGE QUEUE   │     │      SEARCH         │
│  ┌───────────────┐  │     │  ┌───────────────┐  │     │  ┌───────────────┐  │
│  │  PostgreSQL   │  │     │  │   RabbitMQ    │  │     │  │  OpenSearch   │  │
│  │  (StatefulSet)│  │     │  │  (StatefulSet)│  │     │  │  (StatefulSet)│  │
│  ├───────────────┤  │     │  └───────────────┘  │     │  └───────────────┘  │
│  │   MongoDB     │  │     └─────────────────────┘     └─────────────────────┘
│  │  (StatefulSet)│  │
│  └───────────────┘  │
└─────────────────────┘
```

---

## 🌐 Cloud Provider Selection

Choose your cloud provider and follow the detailed implementation guide:

| Provider | Guide | Best For |
|----------|-------|----------|
| **AWS EKS** | [AWS Staging Guide](./staging/AWS/aws-staging-guide.md) | Existing AWS infrastructure, S3 integration, mature EKS ecosystem |
| **Azure AKS** | [Azure Staging Guide](./staging/Azure/azure-staging-guide.md) | Microsoft ecosystem, Azure AD integration, hybrid cloud |

### Provider Comparison

| Feature | AWS EKS | Azure AKS |
|---------|---------|-----------|
| **Control Plane Cost** | ~$73/month | Free |
| **Container Registry** | ECR | ACR |
| **Load Balancer** | ALB/NLB | Azure Load Balancer |
| **DNS** | Route 53 | Azure DNS |
| **Secrets Management** | Secrets Manager | Key Vault |
| **Storage** | EBS (gp3) | Azure Disk (Premium SSD) |
| **Identity** | IAM + IRSA | Managed Identity + Workload Identity |
| **CLI** | aws + eksctl | az |

---

## 🔧 Common Components Across Providers

These components are installed the same way regardless of cloud provider:

### Ingress Controller (NGINX)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2
```

### cert-manager for SSL/TLS

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Let's Encrypt ClusterIssuer

```yaml
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
```

### External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace
```

---

## 📁 Directory Structure

Organize your Kubernetes manifests for multi-environment support:

```
Kubernetes/
├── base/                           # Shared resources
│   ├── kustomization.yaml
│   ├── deployments/
│   ├── services/
│   └── configmaps/
│
├── overlays/
│   ├── dev/                        # Local Kind cluster
│   │   └── kustomization.yaml
│   │
│   ├── staging-aws/                # AWS EKS staging
│   │   ├── kustomization.yaml
│   │   ├── configmaps/
│   │   ├── secrets/
│   │   ├── ingress/
│   │   ├── storage/
│   │   └── patches/
│   │
│   ├── staging-azure/              # Azure AKS staging
│   │   ├── kustomization.yaml
│   │   ├── configmaps/
│   │   ├── secrets/
│   │   ├── ingress/
│   │   ├── storage/
│   │   └── patches/
│   │
│   └── prod/                       # Production
│       └── kustomization.yaml
│
└── docs/
    └── deployment/
        ├── staging/
        │   ├──AWS/
        |   │  └── aws-staging-guide.md
        |   └── Azure/
        |       └── azure-staging-guide.md
        └── cloud-deployment-guide.md  # This file
        
```

### Base Kustomization Example

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  # Databases
  - deployments/postgresql.yaml
  - deployments/mongodb.yaml
  - deployments/rabbitmq.yaml
  - deployments/opensearch.yaml

  # Backend services
  - deployments/orchestratorm8.yaml
  - deployments/asmm8.yaml
  - deployments/naabum8.yaml
  - deployments/katanam8.yaml
  - deployments/num8.yaml
  - deployments/reportingm8.yaml

  # Frontend services
  - deployments/dashboardm8.yaml
  - deployments/socketm8.yaml

  # Observability
  - deployments/vector.yaml

  # Services
  - services/services.yaml
```

### Staging Overlay Example

```yaml
# overlays/staging-aws/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cptm8-staging

resources:
  - ../../base
  - ingress/ingress-staging.yaml
  - storage/storageclass.yaml

patches:
  - path: patches/resource-limits.yaml
  - path: patches/replicas.yaml

images:
  - name: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/cptm8-backend/asmm8
    newTag: staging
  # ... additional images
```

---

## 🔐 Security Hardening

### Network Policies

Restrict traffic between pods:

```yaml
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
    - port: 27017
    - port: 5672
```

### Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cptm8-staging
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Security Context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
```

---

## 📊 Monitoring & Observability

### Prometheus & Grafana Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f prometheus-values.yaml
```

### ServiceMonitor for Applications

```yaml
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

### Alert Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cptm8-alerts
spec:
  groups:
  - name: cptm8.rules
    rules:
    - alert: HighCPUUsage
      expr: rate(container_cpu_usage_seconds_total{namespace="cptm8-staging"}[5m]) > 0.8
      for: 5m
      annotations:
        summary: "High CPU usage on {{ $labels.pod }}"

    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="cptm8-staging"}[15m]) > 0
      for: 5m
      annotations:
        summary: "Pod {{ $labels.pod }} is crash looping"
```

---

## 🚀 CI/CD Pipeline

### GitHub Actions Workflow Structure

```yaml
name: Deploy to Staging

on:
  push:
    branches: [staging]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Build and push images
      # Provider-specific: See AWS or Azure guide

    - name: Deploy to Kubernetes
      run: |
        kubectl apply -k overlays/staging-${{ env.PROVIDER }}
        kubectl rollout status deployment -n cptm8-staging --timeout=10m

    - name: Run smoke tests
      run: |
        for service in asmm8 naabum8 katanam8 num8 reportingm8; do
          kubectl exec -n cptm8-staging deployment/$service -- \
            curl -f http://localhost:8000/health || exit 1
        done
```

> **Note:** See the provider-specific guides for complete CI/CD workflows:
> - [AWS CI/CD Setup](./staging/AWS/aws-staging-guide.md#phase-11-cicd-with-github-actions)
> - [Azure CI/CD Setup](./staging/Azure/azure-staging-guide.md#phase-9-cicd-with-github-actions)

---

## 🔄 Deployment Strategies

### Rolling Update (Default)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  minReadySeconds: 30
```

### Canary Deployment with Flagger

```bash
helm repo add flagger https://flagger.app
helm install flagger flagger/flagger \
  --namespace=flagger-system \
  --create-namespace \
  --set prometheus.install=true
```

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: dashboardm8
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dashboardm8
  analysis:
    interval: 1m
    threshold: 10
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
```

---

## 📈 Autoscaling

### Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: asmm8-hpa
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
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 0
```

### Vertical Pod Autoscaler (VPA)

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: vector-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vector
  updatePolicy:
    updateMode: "Auto"
```

---

## 💰 Cost Optimization

### Resource Right-Sizing

```bash
# Install Goldilocks for recommendations
helm install goldilocks fairwinds-stable/goldilocks -n goldilocks --create-namespace

# Enable for namespace
kubectl label ns cptm8-staging goldilocks.fairwinds.com/enabled=true
```

### Spot/Preemptible Instances

Both AWS and Azure support spot instances for non-critical workloads. See provider-specific guides for configuration.

### Scale Down Schedule

For staging environments, consider scaling down outside business hours:

```bash
# AWS: Scale down EKS node group
eksctl scale nodegroup --cluster=cptm8-staging --name=staging-workers --nodes=1

# Azure: Stop AKS cluster (completely stops billing)
az aks stop --name cptm8-staging-aks --resource-group cptm8-staging-rg
```

---

## ✅ Pre-Deployment Checklist

Before deploying to staging, verify:

### Infrastructure
- [ ] Cloud cluster created and accessible
- [ ] kubectl configured and connected
- [ ] Storage classes configured
- [ ] Container registry accessible

### Networking
- [ ] Ingress controller installed
- [ ] DNS records configured
- [ ] SSL certificates provisioned
- [ ] Network policies applied

### Security
- [ ] Secrets encrypted (SOPS or cloud provider)
- [ ] RBAC configured
- [ ] Pod Security Standards enforced
- [ ] Service accounts with minimal permissions

### Observability
- [ ] Monitoring stack deployed (Prometheus/Grafana)
- [ ] Log aggregation configured (Vector → OpenSearch)
- [ ] Alerts configured

### Deployment
- [ ] CI/CD pipeline configured
- [ ] Image tags updated in kustomization
- [ ] Health checks verified

---

## 📋 Environment Comparison

| Component | Development (Kind) | Staging (Cloud) | Production (Cloud) |
|-----------|-------------------|-----------------|-------------------|
| **Cluster** | Single node | 3 nodes (autoscaling) | 5+ nodes (multi-AZ) |
| **Storage** | hostPath | Cloud SSD (50-100GB) | Cloud SSD (100GB+) + backup |
| **Replicas** | 1 per service | 2 per service | 3+ per service |
| **Resources** | No limits | Soft limits | Hard limits + VPA |
| **Monitoring** | Basic logs | Prometheus + Grafana | Full observability |
| **Security** | Basic RBAC | Network Policies + PSS | + Falco + OPA + mTLS |
| **Ingress** | NodePort | LB with SSL | LB + WAF + CDN |
| **CI/CD** | Manual | GitHub Actions | + Approval gates |
| **Backup** | None | Daily snapshots | Continuous + DR |
| **Estimated Cost** | $0 | ~$250-450/month | ~$800-1500/month |

---

## 🎯 Next Steps

After successfully deploying to staging:

1. **Load Testing**
   - Use k6 or Locust to simulate production load
   - Identify bottlenecks and optimize

2. **Security Audit**
   - Run vulnerability scans (Trivy)
   - Perform penetration testing
   - Review access controls

3. **Disaster Recovery**
   - Test backup and restore procedures
   - Document recovery runbooks

4. **Performance Tuning**
   - Analyze Grafana dashboards
   - Right-size resources based on actual usage

5. **Production Planning**
   - Multi-AZ/region deployment
   - WAF and DDoS protection
   - CDN configuration

---

## 📚 Related Documentation

### Cloud Provider Guides
- [AWS EKS Staging Guide](./staging/AWS/aws-staging-guide.md) - Complete AWS implementation
- [Azure AKS Staging Guide](./staging/Azure/azure-staging-guide.md) - Complete Azure implementation

### Additional Resources
- [Helm Implementation Guide](./helm-implementation-guide.md)
- [CI/CD Pipeline Guide](./cicd-pipeline-guide.md)
- [Security Review](./SECURITY_REVIEW.md)
- [Kubernetes Architecture Diagram](./kubernetes-architecture-diagram.md)

---

## 🏆 What You'll Achieve

After completing the staging setup:

- ✅ **Cloud-native architecture** with managed Kubernetes
- ✅ **Auto-scaling** at pod and cluster level
- ✅ **Production-grade monitoring** with Prometheus/Grafana
- ✅ **Secure networking** with policies and SSL/TLS
- ✅ **CI/CD automation** with GitHub Actions
- ✅ **Cost optimization** with spot instances and right-sizing
- ✅ **Zero-downtime deployments** with rolling updates
- ✅ **Disaster recovery** with automated backups
- ✅ **Security hardening** with PSS and vulnerability scanning
- ✅ **Performance insights** from real cloud environment

---

*This staging environment provides a production-like testing ground while maintaining cost efficiency. Choose your cloud provider and follow the detailed guide to get started.*
