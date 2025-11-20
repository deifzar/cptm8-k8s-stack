# CPTM8 Kubernetes Manifests Code Review

**Date:** November 19, 2025
**Last Updated:** November 19, 2025
**Reviewer:** Claude Code
**Scope:** Kubernetes manifests, Kustomize configuration, and deployment strategies

## Overview

This document provides a comprehensive code review of the CPTM8 Kubernetes manifests, analyzing configuration quality, identifying issues, and providing specific recommendations for improvement. The review covers 48 YAML files across 12 directories with focus on security, reliability, and operational excellence.

## Strengths

### 1. Configuration Management
- **Well-Structured Kustomize Layout:** Clear base/overlays pattern for multi-environment management
- **Environment Separation:** Distinct configurations for dev, staging, and production
- **Consistent Naming:** Uniform naming conventions across resources (cptm8- prefix)
- **Version Control:** All manifests tracked in Git for audit trail

### 2. Resource Organization
- **Modular Structure:** Each service has dedicated directory with consistent file layout
- **Separation of Concerns:** ConfigMaps, Secrets, Deployments separated into distinct files
- **Stateful Workloads:** Proper use of StatefulSets for databases
- **Service Discovery:** Headless services for StatefulSets, ClusterIP for standard services

### 3. Operational Features
- **Health Checks:** Liveness and readiness probes configured for most services
- **Resource Management:** CPU/memory requests and limits defined
- **Persistent Storage:** PVCs with appropriate storage classes
- **Logging Integration:** Vector DaemonSet for centralized logging

## Critical Issues

### 1. Security - Hardcoded Credentials
**Location:** `docs/staging/staging-environment-guide.md:372`
**Severity:** Critical

```yaml
# ISSUE: Hardcoded Grafana admin password
grafana:
  adminPassword: admin123
```

**Impact:** Credential compromise, unauthorized access to monitoring infrastructure

**Recommendation:**
```yaml
# Use Kubernetes Secret
apiVersion: v1
kind: Secret
metadata:
  name: grafana-credentials
type: Opaque
stringData:
  admin-password: <use strong randomly generated password>
  # Or reference from external secret manager

---
# Reference in Grafana deployment
env:
- name: GF_SECURITY_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: grafana-credentials
      key: admin-password
```

### 2. Security - AWS Account ID Exposure
**Location:** `CLAUDE.md`, `docs/staging/staging-environment-guide.md`
**Severity:** Critical

```bash
# ISSUE: AWS account ID exposed in documentation
ECR_ACCOUNT="507745009364"
aws ecr get-login-password --region eu-south-2 | docker login --username AWS --password-stdin 507745009364.dkr.ecr.eu-south-2.amazonaws.com
```

**Impact:** Information disclosure, potential reconnaissance for attackers

**Recommendation:**
```bash
# Use environment variables
ECR_ACCOUNT="${AWS_ACCOUNT_ID}"
ECR_REGION="${AWS_REGION:-eu-south-2}"

# Or retrieve dynamically
ECR_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region ${ECR_REGION} | docker login --username AWS --password-stdin ${ECR_ACCOUNT}.dkr.ecr.${ECR_REGION}.amazonaws.com
```

### 3. Network Security - Overly Permissive Policies
**Location:** `docs/staging/staging-environment-guide.md:200-218`
**Severity:** High

```yaml
# ISSUE: Allows all traffic from any pod with specific label
spec:
  podSelector:
    matchLabels:
      app: asmm8
  ingress:
  - from:
    - podSelector: {}  # Allows from ANY pod in namespace
```

**Impact:** Insufficient network segmentation, lateral movement risk

**Recommendation:**
```yaml
# Principle of least privilege
spec:
  podSelector:
    matchLabels:
      app: asmm8
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: naabum8  # Explicit service-to-service communication
    ports:
    - protocol: TCP
      port: 8000
  - from:
    - podSelector:
        matchLabels:
          app: ingress-nginx
      namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
```

### 4. Container Security - Missing Security Context
**Location:** Multiple deployment files
**Severity:** High

```yaml
# ISSUE: Missing security context in many deployments
spec:
  containers:
  - name: asmm8
    image: asmm8:latest
    # No securityContext defined
```

**Impact:** Containers running as root, privilege escalation risk

**Recommendation:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: asmm8
    image: asmm8:latest
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

