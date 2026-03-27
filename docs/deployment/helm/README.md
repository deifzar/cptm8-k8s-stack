# CPTM8 Helm Deployment Documentation

This directory contains comprehensive documentation for deploying CPTM8 using Helm.

---

## Documentation Index

| Document | Description |
|----------|-------------|
| [Local Deployment Guide](./local-deployment-guide.md) | Deploy to local Kind cluster for development |
| [Cloud Deployment Guide](./cloud-deployment-guide.md) | Deploy to AWS EKS or Azure AKS |
| [Helm Quickstart](./helm-quickstart.md) | Quick command reference |
| [Values Reference](./values-reference.md) | Complete values.yaml documentation |

---

## Quick Start

### Prerequisites

```bash
# Required tools
brew install helm kubectl kind

# Verify
helm version
kubectl version --client
kind version
```

### Local Development

```bash
# 1. Create Kind cluster
kind create cluster --name cptm8-dev

# 2. Deploy with Helm
helm install cptm8 helm -n cptm8-dev --create-namespace

# 3. Access
kubectl port-forward svc/dashboardm8-service 3000:3000 -n cptm8-dev
open http://localhost:3000
```

### Cloud Deployment

```bash
# AWS EKS
aws eks update-kubeconfig --name cptm8-staging-cluster --region eu-south-2
helm install cptm8 helm -n cptm8-staging \
  -f helm/values-staging-aws.yaml \
  -f <(sops -d values-secrets.yaml)

# Azure AKS
az aks get-credentials --name cptm8-staging-aks --resource-group cptm8-staging-rg
helm install cptm8 helm -n cptm8-staging \
  -f helm/values-staging-azure.yaml \
  -f <(sops -d values-secrets.yaml)
```

---

## Chart Structure

```
helm/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default values (dev)
├── values-staging-aws.yaml       # AWS EKS values
├── values-staging-azure.yaml     # Azure AKS values
└── templates/
    ├── _helpers.tpl              # Named templates
    ├── _go-scanner.tpl           # Scanner deployment template
    ├── _frontend.tpl             # Frontend deployment template
    ├── _init-container.tpl       # Init containers
    ├── _probes.tpl               # Health probes
    ├── _security-context.tpl     # Security contexts
    ├── namespace.yaml
    ├── configmaps/               # ConfigMaps
    ├── secrets/                  # Secrets
    ├── storage/                  # StorageClasses, PVs, PVCs
    ├── databases/                # PostgreSQL, MongoDB, RabbitMQ, OpenSearch
    ├── deployments/              # Scanner & Frontend deployments
    ├── services/                 # All services
    ├── jobs/                     # CronJobs, Init jobs
    ├── rbac/                     # ServiceAccounts, Roles
    ├── security/                 # NetworkPolicies
    ├── ingress/                  # Ingress resources
    ├── vector/                   # Vector log aggregation
    └── NOTES.txt                 # Post-install instructions
```

---

## Environment Comparison

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| Cluster | Kind (local) | EKS/AKS | EKS/AKS |
| Registry | Local/ECR | ECR/ACR | ECR/ACR |
| Storage | Local Path | EBS/Azure Disk | EBS/Azure Disk |
| Ingress | NodePort | ALB/NGINX | ALB/NGINX |
| TLS | None | Let's Encrypt | Let's Encrypt |
| Replicas | 1 | 2-3 | 3+ |
| Resources | Minimal | Medium | High |
| Autoscaling | Disabled | Enabled | Enabled |
| NetworkPolicies | Optional | Enabled | Enabled |
| Secrets | Inline | SOPS | External Secrets |

---

## Common Operations

### Upgrade

```bash
helm upgrade cptm8 helm -n cptm8-dev --wait
```

### Rollback

```bash
helm rollback cptm8 -n cptm8-dev
```

### Uninstall

```bash
helm uninstall cptm8 -n cptm8-dev
```

### Debug

```bash
helm template cptm8 helm --debug
helm lint helm --strict
```

---

## Related Documentation

- [Kustomize Deployment](../base_overlays_kustomize/) - Alternative deployment method
- [CI/CD Pipeline](../cicd-pipeline-guide.md) - Automated deployments
- [AWS Staging Guide](../cloud/AWS/aws-staging-guide.md) - AWS-specific setup
- [Azure Staging Guide](../cloud/Azure/azure-staging-guide.md) - Azure-specific setup