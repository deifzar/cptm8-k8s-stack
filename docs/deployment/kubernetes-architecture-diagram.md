# 🏗️ CPTM8 Kubernetes Architecture - Multi-Environment Design

---

## 📋 Table of Contents

- [🏗️ CPTM8 Kubernetes Architecture - Multi-Environment Design](#️-cptm8-kubernetes-architecture---multi-environment-design)
  - [📋 Table of Contents](#-table-of-contents)
  - [📐 Tiered Architecture Overview](#-tiered-architecture-overview)
  - [🔄 Service Communication Flow](#-service-communication-flow)
  - [📁 Directory Structure](#-directory-structure)
    - [Deployment Commands](#deployment-commands)
  - [🌍 Environment-Specific Configurations](#-environment-specific-configurations)
  - [🔐 Security Architecture](#-security-architecture)
  - [📊 Monitoring \& Observability Stack](#-monitoring--observability-stack)
  - [🚀 CI/CD Pipeline Architecture](#-cicd-pipeline-architecture)
  - [💰 Cost Optimization Strategy](#-cost-optimization-strategy)
  - [🔄 Deployment Strategies](#-deployment-strategies)
  - [📚 Related Documentation](#-related-documentation)
    - [Deployment Guides](#deployment-guides)
    - [Technical References](#technical-references)

---

## 📐 Tiered Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           CPTM8 PLATFORM ARCHITECTURE                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         🌐 INGRESS LAYER                                 │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │ │
│  │  │ AWS ALB/NLB  │  │ NGINX Ingress│  │  Cert Manager│                  │ │
│  │  │ (Production) │  │  Controller  │  │  (SSL/TLS)   │                  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         🖥️ FRONTEND LAYER                                │ │
│  │  ┌─────────────────────────────────┐  ┌────────────────────────────┐   │ │
│  │  │     DashboardM8 (Next.js)       │  │    SocketM8 (Socket.io)    │   │ │
│  │  │   Replicas: 2 (staging) / 3+    │  │  Replicas: 2 (staging) / 3+│   │ │
│  │  │   HPA: CPU 70% / Memory 80%     │  │  HPA: CPU 70% / Memory 80% │   │ │
│  │  └─────────────────────────────────┘  └────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                      🔧 APPLICATION LAYER                                │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │ │
│  │  │  ASMM8   │ │ NAABUM8  │ │ KATANAM8 │ │  NUM8    │ │ ReportingM8  │ │ │
│  │  │DNS Brute │ │Port Scan │ │Web Crawl │ │Vuln Scan │ │Report Gen    │ │ │
│  │  │Port 8000 │ │Port 8001 │ │Port 8002 │ │Port 8003 │ │  CronJob     │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │ │
│  │                                                                          │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │  │                    OrchestratorM8                                │   │ │
│  │  │         (RabbitMQ Queue Initialization & API Trigger)           │   │ │
│  │  └─────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                      💾 DATA LAYER                                       │ │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌─────────────────┐  │ │
│  │  │PostgreSQL  │  │  MongoDB   │  │ RabbitMQ   │  │   OpenSearch    │  │ │
│  │  │StatefulSet │  │StatefulSet │  │StatefulSet │  │   StatefulSet   │  │ │
│  │  │ PVC: 50Gi  │  │ PVC: 100Gi │  │ PVC: 30Gi  │  │   PVC: 200Gi    │  │ │
│  │  └────────────┘  └────────────┘  └────────────┘  └─────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                      📊 OBSERVABILITY LAYER                              │ │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌─────────────────┐  │ │
│  │  │   Vector   │  │ Prometheus │  │  Grafana   │  │   AlertManager  │  │ │
│  │  │Log Aggreg. │  │  Metrics   │  │ Dashboards │  │  Notifications  │  │ │
│  │  └────────────┘  └────────────┘  └────────────┘  └─────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Service Communication Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SERVICE DISCOVERY & COMMUNICATION                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  User Request → Ingress → DashboardM8                                        │
│       ↓                                                                       │
│  DashboardM8 → SocketM8 (WebSocket for real-time)                           │
│       ↓                                                                       │
│  DashboardM8 → PostgreSQL (User data, systems, vulnerabilities)              │
│       ↓                                                                       │
│  DashboardM8 → MongoDB (Chat messages)                                       │
│                                                                               │
│  ┌───────────────────────────────────────────────────────────────────┐      │
│  │                    AUTOMATED SCANNING PIPELINE                     │      │
│  │                                                                    │      │
│  │  1. OrchestratorM8 → RabbitMQ (Initialize queues)                │      │
│  │       ↓                                                           │      │
│  │  2. OrchestratorM8 → ASMM8 API (Start DNS discovery)            │      │
│  │       ↓                                                           │      │
│  │  3. ASMM8 → PostgreSQL (Store found systems)                     │      │
│  │       ↓                                                           │      │
│  │  4. ASMM8 → RabbitMQ → NAABUM8 (Trigger port scan)             │      │
│  │       ↓                                                           │      │
│  │  5. NAABUM8 → PostgreSQL (Store open ports)                      │      │
│  │       ↓                                                           │      │
│  │  6. NAABUM8 → RabbitMQ → KATANAM8 (Trigger web crawl)          │      │
│  │       ↓                                                           │      │
│  │  7. KATANAM8 → PostgreSQL (Store web assets)                     │      │
│  │       ↓                                                           │      │
│  │  8. KATANAM8 → RabbitMQ → NUM8 (Trigger vuln scan)             │      │
│  │       ↓                                                           │      │
│  │  9. NUM8 → PostgreSQL (Store vulnerabilities)                    │      │
│  │       ↓                                                           │      │
│  │  10. NUM8 → RabbitMQ → ASMM8 (Loop back to step 2)             │      │
│  │                                                                    │      │
│  │  Monthly: ReportingM8 CronJob → Generate HTML report → S3        │      │
│  └───────────────────────────────────────────────────────────────────┘      │
│                                                                               │
│  All Services → Vector → OpenSearch (Centralized logging)                    │
│  All Services → /metrics endpoint → Prometheus → Grafana                     │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Directory Structure

The repository uses a **Kustomize base/overlay pattern** for multi-environment deployments:

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
├── overlays/                          # Environment-specific configurations
│   ├── dev/                           # Local development (Kind cluster)
│   │   ├── kustomization.yaml
│   │   ├── configmaps/                # Dev ConfigMaps
│   │   ├── secrets/                   # SOPS-encrypted secrets
│   │   ├── storage/                   # Local StorageClass, PVs
│   │   ├── services/                  # NodePort for local access
│   │   ├── patches/                   # Resource limits patches
│   │   ├── security/                  # Network policies
│   │   └── ingress/                   # Optional ingress
│   │
│   ├── staging-aws/                   # AWS EKS staging
│   │   ├── kustomization.yaml
│   │   ├── configmaps/                # AWS-specific configs
│   │   ├── secrets/                   # AWS Secrets Manager integration
│   │   ├── storage/                   # EBS gp3 StorageClass
│   │   ├── patches/                   # Staging resource limits
│   │   ├── security/                  # Pod security, network policies
│   │   ├── ingress/                   # ALB ingress
│   │   └── jobs/                      # MongoDB init for staging
│   │
│   ├── staging-azure/                 # Azure AKS staging
│   │   ├── kustomization.yaml
│   │   ├── configmaps/                # Azure-specific configs
│   │   ├── secrets/                   # Key Vault integration
│   │   ├── storage/                   # Azure Disk StorageClass
│   │   ├── patches/                   # Staging resource limits
│   │   ├── security/                  # Pod security, network policies
│   │   ├── ingress/                   # NGINX/App Gateway ingress
│   │   └── jobs/                      # MongoDB init for staging
│   │
│   └── prod/                          # Production (multi-cloud)
│       ├── ingress/                   # Production ingress
│       └── security/                  # Strict security policies
│
└── docs/                              # Documentation
    └── deployment/
        ├── staging/
        │   ├── AWS/                   # AWS EKS deployment guides
        │   └── Azure/                 # Azure AKS deployment guides
        └── dev/                       # Development setup guides
```

### Deployment Commands

```bash
# Development (Kind cluster)
kubectl apply -k overlays/dev

# Staging - AWS EKS
kubectl apply -k overlays/staging-aws

# Staging - Azure AKS
kubectl apply -k overlays/staging-azure

# Production
kubectl apply -k overlays/prod
```

---

## 🌍 Environment-Specific Configurations

```
# Environment Comparison Matrix
┌─────────────────┬─────────────────────┬──────────────────────────────────────────────┬─────────────────────┐
│   Component     │   Development       │              Staging                         │    Production       │
│                 │   (overlays/dev)    │   AWS (staging-aws)  │  Azure (staging-azure)│   (overlays/prod)   │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ Cluster         │ Kind (local)        │ AWS EKS              │ Azure AKS             │ EKS/AKS (multi-AZ)  │
│ Nodes           │ 1                   │ 3 (autoscale 2-5)    │ 3 (autoscale 2-6)     │ 5+ (autoscale 3-10) │
│ Namespace       │ cptm8-dev           │ cptm8-staging        │ cptm8-staging         │ cptm8-prod          │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ REPLICAS        │                     │                      │                       │                     │
│ - Frontend      │ 1                   │ 2                    │ 2                     │ 3-5                 │
│ - Microservices │ 1                   │ 2                    │ 2                     │ 3-5                 │
│ - Databases     │ 1                   │ 1                    │ 1                     │ 3 (HA cluster)      │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ RESOURCES       │                     │                      │                       │                     │
│ - Requests      │ Minimal             │ 256Mi/200m           │ 256Mi/200m            │ 512Mi/500m          │
│ - Limits        │ None                │ 512Mi/500m           │ 512Mi/500m            │ 2Gi/2000m           │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ STORAGE         │                     │                      │                       │                     │
│ - StorageClass  │ local-storage       │ gp3 (EBS CSI)        │ Azure Disk Premium    │ gp3/Premium SSD     │
│ - PostgreSQL    │ 2Gi (hostPath)      │ 50Gi (gp3)           │ 50Gi (Premium)        │ 200Gi               │
│ - MongoDB       │ 5Gi (hostPath)      │ 100Gi (gp3)          │ 100Gi (Premium)       │ 500Gi               │
│ - RabbitMQ      │ 2Gi (hostPath)      │ 30Gi (gp3)           │ 30Gi (Premium)        │ 100Gi               │
│ - OpenSearch    │ 10Gi (hostPath)     │ 200Gi (gp3)          │ 200Gi (Premium)       │ 1Ti                 │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ NETWORKING      │                     │                      │                       │                     │
│ - Ingress       │ NodePort            │ AWS ALB              │ NGINX/App Gateway     │ ALB + CloudFront    │
│ - SSL/TLS       │ None                │ ACM Certificate      │ cert-manager          │ ACM/App Svc Cert    │
│ - DNS           │ localhost           │ Route 53             │ Azure DNS             │ Route 53/Azure DNS  │
│ - Network Policy│ Basic               │ Basic isolation      │ Basic isolation       │ Strict (Calico)     │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ SECURITY        │                     │                      │                       │                     │
│ - RBAC          │ Basic               │ Environment-scoped   │ Environment-scoped    │ Least privilege     │
│ - Secrets       │ SOPS                │ AWS Secrets Manager  │ Azure Key Vault       │ HashiCorp Vault     │
│ - Pod Security  │ Baseline            │ Restricted           │ Restricted            │ Restricted + OPA    │
│ - Image Scan    │ None                │ ECR scanning         │ ACR scanning          │ Trivy + Snyk        │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ MONITORING      │                     │                      │                       │                     │
│ - Metrics       │ None                │ CloudWatch/Prometheus│ Azure Monitor/Prom    │ Prometheus + APM    │
│ - Logging       │ Vector local        │ Vector → OpenSearch  │ Vector → OpenSearch   │ Vector → ELK        │
│ - Dashboards    │ None                │ Grafana              │ Grafana               │ Grafana + Custom    │
│ - Alerts        │ None                │ Basic alerts         │ Basic alerts          │ PagerDuty           │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ DEPLOYMENT      │                     │                      │                       │                     │
│ - Strategy      │ Recreate            │ Rolling Update       │ Rolling Update        │ Blue-Green/Canary   │
│ - CI/CD         │ Manual              │ GitHub Actions       │ GitHub Actions        │ ArgoCD              │
│ - Rollback      │ Manual              │ Automated            │ Automated             │ Instant rollback    │
├─────────────────┼─────────────────────┼──────────────────────┼───────────────────────┼─────────────────────┤
│ EST. COST       │ $0 (local)          │ ~$250/month          │ ~$450/month           │ ~$800-1500/month    │
└─────────────────┴─────────────────────┴──────────────────────┴───────────────────────┴─────────────────────┘
```

---

## 🔐 Security Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           SECURITY LAYERS                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    1. PERIMETER SECURITY                                │ │
│  │  • AWS WAF (Web Application Firewall)                                   │ │
│  │  • DDoS Protection (AWS Shield / CloudFlare)                           │ │
│  │  • Rate Limiting at Ingress                                            │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    2. NETWORK SECURITY                                  │ │
│  │  • Network Policies (Calico/Cilium)                                     │ │
│  │  • Service Mesh (Istio/Linkerd) - Optional                            │ │
│  │  • Private Subnets for Databases                                       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    3. CLUSTER SECURITY                                  │ │
│  │  • RBAC (Role-Based Access Control)                                    │ │
│  │  • Pod Security Standards (Restricted)                                 │ │
│  │  • Admission Controllers (OPA Gatekeeper)                              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    4. CONTAINER SECURITY                                │ │
│  │  • Non-root containers (UID 10001)                                     │ │
│  │  • Read-only root filesystem                                           │ │
│  │  • Security contexts (capabilities dropped)                            │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    5. DATA SECURITY                                     │ │
│  │  • Encryption at rest (AWS KMS, GCP KMS)                              │ │
│  │  • Encryption in transit (TLS 1.3)                                    │ │
│  │  • Secrets management (SOPS → HashiCorp Vault)                        │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     ↓                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    6. RUNTIME SECURITY                                  │ │
│  │  • Falco (Runtime threat detection)                                    │ │
│  │  • Image scanning (Trivy, Snyk)                                       │ │
│  │  • Compliance scanning (Kubescape)                                     │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Monitoring & Observability Stack

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        OBSERVABILITY ARCHITECTURE                             │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  Application Metrics                    System Metrics                        │
│  ┌──────────────────┐                  ┌──────────────────┐                 │
│  │   /metrics       │                  │  Node Exporter   │                 │
│  │  (Prometheus)    │                  │  Kube-state-     │                 │
│  │   format)        │                  │  metrics         │                 │
│  └────────┬─────────┘                  └────────┬─────────┘                 │
│           │                                      │                            │
│           └──────────────┬───────────────────────┘                           │
│                         ↓                                                     │
│             ┌─────────────────────────────┐                                  │
│             │      PROMETHEUS SERVER      │                                  │
│             │  • Scrape metrics           │                                  │
│             │  • Store time-series        │                                  │
│             │  • Evaluate alert rules     │                                  │
│             └──────────┬──────────────────┘                                  │
│                       ↓                                                       │
│        ┌──────────────────────────────────────┐                             │
│        │             GRAFANA                  │                             │
│        │  • Dashboards                        │                             │
│        │  • Visualizations                    │                             │
│        │  • Alert management                  │                             │
│        └──────────────────────────────────────┘                             │
│                                                                               │
│  Application Logs                       Structured Events                    │
│  ┌──────────────────┐                  ┌──────────────────┐                │
│  │   stdout/stderr  │                  │   Audit logs     │                │
│  │   (containers)   │                  │   Access logs    │                │
│  └────────┬─────────┘                  └────────┬─────────┘                │
│           │                                      │                           │
│           └──────────────┬───────────────────────┘                          │
│                         ↓                                                    │
│             ┌─────────────────────────────┐                                 │
│             │         VECTOR              │                                 │
│             │  • Log aggregation          │                                 │
│             │  • Transformation           │                                 │
│             │  • Routing                  │                                 │
│             └──────────┬──────────────────┘                                 │
│                       ↓                                                      │
│        ┌──────────────────────────────────────┐                            │
│        │          OPENSEARCH                  │                            │
│        │  • Full-text search                  │                            │
│        │  • Log analysis                      │                            │
│        │  • Dashboards                        │                            │
│        └──────────────────────────────────────┘                            │
│                                                                              │
│  Alerts Flow:                                                               │
│  Prometheus → AlertManager → PagerDuty/Slack/Email                          │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 CI/CD Pipeline Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           CI/CD WORKFLOW                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  Developer → Git Push → GitHub                                                │
│                ↓                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    CONTINUOUS INTEGRATION                               │ │
│  │                                                                          │ │
│  │  1. Trigger: Push to staging branch                                     │ │
│  │       ↓                                                                 │ │
│  │  2. Code Quality Checks                                                 │ │
│  │     • Linting (golangci-lint)                                          │ │
│  │     • Unit tests                                                        │ │
│  │     • Security scan (gosec)                                            │ │
│  │       ↓                                                                 │ │
│  │  3. Build Docker Images                                                 │ │
│  │     • Multi-stage builds                                               │ │
│  │     • Layer caching                                                    │ │
│  │       ↓                                                                 │ │
│  │  4. Image Security Scan                                                 │ │
│  │     • Trivy vulnerability scan                                         │ │
│  │     • SBOM generation                                                   │ │
│  │       ↓                                                                 │ │
│  │  5. Push to ECR                                                        │ │
│  │     • Tag: staging-${GITHUB_SHA}                                       │ │
│  │     • Tag: staging-latest                                              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                ↓                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    CONTINUOUS DEPLOYMENT                                │ │
│  │                                                                          │ │
│  │  1. Update Kustomization                                                │ │
│  │     • Set new image tags                                               │ │
│  │       ↓                                                                 │ │
│  │  2. Deploy to Staging                                                   │ │
│  │     • kubectl apply -k overlays/staging                                │ │
│  │       ↓                                                                 │ │
│  │  3. Wait for Rollout                                                    │ │
│  │     • Health checks                                                     │ │
│  │     • Readiness probes                                                  │ │
│  │       ↓                                                                 │ │
│  │  4. Run Smoke Tests                                                     │ │
│  │     • API health checks                                                 │ │
│  │     • Database connectivity                                            │ │
│  │       ↓                                                                 │ │
│  │  5. Run Integration Tests                                               │ │
│  │     • End-to-end workflows                                             │ │
│  │     • Performance baselines                                            │ │
│  │       ↓                                                                 │ │
│  │  6. Notification                                                        │ │
│  │     • Slack notification                                                │ │
│  │     • Deployment metrics                                                │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                                │
│  Production Pipeline (Additional):                                            │
│  • Manual approval gate                                                       │
│  • Canary deployment (10% → 50% → 100%)                                      │
│  • Automated rollback on errors                                              │
│  • Post-deployment verification                                              │
│                                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost Optimization Strategy

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        COST OPTIMIZATION LAYERS                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  1. COMPUTE OPTIMIZATION                                                      │
│     • Spot instances for stateless workloads (70% cost saving)              │
│     • Reserved instances for databases (40% cost saving)                     │
│     • Right-sizing based on actual usage (Goldilocks)                       │
│     • Cluster autoscaler with scale-down policies                           │
│                                                                               │
│  2. STORAGE OPTIMIZATION                                                      │
│     • Lifecycle policies for logs (S3 Glacier after 30 days)                │
│     • Snapshot retention policies                                            │
│     • PVC resizing based on actual usage                                     │
│                                                                               │
│  3. NETWORK OPTIMIZATION                                                      │
│     • CloudFront CDN for static assets                                       │
│     • NAT instance vs NAT Gateway (for non-production)                       │
│     • VPC endpoints for AWS services                                         │
│                                                                               │
│  4. RESOURCE SCHEDULING                                                       │
│     • Scale down non-critical services at night                             │
│     • Hibernate development environments                                      │
│     • Scheduled scaling for known traffic patterns                          │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Deployment Strategies

```
ROLLING UPDATE (Staging)
━━━━━━━━━━━━━━━━━━━━━━━
v1: ████████████ (100%)
    ↓
v1: ████████░░░░ (66%)
v2: ░░░░████░░░░ (33%)
    ↓
v1: ████░░░░░░░░ (33%)
v2: ░░░░████████ (66%)
    ↓
v2: ████████████ (100%)

BLUE-GREEN (Production)
━━━━━━━━━━━━━━━━━━━━━━━
Blue (v1):  ████████████ → Active
Green (v2): ░░░░░░░░░░░░ → Building
    ↓
Blue (v1):  ████████████ → Active
Green (v2): ████████████ → Ready
    ↓ (Switch)
Blue (v1):  ░░░░░░░░░░░░ → Standby
Green (v2): ████████████ → Active

CANARY (Production)
━━━━━━━━━━━━━━━━━━━━━━━
v1: ████████████ (100%)
    ↓
v1: ███████████░ (90%)
v2: ░░░░░░░░░░█░ (10%) → Monitor
    ↓ (If metrics good)
v1: ██████░░░░░░ (50%)
v2: ░░░░░░██████ (50%) → Monitor
    ↓ (If metrics good)
v2: ████████████ (100%)
```

---

## 📚 Related Documentation

### Deployment Guides

| Environment | Guide | Description |
|-------------|-------|-------------|
| **Development** | [DEVELOPMENT.md](./dev/DEVELOPMENT.md) | Local Kind cluster setup and workflows |
| **AWS Staging** | [AWS Staging Guide](./staging/AWS/aws-staging-guide.md) | EKS deployment with ALB, Route 53, ECR |
| **Azure Staging** | [Azure Staging Guide](./staging/Azure/azure-staging-guide.md) | AKS deployment with ACR, Azure DNS |
| **Cloud Overview** | [Cloud Environment Guide](./cloud-environment-guide.md) | High-level multi-cloud architecture |

### Technical References

| Topic | Document | Description |
|-------|----------|-------------|
| **CI/CD** | [CI/CD Pipeline Guide](./cicd-pipeline-guide.md) | GitHub Actions workflows |
| **Helm** | [Helm Implementation Guide](./helm-implementation-guide.md) | Alternative Helm-based deployment |
| **AWS IAM** | [AWS IAM Setup Guide](./staging/AWS/aws-iam-setup-guide.md) | IAM roles and policies for EKS |
| **Azure IAM** | [Azure IAM Setup Guide](./staging/Azure/azure-iam-setup-guide.md) | Azure identity and RBAC configuration |

---

*Last updated: January 2026*