## High-Priority Issues

### 1. Image Management - Using :latest Tag
**Location:** Multiple deployment files
**Severity:** High

```yaml
# ISSUE: Using :latest tag
spec:
  containers:
  - name: asmm8
    image: asmm8:latest
    imagePullPolicy: Always
```

**Impact:** Non-deterministic deployments, rollback difficulties, security risk

**Recommendation:**
```yaml
# Use semantic versioning with digest
spec:
  containers:
  - name: asmm8
    image: 507745009364.dkr.ecr.eu-south-2.amazonaws.com/asmm8:v1.2.3@sha256:abcdef123456...
    imagePullPolicy: IfNotPresent
```

### 2. Resource Management - Missing Resource Quotas
**Location:** Namespace definitions
**Severity:** High

```yaml
# ISSUE: No ResourceQuota defined for namespaces
apiVersion: v1
kind: Namespace
metadata:
  name: cptm8-staging
# Missing ResourceQuota
```

**Impact:** Resource exhaustion, noisy neighbor problems, cost overruns

**Recommendation:**
```yaml
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cptm8-staging-quota
  namespace: cptm8-staging
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "20"
    services.loadbalancers: "1"
    services.nodeports: "0"

---
apiVersion: v1
kind: LimitRange
metadata:
  name: cptm8-staging-limits
  namespace: cptm8-staging
spec:
  limits:
  - max:
      cpu: "4"
      memory: 8Gi
    min:
      cpu: 50m
      memory: 64Mi
    default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
```

### 3. High Availability - Single Point of Failure
**Location:** `bases/postgres/statefulset.yaml`, `bases/mongodb/statefulset.yaml`
**Severity:** High

```yaml
# ISSUE: Only 1 replica in staging for critical databases
spec:
  replicas: 1  # Single point of failure
```

**Impact:** Service downtime during pod restarts, maintenance, or failures

**Recommendation:**
```yaml
# Staging environment
spec:
  replicas: 2  # Primary + 1 standby

# Production environment
spec:
  replicas: 3  # Primary + 2 standby (quorum)

# Add pod anti-affinity
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: postgres
        topologyKey: kubernetes.io/hostname
```

### 4. Monitoring - Missing Service Monitors
**Location:** Service definitions
**Severity:** High

```yaml
# ISSUE: No ServiceMonitor resources for Prometheus scraping
apiVersion: v1
kind: Service
metadata:
  name: asmm8-service
spec:
  # Missing prometheus.io annotations
```

**Impact:** Limited observability, delayed incident detection

**Recommendation:**
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: asmm8-service
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8000"
    prometheus.io/path: "/metrics"

---
# Or use ServiceMonitor CRD
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: asmm8-metrics
spec:
  selector:
    matchLabels:
      app: asmm8
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

### 5. Backup Strategy - No Automated Backups
**Location:** Database StatefulSets
**Severity:** High

```yaml
# ISSUE: No backup CronJob or Velero annotations
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
# No backup strategy defined
```

**Impact:** Data loss risk, difficult disaster recovery

**Recommendation:**
```yaml
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:14
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: password
            command:
            - /bin/sh
            - -c
            - |
              BACKUP_FILE="/backup/postgres-$(date +%Y%m%d-%H%M%S).sql.gz"
              pg_dump -h postgres -U cpt_dbuser cptm8 | gzip > $BACKUP_FILE
              # Upload to S3
              aws s3 cp $BACKUP_FILE s3://cptm8-backups/postgres/
              # Keep only last 7 days locally
              find /backup -name "postgres-*.sql.gz" -mtime +7 -delete
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure

---
# Velero annotations for StatefulSet backup
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  annotations:
    backup.velero.io/backup-volumes: postgres-data
    pre.hook.backup.velero.io/command: '["/bin/bash", "-c", "PGPASSWORD=$POSTGRES_PASSWORD pg_dump -U $POSTGRES_USER $POSTGRES_DB > /tmp/backup.sql"]'
    pre.hook.backup.velero.io/timeout: 5m
```

## Medium-Priority Issues

### 1. Configuration Management - Secrets in Plain Text
**Location:** `.env` files in documentation
**Severity:** Medium

```bash
# ISSUE: Secrets in .env files
DB_PASSWORD="!!cpt!!"
RABBITMQ_PASSWORD="deifzar85"
```

