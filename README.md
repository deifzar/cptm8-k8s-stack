# CPTM8 Kubernetes Infrastructure

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Kustomize](https://img.shields.io/badge/Kustomize-5.0+-00ADD8?logo=kubernetes&logoColor=white)](https://kustomize.io/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-active%20development-yellow)](https://github.com/yourusername/cptm8-k8s-stack)
[![Security Status](https://img.shields.io/badge/Security-Medium-orange)]()

> Cloud-native Kubernetes infrastructure for CPTM8 (Continuous Penetration Testing Platform) - Orchestrating 13 microservices for automated security testing and attack surface management.

## Overview

CPTM8 is a comprehensive security scanning platform deployed on Kubernetes, providing automated reconnaissance, vulnerability scanning, and continuous penetration testing capabilities. The infrastructure supports three environments (dev/staging/prod) with declarative configuration management using Kustomize.

### Key Features

- 🔐 **Security-First Architecture** - Network policies, RBAC, pod security standards
- ⚡ **High Performance** - Optimized resource allocation, HPA, connection pooling
- 🚀 **Rapid Deployment** - Full stack deployment in under 10 minutes
- 📊 **Comprehensive Observability** - Vector log aggregation, OpenSearch indexing
- 🔄 **GitOps Ready** - Declarative configuration with Kustomize, ArgoCD compatible
- 🌍 **Multi-Cloud Support** - AWS EKS, GCP GKE, Azure AKS, or local Kind cluster

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Ingress Layer                            │
│                    (NGINX Ingress Controller)                    │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐ ┌────────▼───────┐ ┌────────▼───────┐
│  DashboardM8   │ │   SocketM8     │ │  API Services  │
│  (Next.js)     │ │  (WebSocket)   │ │  (Go)          │
│  Port 3000     │ │  Port 4000     │ │  Ports 8000+   │
└────────────────┘ └────────────────┘ └────────┬────────┘
                                               │
        ┌──────────────────────────────────────┼──────────────────┐
        │                                      │                  │
┌───────▼────────┐ ┌───────────────┐ ┌────────▼───────┐ ┌───────▼────────┐
│   PostgreSQL   │ │   MongoDB     │ │   RabbitMQ     │ │  OpenSearch    │
│  (StatefulSet) │ │ (StatefulSet) │ │ (StatefulSet)  │ │ (StatefulSet)  │
│   Port 5432    │ │  Port 27017   │ │  Port 5672     │ │  Port 9200     │
└────────────────┘ └───────────────┘ └────────────────┘ └────────────────┘
```

## Quick Start

### Prerequisites

- Docker 24.0+ (4 CPU cores, 8GB RAM minimum)
- kubectl 1.28+
- Kind 0.20+ (for local development)
- Kustomize 5.0+ (bundled with kubectl)

### 5-Minute Local Deployment

```bash
# 1. Clone repository
git clone <repository-url>
cd Kubernetes

# 2. Create Kind cluster with port mappings
cat <<EOF | kind create cluster --name cptm8-dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 3000  # DashboardM8
  - containerPort: 30001
    hostPort: 4000  # SocketM8
EOF

# 3. Deploy full stack
kubectl apply -k overlays/dev/

# 4. Wait for all pods to be ready (2-5 minutes)
kubectl wait --for=condition=ready pod --all --timeout=300s -n cptm8-dev

# 5. Access services
echo "DashboardM8: http://localhost:3000"
echo "SocketM8: ws://localhost:4000"
```

### Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n cptm8-dev

# Check services
kubectl get svc -n cptm8-dev

# Run validation script
./scripts/validate-deployment.sh
```

## Service Architecture

### Frontend Tier

| Service | Technology | Port | Purpose |
|---------|-----------|------|---------|
| **DashboardM8** | Next.js/React | 3000 | Web UI for scan management |
| **SocketM8** | Go WebSocket | 4000 | Real-time updates and notifications |

### Application Tier (Go Microservices)

| Service | Port | Purpose |
|---------|------|---------|
| **ASMM8** | 8000 | Asset surface management, subdomain enumeration |
| **NAABUM8** | 8001 | Notification aggregation and distribution |
| **KATANAM8** | 8002 | Vulnerability scanning and assessment |
| **NUM8** | 8003 | Network enumeration and reconnaissance |
| **OrchestratorM8** | 8004 | Workflow orchestration and task scheduling |
| **ReportingM8** | 8005 | Report generation and export |

### Data Tier

| Service | Type | Port | Purpose |
|---------|------|------|---------|
| **PostgreSQL** | StatefulSet | 5432 | Relational data (domains, hostnames, scans) |
| **MongoDB** | StatefulSet (3 replicas) | 27017 | Document storage (scan results, logs) |
| **RabbitMQ** | StatefulSet (3 replicas) | 5672/15672 | Message queue for async processing |
| **OpenSearch** | StatefulSet (3 nodes) | 9200 | Log aggregation and search |

### Observability

| Service | Purpose |
|---------|---------|
| **Vector** | Log collection and forwarding (DaemonSet) |
| **Prometheus** | Metrics collection and alerting |
| **Grafana** | Visualization and dashboards |

## Deployment

### Environment Structure

The infrastructure supports three isolated environments:

| Environment | Namespace | Replicas | Resources | Use Case |
|-------------|-----------|----------|-----------|----------|
| **Development** | `cptm8-dev` | 1 | Minimal (2 CPU, 4Gi RAM) | Local development, testing |
| **Staging** | `cptm8-staging` | 2-3 | Moderate (8 CPU, 16Gi RAM) | Pre-production validation |
| **Production** | `cptm8-prod` | 3+ (HPA) | Full (20+ CPU, 40Gi+ RAM) | Live production workloads |

### Deployment Commands

```bash
# Deploy to development (Kind cluster)
kubectl apply -k overlays/dev/

# Deploy to staging (cloud cluster)
kubectl apply -k overlays/staging/

# Deploy to production (with manual approval)
kubectl apply -k overlays/prod/
```

### Kustomize Structure

```
.
├── bases/                     # Base Kubernetes manifests
│   ├── asmm8/                # ASMM8 service (Deployment, Service, ConfigMap)
│   ├── naabum8/              # NAABUM8 service
│   ├── postgres/             # PostgreSQL StatefulSet
│   ├── mongodb/              # MongoDB replica set
│   ├── rabbitmq/             # RabbitMQ cluster
│   ├── opensearch/           # OpenSearch cluster
│   ├── ingress/              # NGINX Ingress Controller
│   └── vector/               # Vector log collector
│
├── overlays/                  # Environment-specific configurations
│   ├── dev/                  # Development overlay (1 replica, minimal resources)
│   ├── staging/              # Staging overlay (2-3 replicas, moderate resources)
│   └── prod/                 # Production overlay (3+ replicas, HPA, full resources)
│
└── docs/                     # Comprehensive documentation
    ├── ARCHITECTURE.md       # System architecture
    ├── CODE_REVIEW.md        # Manifest review and issues
    ├── DEVELOPMENT.md        # Development guide
    ├── PERFORMANCE.md        # Performance optimization
    ├── SECURITY.md           # Security hardening
    └── TODO.md               # Roadmap and action items
```

## Configuration

### ConfigMaps

Configuration is managed through environment-specific ConfigMaps:

```bash
# View configuration
kubectl get configmap asmm8-config -n cptm8-dev -o yaml

# Edit configuration
kubectl edit configmap asmm8-config -n cptm8-dev

# Restart pods to apply changes
kubectl rollout restart deployment/asmm8 -n cptm8-dev
```

### Secrets Management

Development secrets are encrypted with [SOPS](https://github.com/mozilla/sops):

```bash
# Decrypt and view secrets
sops -d overlays/dev/secrets/postgres-secret.yaml

# Edit encrypted secrets
sops overlays/dev/secrets/postgres-secret.yaml

# Apply decrypted secrets
sops -d overlays/dev/secrets/postgres-secret.yaml | kubectl apply -f -
```

For staging and production, use **External Secrets Operator** with AWS Secrets Manager or HashiCorp Vault.

### Environment Variables

Key configuration variables:

| Variable | Example | Description |
|----------|---------|-------------|
| `DB_HOST` | `postgres` | PostgreSQL hostname |
| `DB_PORT` | `5432` | PostgreSQL port |
| `RABBITMQ_HOST` | `rabbitmq` | RabbitMQ hostname |
| `OPENSEARCH_HOST` | `opensearch` | OpenSearch hostname |
| `LOG_LEVEL` | `info` | Application log level |

## Operations

### Monitoring and Logging

#### View Logs

```bash
# View logs from a specific service
kubectl logs -f deployment/asmm8 -n cptm8-dev

# View logs from all application services
kubectl logs -l tier=application -n cptm8-dev --tail=50 -f

# View logs from specific time range
kubectl logs deployment/asmm8 -n cptm8-dev --since=1h
```

#### Access Databases

```bash
# PostgreSQL
kubectl exec -it postgres-0 -n cptm8-dev -- psql -U cpt_dbuser -d cptm8

# MongoDB
kubectl exec -it mongodb-0 -n cptm8-dev -- mongosh

# RabbitMQ Management UI (port-forward)
kubectl port-forward svc/rabbitmq 15672:15672 -n cptm8-dev
# Access http://localhost:15672 (guest/guest)
```

#### Health Checks

```bash
# Check pod health
kubectl get pods -n cptm8-dev

# Describe pod for detailed status
kubectl describe pod <pod-name> -n cptm8-dev

# Run validation script
./scripts/validate-deployment.sh
```

### Scaling

#### Manual Scaling

```bash
# Scale deployment
kubectl scale deployment/asmm8 --replicas=3 -n cptm8-dev

# Scale StatefulSet
kubectl scale statefulset/postgres --replicas=2 -n cptm8-dev
```

#### Horizontal Pod Autoscaler (HPA)

HPA is configured in staging and production:

```yaml
# Example HPA configuration
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
```

### Updates and Rollbacks

```bash
# Update image version
kubectl set image deployment/asmm8 asmm8=asmm8:v1.2.3 -n cptm8-dev

# Watch rollout status
kubectl rollout status deployment/asmm8 -n cptm8-dev

# View rollout history
kubectl rollout history deployment/asmm8 -n cptm8-dev

# Rollback to previous version
kubectl rollout undo deployment/asmm8 -n cptm8-dev

# Rollback to specific revision
kubectl rollout undo deployment/asmm8 --to-revision=2 -n cptm8-dev
```

### Backup and Disaster Recovery

#### Database Backups

```bash
# PostgreSQL backup
kubectl exec postgres-0 -n cptm8-dev -- pg_dump -U cpt_dbuser cptm8 > backup-$(date +%Y%m%d).sql

# MongoDB backup
kubectl exec mongodb-0 -n cptm8-dev -- mongodump --archive --gzip --db cptm8 > mongodb-backup-$(date +%Y%m%d).gz

# Restore PostgreSQL
kubectl exec -i postgres-0 -n cptm8-dev -- psql -U cpt_dbuser cptm8 < backup-20251119.sql

# Restore MongoDB
kubectl exec -i mongodb-0 -n cptm8-dev -- mongorestore --archive --gzip --db cptm8 < mongodb-backup-20251119.gz
```

#### Cluster Backup (Velero)

For production environments, use Velero for cluster-wide backups:

```bash
# Install Velero
velero install --provider aws --bucket cptm8-backups --backup-location-config region=eu-south-2

# Create backup
velero backup create cptm8-backup-$(date +%Y%m%d) --include-namespaces cptm8-prod

# Restore from backup
velero restore create --from-backup cptm8-backup-20251119
```

## Security

### Security Posture

Current security status: **Medium** (20 issues identified, 3 critical)

Priority security improvements:
- 🔴 **Critical:** Remove hardcoded credentials, implement security contexts, zero-trust network policies
- 🟠 **High:** Stop using `:latest` tags, implement image scanning, RBAC enforcement
- 🟡 **Medium:** Add security headers, rate limiting, secrets encryption

See [SECURITY.md](docs/SECURITY.md) and [SECURITY_REVIEW.md](docs/staging/SECURITY_REVIEW.md) for complete details.

### Security Best Practices

#### Pod Security

All pods should run with security context:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

#### Network Policies

Implement zero-trust network policies:

```yaml
# Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

#### RBAC

Use least-privilege service accounts:

```bash
# Create service account
kubectl create serviceaccount asmm8-sa -n cptm8-dev

# Create role with minimal permissions
kubectl create role asmm8-role --verb=get,list --resource=configmaps,secrets -n cptm8-dev

# Bind role to service account
kubectl create rolebinding asmm8-rolebinding --role=asmm8-role --serviceaccount=cptm8-dev:asmm8-sa -n cptm8-dev
```

## Performance

### Resource Requirements

| Service | CPU Request | Memory Request | CPU Limit | Memory Limit |
|---------|-------------|----------------|-----------|--------------|
| ASMM8 | 250m | 384Mi | 1500m | 1.5Gi |
| PostgreSQL | 500m | 1Gi | 2000m | 4Gi |
| MongoDB | 500m | 1Gi | 2000m | 4Gi |
| RabbitMQ | 300m | 512Mi | 1000m | 2Gi |

### Performance Optimization

Key optimization recommendations:
- Deploy PgBouncer for connection pooling (30-50% performance improvement)
- Use emptyDir for temporary storage instead of PVCs
- Implement HPA with custom metrics
- Optimize PostgreSQL and MongoDB configurations
- Use appropriate storage classes (gp3, io2)

See [PERFORMANCE.md](docs/PERFORMANCE.md) for detailed optimization strategies.

### Performance Metrics

Expected performance characteristics:
- API P95 latency: <100ms
- Scan completion time: 2-10 minutes (depending on scope)
- Database query time: 5-15ms (P95)
- Message queue throughput: 100+ messages/sec

## Troubleshooting

### Common Issues

#### Pods Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n cptm8-dev

# Common causes:
# - Insufficient resources
kubectl top nodes
# - PVC not bound
kubectl get pvc -n cptm8-dev
# - Node selector issues
kubectl get nodes --show-labels
```

#### CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> --previous -n cptm8-dev

# Check events
kubectl describe pod <pod-name> -n cptm8-dev

# Common causes:
# - Application error
# - Missing configuration
# - Failed health checks
```

#### MongoDB Replica Set Not Initializing

```bash
# Check MongoDB pod logs
kubectl logs mongodb-0 -n cptm8-dev

# Manually initialize replica set
kubectl exec -it mongodb-0 -n cptm8-dev -- mongosh --eval 'rs.initiate()'

# Check status
kubectl exec mongodb-0 -n cptm8-dev -- mongosh --eval 'rs.status()'
```

#### Service Not Accessible

```bash
# Check service endpoints
kubectl get endpoints <service-name> -n cptm8-dev

# Check if pods match selector
kubectl get pods -l app=<app-name> -n cptm8-dev

# Test connectivity from another pod
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://<service-name>:8000/health
```

### Debug Commands

```bash
# Execute commands in pod
kubectl exec -it <pod-name> -n cptm8-dev -- /bin/sh

# Copy files from pod
kubectl cp <pod-name>:/path/to/file ./local-file -n cptm8-dev

# Port forward for debugging
kubectl port-forward <pod-name> 9999:8000 -n cptm8-dev

# Check resource usage
kubectl top pods -n cptm8-dev
kubectl top nodes
```

For more troubleshooting guidance, see [DEVELOPMENT.md](docs/DEVELOPMENT.md#troubleshooting).

## Documentation

### Core Documentation

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Complete system architecture, component descriptions, design patterns
- **[CODE_REVIEW.md](docs/CODE_REVIEW.md)** - Kubernetes manifest review, 20+ identified issues and recommendations
- **[DEVELOPMENT.md](docs/DEVELOPMENT.md)** - Local development setup, workflows, troubleshooting guide
- **[PERFORMANCE.md](docs/PERFORMANCE.md)** - Performance analysis, optimization strategies, tuning recommendations
- **[SECURITY.md](docs/SECURITY.md)** - Security hardening guide, vulnerability mitigation, compliance roadmap
- **[TODO.md](docs/TODO.md)** - Prioritized action items, sprint planning, development roadmap

### Additional Resources

- **[CLAUDE.md](CLAUDE.md)** - Guide for Claude Code instances working with this repository
- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Step-by-step deployment walkthrough
- **[docs/staging/SECURITY_REVIEW.md](docs/staging/SECURITY_REVIEW.md)** - Comprehensive security audit (20 issues)

## Roadmap

### Phase 1: Critical Security (Week 1)
- [x] Create comprehensive documentation
- [ ] Remove hardcoded credentials
- [ ] Implement container security contexts
- [ ] Deploy zero-trust network policies

### Phase 2: High Priority (Weeks 2-4)
- [ ] Stop using `:latest` tags
- [ ] Implement image scanning in CI/CD
- [ ] Deploy resource quotas and HPA
- [ ] Increase database replicas for HA
- [ ] Deploy monitoring stack (Prometheus + Grafana)

### Phase 3: Enhancements (Months 2-3)
- [ ] Deploy PgBouncer for connection pooling
- [ ] Implement RBAC for all service accounts
- [ ] Add security headers and rate limiting
- [ ] Implement GitOps with ArgoCD
- [ ] Optimize storage classes

### Phase 4: Advanced Features (Q1 2026)
- [ ] Implement service mesh (Istio) with mTLS
- [ ] Deploy runtime security (Falco)
- [ ] Implement policy enforcement (OPA Gatekeeper)
- [ ] Distributed tracing (Jaeger)
- [ ] Multi-region deployment

See [TODO.md](docs/TODO.md) for complete roadmap with deadlines and ownership.

## Contributing

### Development Workflow

1. Create feature branch: `git checkout -b feature/new-feature`
2. Make changes to manifests
3. Test locally: `kubectl apply -k overlays/dev/`
4. Validate: `./scripts/validate-deployment.sh`
5. Commit with descriptive message
6. Create pull request

### Commit Message Format

```
<type>: <subject>

<body>

<footer>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

Example:
```
feat: add HPA configuration for ASMM8 service

- Configure min/max replicas
- Add CPU and memory metrics
- Test autoscaling behavior under load

Closes #123
```

### Code Review Checklist

- [ ] Security context defined for all pods
- [ ] Resource requests and limits specified
- [ ] Health checks (liveness/readiness) configured
- [ ] No hardcoded credentials or secrets
- [ ] Network policies updated if needed
- [ ] Documentation updated
- [ ] Changes tested in dev environment

## Support

### Getting Help

- 📖 **Documentation:** Start with [DEVELOPMENT.md](docs/DEVELOPMENT.md) and [ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 🐛 **Issues:** Check [TODO.md](docs/TODO.md) for known issues and workarounds
- 🔒 **Security:** Review [SECURITY.md](docs/SECURITY.md) and [SECURITY_REVIEW.md](docs/staging/SECURITY_REVIEW.md)

### Contact

- **Platform Team:** platform-team@securetivity.com
- **Security Team:** security-team@securetivity.com
- **On-Call:** Use PagerDuty for production issues

## License

Proprietary - Copyright © 2025 Securetivity. All rights reserved.

---

**Last Updated:** November 19, 2025
**Version:** 1.0.0
**Maintainer:** Platform Team
