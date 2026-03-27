# CPTM8 Helm Quick Reference

Quick command reference for common Helm operations.

---

## Installation

```bash
# Development (local Kind) - NodePort mode (default)
helm install cptm8 helm -n cptm8-dev --create-namespace

# Development (local Kind) - Ingress mode
helm install cptm8 helm -n cptm8-dev --create-namespace \
  -f helm/values-dev-ingress.yaml

# Staging AWS
helm install cptm8 helm -n cptm8-staging \
  -f helm/values-staging-aws.yaml \
  -f <(sops -d values-secrets.yaml)

# Staging Azure
helm install cptm8 helm -n cptm8-staging \
  -f helm/values-staging-azure.yaml \
  -f <(sops -d values-secrets.yaml)
```

---

## Upgrades

```bash
# Basic upgrade
helm upgrade cptm8 helm -n cptm8-dev

# Upgrade with wait
helm upgrade cptm8 helm -n cptm8-dev --wait --timeout 5m

# Atomic upgrade (auto-rollback on failure)
helm upgrade cptm8 helm -n cptm8-dev --atomic --timeout 5m

# Upgrade with value override
helm upgrade cptm8 helm -n cptm8-dev \
  --set scanners.asmm8.replicaCount=2

# Install or upgrade (idempotent)
helm upgrade --install cptm8 helm -n cptm8-dev --create-namespace
```

---

## Rollback

```bash
# View history
helm history cptm8 -n cptm8-dev

# Rollback to previous
helm rollback cptm8 -n cptm8-dev

# Rollback to specific revision
helm rollback cptm8 3 -n cptm8-dev
```

---

## Status & Debugging

```bash
# Release status
helm status cptm8 -n cptm8-dev

# List releases
helm list -n cptm8-dev
helm list -A  # All namespaces

# Get values used
helm get values cptm8 -n cptm8-dev
helm get values cptm8 -n cptm8-dev --all  # Include defaults

# Get manifests
helm get manifest cptm8 -n cptm8-dev
```

---

## Template Rendering

```bash
# Render all templates
helm template cptm8 helm -n cptm8-dev

# Render specific template
helm template cptm8 helm -n cptm8-dev \
  --show-only templates/deployments/scanners.yaml

# Render with custom values
helm template cptm8 helm -n cptm8-dev \
  -f values-custom.yaml

# Dry-run with debug
helm install cptm8 helm -n cptm8-dev --dry-run --debug
```

---

## Validation

```bash
# Lint chart
helm lint helm
helm lint helm --strict

# Validate YAML
helm template cptm8 helm | kubectl apply --dry-run=server -f -

# Check dependencies
helm dependency list helm
helm dependency update helm
```

---

## Uninstall

```bash
# Uninstall release (keeps PVCs)
helm uninstall cptm8 -n cptm8-dev

# Uninstall and delete namespace
helm uninstall cptm8 -n cptm8-dev
kubectl delete namespace cptm8-dev

# Keep history for rollback
helm uninstall cptm8 -n cptm8-dev --keep-history
```

---

## Common Value Overrides

```bash
# Disable a service
--set scanners.num8.enabled=false

# Change replica count
--set scanners.asmm8.replicaCount=3

# Change image tag
--set global.imageTag=v1.2.3

# Disable network policies (debugging)
--set networkPolicies.enabled=false

# Enable ingress
--set ingress.enabled=true \
--set ingress.className=nginx

# Set resource limits
--set 'global.resources.scanner.limits.memory=1Gi'
```

---

## Environment-Specific Commands

### Development

```bash
# Quick deploy
helm upgrade --install cptm8 helm -n cptm8-dev --create-namespace

# Port-forward for access
kubectl port-forward svc/dashboardm8-service 3000:3000 -n cptm8-dev

# Watch pods
kubectl get pods -n cptm8-dev -w

# Restart deployment
kubectl rollout restart deploy/dashboardm8 -n cptm8-dev
```

### Staging/Production

```bash
# Deploy with secrets
helm upgrade --install cptm8 helm \
  -n cptm8-staging \
  -f values-staging.yaml \
  -f <(sops -d values-secrets.yaml) \
  --atomic \
  --timeout 10m

# Check deployment status
kubectl rollout status deploy -n cptm8-staging

# View all resources
kubectl get all -n cptm8-staging
```

---

## Troubleshooting Commands

```bash
# Failed pods
kubectl get pods -n cptm8-dev | grep -v Running

# Pod logs
kubectl logs -f deploy/dashboardm8 -n cptm8-dev
kubectl logs <pod-name> -n cptm8-dev --previous

# Describe resources
kubectl describe pod <pod-name> -n cptm8-dev
kubectl describe pvc <pvc-name> -n cptm8-dev

# Events
kubectl get events -n cptm8-dev --sort-by='.lastTimestamp'

# Exec into pod
kubectl exec -it deploy/dashboardm8 -n cptm8-dev -- /bin/sh

# Test connectivity
kubectl run test --rm -it --image=busybox -n cptm8-dev -- \
  nslookup postgresql-service
```

---

## Helm Plugins

```bash
# Install diff plugin
helm plugin install https://github.com/databus23/helm-diff

# Show diff before upgrade
helm diff upgrade cptm8 helm -n cptm8-dev

# Install secrets plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Use encrypted values
helm secrets upgrade cptm8 helm -f values-secrets.enc.yaml
```