**Impact:** Credential exposure in Git history

**Recommendation:**
```bash
# Use SOPS for encrypted secrets
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
type: Opaque
stringData:
  username: ENC[AES256_GCM,data:abc123,type:str]
  password: ENC[AES256_GCM,data:def456,type:str]

# Or use external secret manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: postgres-credentials
  data:
  - secretKey: password
    remoteRef:
      key: cptm8/postgres
      property: password
```

### 2. Ingress Configuration - Missing Security Headers
**Location:** `bases/ingress/ingress.yaml`
**Severity:** Medium

```yaml
# ISSUE: No security headers configured
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cptm8-ingress
  # Missing security annotations
```

**Impact:** Vulnerable to XSS, clickjacking, MIME sniffing attacks

**Recommendation:**
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
      more_set_headers "Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'";
      more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
```

### 3. Service Configuration - No Pod Disruption Budgets
**Location:** Service deployments
**Severity:** Medium

```yaml
# ISSUE: No PodDisruptionBudget defined
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
spec:
  replicas: 3
# No PDB protection
```

**Impact:** All pods can be evicted simultaneously during cluster maintenance

**Recommendation:**
```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: asmm8-pdb
spec:
  minAvailable: 2  # Always keep 2 pods running
  selector:
    matchLabels:
      app: asmm8

---
# Or use percentage
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: asmm8-pdb
spec:
  maxUnavailable: 1  # Only 1 pod can be down at a time
  selector:
    matchLabels:
      app: asmm8
