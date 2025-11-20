# CPTM8 Kubernetes Security Considerations

**Date:** November 19, 2025
**Last Updated:** November 19, 2025
**Risk Assessment:** Medium to High
**Focus:** Security hardening, compliance, and threat mitigation

## Overview

This document outlines security considerations, vulnerabilities, and recommended security improvements for the CPTM8 Kubernetes infrastructure. Refer to `docs/staging/SECURITY_REVIEW.md` for the comprehensive 20-issue security audit.

## Executive Summary

**Current Security Posture:** Medium
- **Critical Issues:** 3 (hardcoded credentials, account ID exposure, missing AWS profile)
- **High Priority Issues:** 5 (network policies, SSH access, image security, RBAC, resource controls)
- **Medium Priority Issues:** 8 (secrets management, headers, monitoring, backups, etc.)
- **Low Priority Issues:** 4 (documentation, labels, annotations)

**Primary Risks:**
1. Credential compromise (hardcoded Grafana password, plain text secrets)
2. Network segmentation failures (overly permissive network policies)
3. Container breakouts (missing security contexts, running as root)
4. Supply chain attacks (insecure downloads, `:latest` tags, no image scanning)
5. Information disclosure (AWS account IDs in documentation)

## Critical Security Issues

### 1. Credential Management (HIGH RISK)

**Issue:** Credentials stored in multiple insecure locations

**Affected Areas:**
- `docs/staging/staging-environment-guide.md:372` - Hardcoded Grafana password (`admin123`)
- `CLAUDE.md` - AWS account ID exposure (`507745009364`)
- ConfigMaps containing database credentials in plain text
- `.env` files with secrets in documentation

**Risk:** Complete system compromise, data breach, unauthorized access

**Immediate Remediation:**
```yaml
# 1. Remove hardcoded credentials from all documentation
# 2. Use Kubernetes Secrets with SOPS encryption
---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-credentials
  namespace: monitoring
type: Opaque
stringData:
  admin-password: ENC[AES256_GCM,data:encrypted_password_here,type:str]

# 3. Use External Secrets Operator with AWS Secrets Manager
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-credentials
  namespace: cptm8-staging
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: postgres-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: cptm8/postgres
      property: username
  - secretKey: password
    remoteRef:
      key: cptm8/postgres
      property: password

# 4. Rotate all exposed credentials immediately
# 5. Use AWS IAM roles for service accounts (IRSA) instead of credentials
```

### 2. Network Security (HIGH RISK)

**Issue:** Overly permissive network policies allowing lateral movement

**Location:** `docs/staging/staging-environment-guide.md:200-218`

**Risk:** Attacker can move laterally between services if one is compromised

**Remediation:**
```yaml
# Implement zero-trust network policies
---
# 1. Default deny all traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: cptm8-staging
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# 2. Explicit service-to-service policies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: asmm8-policy
  namespace: cptm8-staging
spec:
  podSelector:
    matchLabels:
      app: asmm8
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Only from ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  egress:
  # Only to specific services
  - to:
    - podSelector:
        matchLabels:
          app: pgbouncer
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: rabbitmq
    ports:
    - protocol: TCP
      port: 5672
  # DNS only
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

### 3. Container Security (HIGH RISK)

**Issue:** Containers running with excessive privileges

**Risk:** Container breakout, privilege escalation, host compromise

**Remediation:**
```yaml
# Apply to all deployments and StatefulSets
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
spec:
  template:
    spec:
      # Pod-level security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
        supplementalGroups: []

      containers:
      - name: asmm8
        image: asmm8:v1.2.3

        # Container-level security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop: ["ALL"]
            add: []  # Add only required capabilities
          seccompProfile:
            type: RuntimeDefault

        # Writable volumes for read-only filesystem
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /cache

      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```

## High-Priority Security Issues

### 1. Image Security

**Issues:**
- Using `:latest` tags (non-deterministic deployments)
- No image scanning in CI/CD pipeline
- Insecure script downloads without verification
- Missing image pull secrets for private registries

**Remediation:**
```bash
# 1. Use semantic versioning with SHA digests
image: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/asmm8:v1.2.3@sha256:abc123...

# 2. Scan images in CI/CD
trivy image --severity HIGH,CRITICAL 507745009364.dkr.ecr.eu-south-2.amazonaws.com/asmm8:v1.2.3

# 3. Implement admission controller to reject vulnerable images
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml

# 4. Sign images with cosign
cosign sign --key cosign.key 507745009364.dkr.ecr.eu-south-2.amazonaws.com/asmm8:v1.2.3

# 5. Verify signatures in admission controller
```

### 2. RBAC Configuration

**Issue:** No RBAC policies defined for service accounts

**Remediation:**
```yaml
---
# Service account for ASMM8
apiVersion: v1
kind: ServiceAccount
metadata:
  name: asmm8-sa
  namespace: cptm8-staging