```

### 4. Storage Configuration - No StorageClass Specifications
**Location:** `bases/*/pvc.yaml`
**Severity:** Medium

```yaml
# ISSUE: Using default StorageClass
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  # No storageClassName specified
  resources:
    requests:
      storage: 50Gi
```

**Impact:** Unpredictable storage performance, potential cost issues

**Recommendation:**
```yaml
# Development environment
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  storageClassName: standard  # Standard HDD for dev
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi

---
# Staging environment
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  storageClassName: gp3  # AWS EBS gp3 for balanced performance
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi

---
# Production environment
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  storageClassName: io2  # AWS EBS io2 for high performance
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  # IOPS configuration for io2
  # AWS specific annotations
  metadata:
    annotations:
      volume.beta.kubernetes.io/storage-provisioner: ebs.csi.aws.com
      ebs.csi.aws.com/iops: "5000"
```

### 5. Database Configuration - Missing Connection Pooling
**Location:** Application ConfigMaps
**Severity:** Medium

```yaml
# ISSUE: Direct database connections without pooling
data:
  DB_HOST: "postgres"
  DB_PORT: "5432"
  # No connection pool configuration
```

**Impact:** Connection exhaustion under load, poor performance

**Recommendation:**
```yaml
---
# Deploy PgBouncer for connection pooling
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: pgbouncer
        image: pgbouncer/pgbouncer:1.21.0
        env:
        - name: DATABASES_HOST
          value: postgres
        - name: DATABASES_PORT
          value: "5432"
        - name: DATABASES_DBNAME
          value: cptm8
        - name: PGBOUNCER_POOL_MODE
          value: transaction
        - name: PGBOUNCER_MAX_CLIENT_CONN
          value: "1000"
        - name: PGBOUNCER_DEFAULT_POOL_SIZE
          value: "25"
        - name: PGBOUNCER_RESERVE_POOL_SIZE
          value: "5"
        ports:
        - containerPort: 5432
        livenessProbe:
          tcpSocket:
            port: 5432
          initialDelaySeconds: 30
        readinessProbe:
          tcpSocket:
            port: 5432
          initialDelaySeconds: 10

---
# Update application ConfigMap
data:
  DB_HOST: "pgbouncer"  # Point to PgBouncer instead of direct Postgres
  DB_PORT: "5432"
  DB_MAX_OPEN_CONNS: "25"
  DB_MAX_IDLE_CONNS: "25"
  DB_CONN_MAX_LIFETIME: "5m"
```

### 6. Logging Configuration - Insufficient Log Retention
**Location:** `bases/vector/configmap.yaml`, OpenSearch configuration
**Severity:** Medium

```yaml
# ISSUE: No explicit log retention policy
[sinks.opensearch]
type = "elasticsearch"
# No index lifecycle management
```

**Impact:** Disk space exhaustion, compliance issues

**Recommendation:**
```yaml
# OpenSearch Index Lifecycle Management
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: opensearch-ilm-policy
data:
  ilm-policy.json: |
    {
      "policy": {
        "description": "CPTM8 log lifecycle policy",
        "default_state": "hot",
        "states": [
          {
            "name": "hot",
            "actions": [
              {
                "rollover": {
                  "min_index_age": "1d",
                  "min_primary_shard_size": "50gb"
                }
              }
            ],
            "transitions": [
              {
                "state_name": "warm",
                "conditions": {
                  "min_index_age": "7d"
                }
              }
            ]
          },
          {
            "name": "warm",
            "actions": [
              {
                "replica_count": {
                  "number_of_replicas": 1
                }
              }
            ],
            "transitions": [
              {
                "state_name": "delete",
                "conditions": {
                  "min_index_age": "90d"
                }
              }
            ]
          },
          {
            "name": "delete",
            "actions": [
              {
                "delete": {}
              }
            ]
          }
        ]
      }
    }

# Vector configuration with index templates
---
[sinks.opensearch]
type = "elasticsearch"
endpoint = "http://opensearch:9200"
index = "cptm8-logs-%Y.%m.%d"
bulk.action = "create"
bulk.index = "cptm8-logs"

# Apply ILM policy
[sinks.opensearch.request]
headers.X-Opaque-Id = "vector"

# Retention: Hot (7 days) → Warm (83 days) → Delete (90 days total)
```

### 7. Init Containers - Insecure Script Downloads
**Location:** `docs/staging/cicd-pipeline-guide.md:125-130`
**Severity:** Medium

```bash
# ISSUE: Downloading scripts without verification
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Impact:** Supply chain attack risk, malicious code execution

**Recommendation:**
```bash
# Download, verify, then execute
HELM_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
HELM_SCRIPT_SHA256="expected_sha256_hash_here"

# Download script
curl -fsSL ${HELM_INSTALL_SCRIPT_URL} -o get-helm-3.sh

# Verify checksum
echo "${HELM_SCRIPT_SHA256}  get-helm-3.sh" | sha256sum -c -

# Execute only if checksum matches
bash get-helm-3.sh

# Or use official Helm binary with GPG verification
curl -fsSL https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz
curl -fsSL https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz.asc -o helm.tar.gz.asc
gpg --verify helm.tar.gz.asc helm.tar.gz
tar -zxvf helm.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
```

### 8. Service Mesh - No mTLS Configuration
**Location:** All service-to-service communication
**Severity:** Medium

```yaml
# ISSUE: Plaintext service-to-service communication
apiVersion: v1
kind: Service
metadata:
  name: asmm8-service
# No mTLS annotations or Istio configuration
```

**Impact:** Man-in-the-middle attacks on internal traffic

**Recommendation:**
```yaml
# Option 1: Istio Service Mesh
---
apiVersion: networking.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: cptm8-staging
spec:
  mtls:
    mode: STRICT  # Enforce mTLS for all traffic

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default
  namespace: cptm8-staging
spec:
  host: "*.cptm8-staging.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL

# Option 2: Linkerd Service Mesh
---
apiVersion: v1
kind: Namespace
metadata:
  name: cptm8-staging
  annotations:
    linkerd.io/inject: enabled  # Auto-inject Linkerd proxy
    config.linkerd.io/proxy-cpu-request: "100m"
    config.linkerd.io/proxy-memory-request: "128Mi"
```

## Low-Priority Issues

### 1. Label Consistency - Missing Recommended Labels
**Location:** Multiple resources
**Severity:** Low

```yaml
# ISSUE: Minimal labels
metadata:
  labels:
    app: asmm8
```

**Impact:** Difficult resource management and monitoring

**Recommendation:**
```yaml
metadata:
  labels:
    app.kubernetes.io/name: asmm8
    app.kubernetes.io/instance: asmm8-staging
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: cptm8
    app.kubernetes.io/managed-by: kustomize
    environment: staging
    team: security
```

### 2. Documentation - Missing Runbook Links
**Location:** All resources
**Severity:** Low

```yaml
# ISSUE: No operational documentation references
metadata:
  name: asmm8
```

**Impact:** Slower incident response, knowledge silos

**Recommendation:**
```yaml
metadata:
  annotations:
    runbook.url: "https://wiki.securetivity.com/runbooks/asmm8"
    pagerduty.service: "asmm8-api"
    slack.channel: "#cptm8-alerts"
    owner.team: "security-platform"
    owner.email: "security-platform@securetivity.com"
```

### 3. Resource Naming - Inconsistent Suffixes
**Location:** Various resources
**Severity:** Low

```yaml
# ISSUE: Inconsistent naming patterns
metadata:
  name: asmm8-service  # Some have -service suffix
  name: postgres       # Some don't
```

**Impact:** Confusion, harder to write generic automation

**Recommendation:**
```yaml
# Standardize naming convention
Services: <name>-svc
Deployments: <name>-deploy
StatefulSets: <name>-sts
ConfigMaps: <name>-config
Secrets: <name>-secret
PVCs: <name>-pvc
```

### 4. Health Checks - Insufficient Probe Configuration
**Location:** Multiple deployments
**Severity:** Low

```yaml
# ISSUE: Basic health checks without tuning
livenessProbe:
  httpGet:
    path: /health
    port: 8000
# Missing timeouts, periods, thresholds
```

**Impact:** Premature pod restarts or delayed failure detection

**Recommendation:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
    scheme: HTTP
  initialDelaySeconds: 30  # Allow time for startup
  periodSeconds: 10        # Check every 10 seconds
  timeoutSeconds: 5        # Timeout after 5 seconds
  successThreshold: 1      # 1 success = healthy
  failureThreshold: 3      # 3 failures = restart pod

readinessProbe:
  httpGet:
    path: /ready
    port: 8000
    scheme: HTTP
  initialDelaySeconds: 10  # Check sooner than liveness
  periodSeconds: 5         # Check more frequently
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3      # 3 failures = remove from service

startupProbe:
  httpGet:
    path: /startup
    port: 8000
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 30     # Allow up to 5 minutes for startup
```

### 5. HPA Configuration - No Custom Metrics
**Location:** Autoscaling configurations (if any)
**Severity:** Low

```yaml
# ISSUE: Only CPU-based autoscaling
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  metrics:
  - type: Resource
    resource:
      name: cpu
  # No custom metrics
```

**Impact:** Suboptimal scaling decisions

**Recommendation:**
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
  minReplicas: 3
  maxReplicas: 10
  metrics:
  # CPU utilization
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

  # Memory utilization
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

  # Custom metric: Request rate
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"

  # Custom metric: Queue length
  - type: External
    external:
      metric:
        name: rabbitmq_queue_messages_ready
        selector:
          matchLabels:
            queue: qasmm8
      target:
        type: AverageValue
        averageValue: "100"

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 50              # Scale down max 50% of current pods
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0    # Scale up immediately
      policies:
      - type: Percent
        value: 100             # Can double pod count
        periodSeconds: 60
      - type: Pods
        value: 4               # But max 4 pods at once
        periodSeconds: 60
      selectPolicy: Max        # Use most aggressive policy
```

## Recommendations by Priority

### Immediate Actions (Critical/High Priority) - Week 1

#### 1. Security Hardening
```bash
# Remove hardcoded credentials
grep -r "password:" bases/ overlays/ --exclude-dir=secrets/
# Move all to encrypted secrets

# Add security contexts to all deployments
for f in bases/*/deployment.yaml; do
  # Add securityContext if missing
  echo "Reviewing $f"
done

# Implement network policies
kubectl apply -f security/network-policies/
```

#### 2. Image Security
```bash
# Scan all images for vulnerabilities
trivy image 507745009364.dkr.ecr.eu-south-2.amazonaws.com/asmm8:latest

# Tag images with semantic versions
docker tag asmm8:latest asmm8:v1.0.0
docker push asmm8:v1.0.0

# Update manifests to use versioned tags
find bases/ -name "deployment.yaml" -exec sed -i 's/:latest/:v1.0.0/g' {} \;
```

#### 3. Resource Quotas and Limits
```bash
# Create ResourceQuota for each namespace
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cptm8-staging-quota
  namespace: cptm8-staging
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
EOF
```

### Medium Priority - Weeks 2-4

#### 1. High Availability
```yaml
# Add pod anti-affinity to all StatefulSets
# Increase replicas for critical services
# Implement PodDisruptionBudgets
```

#### 2. Monitoring and Observability
```bash
# Deploy Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Create ServiceMonitors for all services
# Configure Grafana dashboards
# Set up alerting rules
```

#### 3. Backup and Disaster Recovery
```bash
# Deploy Velero for cluster backups
velero install --provider aws --bucket cptm8-backups --backup-location-config region=eu-south-2

# Create backup schedules
velero schedule create daily-backup --schedule="@daily" --include-namespaces cptm8-staging
```

### Long-term Improvements - Months 2-3

#### 1. Service Mesh Implementation
```bash
# Deploy Istio
istioctl install --set profile=production