---
# Role with minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: asmm8-role
  namespace: cptm8-staging
rules:
# Read-only access to ConfigMaps and Secrets
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
# Read-only access to own pod info
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
  resourceNames: ["asmm8-*"]

---
# Bind role to service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: asmm8-rolebinding
  namespace: cptm8-staging
subjects:
- kind: ServiceAccount
  name: asmm8-sa
  namespace: cptm8-staging
roleRef:
  kind: Role
  name: asmm8-role
  apiGroup: rbac.authorization.k8s.io

---
# Use service account in deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
spec:
  template:
    spec:
      serviceAccountName: asmm8-sa
      automountServiceAccountToken: false  # Disable if not needed
```

### 3. Pod Security Standards

**Issue:** No Pod Security Standards enforcement

**Remediation:**
```yaml
---
# Enforce restricted Pod Security Standard
apiVersion: v1
kind: Namespace
metadata:
  name: cptm8-staging
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest

# For data tier (requires privileged for some databases)
---
apiVersion: v1
kind: Namespace
metadata:
  name: cptm8-staging
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
```

### 4. Secrets Management with SOPS

**Setup:**
```bash
# 1. Generate age key for SOPS
age-keygen -o key.txt
# Save public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 2. Create .sops.yaml
cat <<EOF > .sops.yaml
creation_rules:
  - path_regex: overlays/.*/secrets/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF

# 3. Encrypt existing secrets
sops -e -i overlays/staging/secrets/postgres-secret.yaml
sops -e -i overlays/staging/secrets/rabbitmq-secret.yaml

# 4. Decrypt and apply in CI/CD
sops -d overlays/staging/secrets/postgres-secret.yaml | kubectl apply -f -
```

### 5. Audit Logging

**Configuration:**
```yaml
---
# Enable Kubernetes audit logging
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log all requests at Metadata level
- level: Metadata
  omitStages: ["RequestReceived"]

# Log all secrets access
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
  omitStages: ["RequestReceived"]

# Log all RBAC changes
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
  omitStages: ["RequestReceived"]

# Log all pod creation/deletion
- level: Request
  verbs: ["create", "delete", "patch"]
  resources:
  - group: ""
    resources: ["pods"]
```

## Medium-Priority Security Issues

### 1. Ingress Security Headers

**Implementation:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cptm8-ingress
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
      more_set_headers "Content-Security-Policy: default-src 'self'";
      more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
      more_set_headers "Permissions-Policy: geolocation=(), microphone=(), camera=()";
```

### 2. Rate Limiting

**Implementation:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cptm8-ingress
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-connections: "10"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"
```

### 3. mTLS with Service Mesh

**Istio Implementation:**
```yaml
---
# Install Istio
# istioctl install --set profile=production

# Enable mTLS for namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: cptm8-staging
spec:
  mtls:
    mode: STRICT

---
# Authorization policy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: asmm8-authz
  namespace: cptm8-staging
spec:
  selector:
    matchLabels:
      app: asmm8
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/ingress-nginx/sa/ingress-nginx"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/asmm8/*"]
```

## Security Monitoring and Incident Response

### 1. Deploy Falco for Runtime Security

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: falco

---
# Install Falco via Helm
# helm install falco falcosecurity/falco -n falco

# Custom rules for CPTM8
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-rules
  namespace: falco
data:
  custom-rules.yaml: |
    - rule: Unauthorized Process in Container
      desc: Detect unauthorized process execution
      condition: >
        spawned_process and
        container and
        not proc.name in (expected_processes)
      output: >
        Unauthorized process started in container
        (user=%user.name command=%proc.cmdline container=%container.name)
      priority: WARNING

    - rule: Sensitive File Access
      desc: Detect access to sensitive files
      condition: >
        open_read and
        container and
        fd.name in (/etc/shadow, /etc/passwd, /root/.ssh/*)
      output: >
        Sensitive file accessed
        (user=%user.name file=%fd.name container=%container.name)
      priority: CRITICAL

    - rule: Outbound Connection from Database
      desc: Detect unexpected outbound connections from database pods
      condition: >
        outbound and
        container and
        container.name contains "postgres" or container.name contains "mongodb"
      output: >
        Unexpected outbound connection from database
        (connection=%fd.name container=%container.name)
      priority: WARNING
```

### 2. Security Scanning with Trivy Operator

```bash
# Install Trivy Operator
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml

# Configure continuous scanning
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: trivy-operator
  namespace: trivy-system
data:
  scanJob.compressLogs: "true"
  vulnerabilityReports.scanner: "Trivy"
  configAuditReports.scanner: "Trivy"
  compliance.failEntriesLimit: "10"
  scanJob.tolerations: "[]"
  metrics.resourceLabelsPrefix: "k8s_label_"
EOF

# View vulnerability reports
kubectl get vulnerabilityreports -A
kubectl describe vulnerabilityreport <report-name>
```

### 3. Policy Enforcement with OPA Gatekeeper

```yaml
---
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Constraint template: Require security context
---
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiresecuritycontext
spec:
  crd:
    spec:
      names:
        kind: K8sRequireSecurityContext
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiresecuritycontext

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := sprintf("Container %v must run as non-root", [container.name])
        }

---
# Apply constraint
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireSecurityContext
metadata:
  name: require-security-context
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces: ["cptm8-staging", "cptm8-prod"]
```

## Compliance and Auditing

### 1. CIS Kubernetes Benchmark

```bash
# Run kube-bench for CIS compliance
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# Wait for completion
kubectl wait --for=condition=complete job/kube-bench

# View results
kubectl logs job/kube-bench

# Expected findings to remediate:
# - API server settings
# - Kubelet configuration
# - RBAC policies
# - Pod Security Standards
```

### 2. OWASP Kubernetes Top 10

**Mitigation Status:**
- K01: Insecure Workload Configurations → **Partially Mitigated** (need security contexts)
- K02: Supply Chain Vulnerabilities → **At Risk** (need image scanning)
- K03: Overly Permissive RBAC → **At Risk** (no RBAC policies defined)
- K04: Lack of Centralized Policy Enforcement → **At Risk** (no OPA/Kyverno)
- K05: Inadequate Logging and Monitoring → **Partially Mitigated** (have Vector, need Falco)
- K06: Broken Authentication Mechanisms → **At Risk** (no mTLS, no auth)
- K07: Missing Network Segmentation → **At Risk** (overly permissive policies)
- K08: Secrets Management Failures → **Critical** (plain text secrets)
- K09: Misconfigured Cluster Components → **Needs Assessment**
- K10: Outdated and Vulnerable Components → **Needs Assessment** (no version tracking)

## Security Improvement Roadmap

### Phase 1: Critical (Week 1)
- [ ] Remove all hardcoded credentials from documentation and code
- [ ] Implement SOPS encryption for all secrets
- [ ] Add security contexts to all deployments
- [ ] Implement zero-trust network policies
- [ ] Use semantic versioning (no `:latest` tags)
- [ ] Scan all container images for vulnerabilities

### Phase 2: High Priority (Weeks 2-4)
- [ ] Implement RBAC for all service accounts
- [ ] Deploy Pod Security Standards enforcement
- [ ] Add rate limiting to Ingress
- [ ] Implement security headers
- [ ] Deploy External Secrets Operator
- [ ] Enable Kubernetes audit logging
- [ ] Deploy Trivy Operator for continuous scanning

### Phase 3: Medium Priority (Months 2-3)
- [ ] Implement service mesh with mTLS (Istio/Linkerd)
- [ ] Deploy Falco for runtime security monitoring
- [ ] Implement OPA Gatekeeper for policy enforcement
- [ ] Add WAF protection (AWS WAF or ModSecurity)
- [ ] Implement backup encryption
- [ ] Add security monitoring dashboards
- [ ] Create incident response runbooks

### Phase 4: Long-term (Months 3-6)
- [ ] Implement zero-trust architecture
- [ ] Add multi-factor authentication
- [ ] Implement secret rotation automation
- [ ] Deploy SIEM integration
- [ ] Achieve SOC 2 compliance
- [ ] Implement penetration testing program
- [ ] Add security chaos engineering

## Security Testing

### 1. Vulnerability Scanning
```bash
# Scan manifests
kubesec scan bases/asmm8/deployment.yaml
kube-score score bases/asmm8/deployment.yaml

# Scan images
trivy image asmm8:v1.2.3
grype asmm8:v1.2.3

# Scan cluster
kube-hunter --remote https://staging.cptm8.securetivity.com
```

### 2. Penetration Testing
```bash
# Use kube-hunter for cluster pentesting
docker run -it --rm --network host aquasec/kube-hunter --remote <cluster-ip>

# Test network policies
kubectl run test-pod --rm -it --image=busybox -- wget -O- http://postgres:5432
# Should fail if network policies are correct
```

## Conclusion

The CPTM8 Kubernetes infrastructure requires immediate security hardening to address critical vulnerabilities. Priority should be given to credential management, container security, and network segmentation.

**Immediate Actions Required:**
1. Remove all hardcoded credentials (Grafana, AWS account IDs)
2. Implement SOPS for secret encryption
3. Add security contexts to all containers
4. Implement restrictive network policies
5. Stop using `:latest` image tags

**Success Metrics:**
- Zero critical vulnerabilities in production
- 100% of secrets encrypted with SOPS
- All containers running with security context
- Zero-trust network policies enforced
- CIS Kubernetes Benchmark score > 90%

**References:**
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NSA Kubernetes Hardening Guide](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/2716980/)
- CPTM8 [SECURITY_REVIEW.md](./staging/SECURITY_REVIEW.md) (comprehensive 20-issue audit)