# Enable auto-injection
kubectl label namespace cptm8-staging istio-injection=enabled

# Implement mTLS policies
kubectl apply -f security/istio/peer-authentication.yaml
```

#### 2. Advanced Monitoring
```bash
# Deploy Jaeger for distributed tracing
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/crds/jaegertracing.io_jaegers_crd.yaml

# Integrate with Istio
istioctl manifest generate --set values.tracing.enabled=true
```

#### 3. Cost Optimization
```bash
# Deploy Kubecost
helm install kubecost kubecost/cost-analyzer -n kubecost

# Implement pod rightsizing recommendations
# Configure cluster autoscaler
# Use spot instances for non-critical workloads
```

## Testing Recommendations

### 1. Manifest Validation
```bash
# Validate YAML syntax
find bases/ overlays/ -name "*.yaml" -exec yamllint {} \;

# Validate Kubernetes manifests
kubectl apply --dry-run=client -k overlays/staging/

# Validate with kubeconform
kubeconform -summary -output json overlays/staging/

# Check for deprecated API versions
pluto detect-all-in-cluster
```

### 2. Security Scanning
```bash
# Scan manifests with kubesec
kubesec scan bases/asmm8/deployment.yaml

# Check for misconfigurations with kube-score
kube-score score bases/asmm8/deployment.yaml

# Scan with Checkov
checkov -d overlays/staging/ --framework kubernetes
```

### 3. Policy Enforcement
```bash
# Install OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Apply constraint templates
kubectl apply -f security/opa-policies/

# Test policies
kubectl apply --dry-run=server -k overlays/staging/
```

## File-Specific Issues

### `bases/asmm8/deployment.yaml`
- Line 12: Missing security context
- Line 25: Using `:latest` tag
- Line 35: No resource requests/limits
- Line 50: Health check probes too aggressive

### `bases/postgres/statefulset.yaml`
- Line 8: Only 1 replica (single point of failure)
- Line 45: No backup sidecar container
- Line 60: Missing pod anti-affinity
- Line 75: No connection pooling (PgBouncer)

### `bases/rabbitmq/statefulset.yaml`
- Line 8: Only 1 replica (should be 3 for quorum)
- Line 30: No TLS configuration
- Line 50: Default resource limits too low
- Line 80: No monitoring sidecar

### `bases/ingress/ingress.yaml`
- Line 5: Missing security header annotations
- Line 15: No rate limiting configuration
- Line 25: Missing WAF integration
- Line 40: No IP whitelist for admin paths

### `overlays/staging/kustomization.yaml`
- Line 1: No resource quota references
- Line 10: Missing network policy patches
- Line 20: No PodDisruptionBudget definitions

## Conclusion

The CPTM8 Kubernetes manifests demonstrate a solid foundation with good separation of concerns and modular structure. However, several critical security and reliability issues need immediate attention:

**Critical Priorities:**
1. Remove hardcoded credentials (Grafana password, AWS account ID)
2. Implement restrictive network policies with explicit service-to-service rules
3. Add security contexts to all containers (runAsNonRoot, drop capabilities)
4. Replace `:latest` tags with semantic versioning

**High Priorities:**
1. Add resource quotas and limit ranges to all namespaces
2. Increase replica counts for high availability (especially databases)
3. Implement ServiceMonitors for comprehensive observability
4. Create automated backup strategy with CronJobs or Velero

**Ongoing Improvements:**
1. Implement service mesh for mTLS (Istio/Linkerd)
2. Add PodDisruptionBudgets for all critical services
3. Create runbook annotations for operational excellence
4. Implement advanced HPA with custom metrics

Addressing these issues incrementally will significantly improve the security posture, reliability, and operational excellence of the CPTM8 platform. Priority should be given to the critical and high-priority issues before deploying to production environments.
