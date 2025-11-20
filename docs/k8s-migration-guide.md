# 📚 CPTM8 Docker → Kubernetes Learning Journey

## 🎯 Purpose

This guide documents your learning journey migrating from Docker Compose to Kubernetes using Claude Desktop. It focuses on **why** decisions were made and **what concepts** you mastered - perfect for understanding the theory behind your implementation.

> **📖 Educational Focus**: This guide explains concepts and patterns. For practical deployment, see **DEPLOYMENT-GUIDE.md**.

## 🏗️ Your Original Docker Architecture

### **What You Started With**
- **6 Go Microservices**: asmm8, naabum8, katanam8, num8, reportingm8, orchestratorm8  
- **Databases**: PostgreSQL, MongoDB, RabbitMQ
- **Search & Logging**: OpenSearch cluster, Vector log aggregation
- **Simple Dependencies**: `depends_on` with health checks

### **Why Migrate to Kubernetes?**
Docker Compose is excellent for development, but Kubernetes provides:
- **Production scalability** - Handle real user loads
- **Self-healing** - Restart failed containers automatically  
- **Rolling updates** - Deploy without downtime
- **Resource management** - CPU/memory limits and requests
- **Advanced networking** - Service discovery and load balancing

> **💡 Key Insight**: You're not just learning Kubernetes - you're learning production-ready architecture patterns.

## 🧠 Core Kubernetes Concepts You Mastered

### **1. RBAC - Role-Based Access Control**

**What is RBAC?**
RBAC controls **who** (users, pods, services) can do **what** (create, read, update, delete) on **which resources** (pods, secrets, deployments) in Kubernetes.

**The Three RBAC Components You Use:**

```yaml
# 1. ServiceAccount - Identity for pods
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ecr-token-refresher
  namespace: cptm8-dev
---
# 2. Role - Permissions within a namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ecr-secret-manager
  namespace: cptm8-dev
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "create", "patch", "delete"]
---
# 3. RoleBinding - Connect ServiceAccount to Role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ecr-token-refresher-binding
  namespace: cptm8-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ecr-secret-manager
subjects:
- kind: ServiceAccount
  name: ecr-token-refresher
  namespace: cptm8-dev
```

**Why You Need RBAC:**

1. **Security principle of least privilege**: Vector pod only gets permissions to read logs, not to delete deployments
2. **Isolation**: ECR token refresher can only manage secrets in `cptm8-dev` namespace, not cluster-wide
3. **Compliance**: Audit trail of what each component can access

**Your RBAC Setup:**
- `vector-sa` ServiceAccount: Allows Vector to access log files from application pods
- `ecr-token-refresher` ServiceAccount: Allows CronJob to create/update ECR registry secret
- Each has minimal permissions needed for its specific job

> **🔐 Security Win**: Without RBAC, every pod could access all secrets in the cluster. With RBAC, each pod gets only what it needs.

**Common RBAC Debugging:**
```bash
# Check if a ServiceAccount has permission
kubectl auth can-i create secrets --as=system:serviceaccount:cptm8-dev:ecr-token-refresher -n cptm8-dev

# View all roles in namespace
kubectl get roles,rolebindings -n cptm8-dev

# Describe role to see permissions
kubectl describe role ecr-secret-manager -n cptm8-dev
```

> **🎓 Learning**: RBAC is one of Kubernetes' most powerful security features. Your deployment applies it from day one.

### **2. Declarative vs Imperative**

**Docker Compose way (still declarative but limited):**
```yaml
services:
  asmm8:
    depends_on:
      postgres: 
        condition: service_healthy
```

**Your Kubernetes way (fully declarative):**
```yaml
# Kubernetes continuously ensures this desired state
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
spec:
  replicas: 1  # Always maintain 1 running instance
```

> **🎓 Learning**: Kubernetes doesn't just start things once - it continuously maintains your desired state.

### **3. Namespace Isolation Concepts**

**What are Namespaces?**
Think of namespaces as virtual clusters within your physical Kubernetes cluster. They provide **logical separation** of resources.

**Your namespace:**
```bash
kubectl create namespace cptm8-dev
```

**Why Isolation Matters:**

1. **Resource Organization**: All CPTM8 resources grouped together
2. **Access Control**: RBAC rules scoped to namespace (ECR refresher can't touch other namespaces)
3. **Resource Quotas**: Can limit CPU/memory per namespace to prevent resource exhaustion
4. **Environment Separation**: dev, staging, prod in same cluster but isolated

**DNS Within Namespaces:**

Kubernetes creates automatic DNS names for services:

```yaml
# Service in same namespace
postgresql-service  # Short form (works within cptm8-dev)

# Fully Qualified Domain Name (FQDN)
postgresql-service.cptm8-dev.svc.cluster.local
#                  └─namespace─┘ └──service─┘ └─cluster domain─┘
```

**How Your Apps Use This:**
```yaml
# In ConfigMap
POSTGRESQL_HOSTNAME: "postgresql-service.cptm8-dev.svc.cluster.local"

# Or simply (if calling from same namespace)
POSTGRESQL_HOSTNAME: "postgresql-service"
```

**Cross-Namespace Communication:**
```bash
# Accessing service in another namespace
curl http://api-service.production.svc.cluster.local:8080
```

**View Resources by Namespace:**
```bash
# List all namespaces
kubectl get namespaces

# View all resources in cptm8-dev
kubectl get all -n cptm8-dev

# Set default namespace (avoid typing -n every time)
kubectl config set-context --current --namespace=cptm8-dev
```

> **🎓 Learning**: Namespaces are Kubernetes' way of creating "resource boundaries" - like folders for your cluster objects.

### **4. StatefulSets vs Deployments**

**When you use StatefulSets:**
- **Databases** (PostgreSQL, MongoDB) - need persistent identity and ordered startup
- **Any service** that needs stable network identity or persistent storage

**When you use Deployments:**
- **Applications** (your Go services) - can be recreated anywhere
- **Stateless services** - no persistent data

```yaml
# Your PostgreSQL (StatefulSet)
kind: StatefulSet
metadata:
  name: postgresqlm8  # Always postgresqlm8-0, postgresqlm8-1, etc.

# Your Go services (Deployment)
kind: Deployment
metadata:
  name: asmm8  # Pod names are random: asmm8-abc123-xyz789
```

**StatefulSet Deep Dive:**

**Predictable Pod Names:**
```bash
# StatefulSet pods get ordinal indices
postgresqlm8-0  # First pod, always this name
postgresqlm8-1  # Second pod (if scaled)
postgresqlm8-2  # Third pod (if scaled)

# Deployment pods get random suffixes
asmm8-7d4f8b9c5-k2x9p  # Random
asmm8-7d4f8b9c5-m8t4w  # Random
```

**The Two-Service Architecture for StatefulSets:**

StatefulSets require a unique networking setup: **TWO services** working together:

**1. Headless Service** (for StatefulSet pod identity):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-headless
spec:
  clusterIP: None  # This makes it "headless" - no virtual IP!
  selector:
    app: postgresqlm8
  ports:
  - port: 5432
```

**2. Regular ClusterIP Service** (for application access):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-service
spec:
  type: ClusterIP  # Has a virtual IP for load balancing
  selector:
    app: postgresqlm8
  ports:
  - port: 5432
```

**Why TWO services?**

| Service Type | Purpose | DNS Created | Used By |
|--------------|---------|-------------|---------|
| **Headless** (`clusterIP: None`) | StatefulSet pod identity | Individual pod DNS: `postgresqlm8-0.postgresql-headless.cptm8-dev.svc.cluster.local` | StatefulSet `serviceName` field, cluster peer discovery |
| **Regular ClusterIP** | Application access | Single load-balanced DNS: `postgresql-service.cptm8-dev.svc.cluster.local` | All your applications (asmm8, naabum8, etc.) |

**The Complete Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Applications                                 │
│  (asmm8, naabum8, katanam8, num8, reportingm8)                 │
└────────────────────────┬────────────────────────────────────────┘
                         │ Connect via regular service
                         ▼
          ┌──────────────────────────────┐
          │  postgresql-service          │ ◄─── Regular ClusterIP
          │  (ClusterIP: 10.96.100.50)  │      (Load balancing)
          └──────────────┬───────────────┘
                         │ Routes to pods
                         ▼
          ┌──────────────────────────────┐
          │  postgresql-headless         │ ◄─── Headless Service
          │  (clusterIP: None)           │      (Pod DNS)
          └──────────────┬───────────────┘
                         │ Provides stable DNS
                         ▼
          ┌──────────────────────────────┐
          │  StatefulSet                 │
          │  serviceName: postgresql-headless
          │  └─ postgresqlm8-0           │ ◄─── Pod with PVC
          │     (with PersistentVolume)  │
          └──────────────────────────────┘
```

**StatefulSet REQUIRES Headless Service:**
```yaml
# StatefulSet specification
apiVersion: apps/v1
kind: StatefulSet
spec:
  serviceName: postgresql-headless  # MUST reference a headless service!
  replicas: 1
```

**DNS Resolution Examples:**

```bash
# Application access (via regular service) - RECOMMENDED
postgresql-service.cptm8-dev.svc.cluster.local
→ Load balances to all PostgreSQL pods

# Pod-specific access (via headless service) - for clustering/admin
postgresqlm8-0.postgresql-headless.cptm8-dev.svc.cluster.local
→ Direct access to specific pod
```

**Why Applications Use Regular Service:**

1. ✅ **Abstraction** - Apps don't need to know pod names
2. ✅ **Resilience** - Works even if pod restarts with new IP
3. ✅ **Future-proof** - Automatic load balancing when you scale
4. ✅ **Best practice** - Services abstract pod complexity

**When to Use Headless Service DNS:**

Direct pod access is only needed for:
- **Database clustering** (PostgreSQL primary/replica discovery)
- **Distributed systems** (RabbitMQ, MongoDB cluster formation)
- **Admin operations** (targeting specific replica for backup)

**Real-World Example - RabbitMQ Clustering:**

```yaml
# RabbitMQ StatefulSet with 3 replicas
env:
- name: RABBITMQ_NODENAME
  value: "rabbit@rabbitmq-0.rabbitmq-headless.cptm8-dev.svc.cluster.local"
- name: RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS
  value: |
    -rabbit cluster_nodes {[
      'rabbit@rabbitmq-0.rabbitmq-headless',
      'rabbit@rabbitmq-1.rabbitmq-headless',
      'rabbit@rabbitmq-2.rabbitmq-headless'
    ],disc}
```

Without headless service DNS, RabbitMQ nodes couldn't discover each other!

**Your Implementation:**

You correctly implemented this pattern for all StatefulSets:

| StatefulSet | Headless Service | Regular Service | Application Uses |
|-------------|------------------|-----------------|------------------|
| **PostgreSQL** | `postgresql-headless` | `postgresql-service` | `postgresql-service` ✅ |
| **MongoDB** | `mongodb-primary-headless` | `mongodb-primary-service` | `mongodb-primary-service` ✅ |
| **RabbitMQ** | `rabbitmq-headless` | `rabbitmq-service` | `rabbitmq-service` ✅ |
| **OpenSearch** | `opensearch-cluster` | `opensearch-service` | `opensearch-service` ✅ |

**Common Mistakes to Avoid:**

❌ **Wrong:** Using headless service for application connections
```yaml
# ConfigMap - INCORRECT
POSTGRESQL_HOSTNAME: "postgresqlm8-0.postgresql-headless.cptm8-dev.svc.cluster.local"
```

✅ **Correct:** Using regular service for application connections
```yaml
# ConfigMap - CORRECT
POSTGRESQL_HOSTNAME: "postgresql-service.cptm8-dev.svc.cluster.local"
```

❌ **Wrong:** Missing headless service (StatefulSet won't work properly)
```yaml
kind: StatefulSet
spec:
  serviceName: postgresql-service  # This is NOT headless!
```

✅ **Correct:** StatefulSet references headless service
```yaml
kind: StatefulSet
spec:
  serviceName: postgresql-headless  # Headless service with clusterIP: None
```

❌ **Wrong:** Headless service with conflicting type
```yaml
kind: Service
metadata:
  name: postgresql-headless
spec:
  clusterIP: None
  type: ClusterIP  # ❌ REMOVE THIS - conflicts with clusterIP: None
```

✅ **Correct:** Headless service without type field
```yaml
kind: Service
metadata:
  name: postgresql-headless
spec:
  clusterIP: None  # No "type" field needed
```

**Ordered Startup/Shutdown:**
- StatefulSets start pods **sequentially**: `pod-0` must be Running before `pod-1` starts
- Deployments start pods **in parallel**: All pods start simultaneously

> **🎓 Learning**: Use StatefulSets when pod identity matters (databases, distributed systems). Use Deployments for stateless apps where any pod is interchangeable. StatefulSets ALWAYS require a headless service for pod DNS, plus a regular service for application access.

### **5. ConfigMaps vs Secrets**

**ConfigMaps** (non-sensitive data):
```yaml
data:
  POSTGRESQL_DB: "cptm8"
  POSTGRESQL_HOSTNAME: "postgresql-service.cptm8-dev.svc.cluster.local"
```

**Secrets** (sensitive data with SOPS encryption):
```yaml
data:
  postgresql-root-password: "cGFzc3dvcmQxMjM0Cg=="  # Base64 + SOPS encrypted
```

> **🔐 Security Win**: Your secrets are encrypted in git and only decrypted during deployment.

### **6. Live Configuration Updates - The emptyDir + ConfigMap Pattern**

A common challenge: How to make configuration files **writable** for development while keeping them **version-controlled** in ConfigMaps?

**The Problem:**

ConfigMaps are **read-only** when mounted. You can't edit files mounted from ConfigMaps:

```yaml
# ❌ This doesn't work - ConfigMap mounts are read-only
volumeMounts:
- name: config-volume
  mountPath: /app/configs/subfinderconfig.yaml
  subPath: subfinderconfig.yaml
  readOnly: false  # ❌ This flag doesn't make ConfigMaps writable!
```

```bash
# Try to edit - fails!
kubectl exec pod -- vi /app/configs/subfinderconfig.yaml
# Error: Read-only file system
```

**The Solution: ConfigMap Hot-Reload + emptyDir Pattern**

Your implementation uses a hybrid approach that solves this:

```
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: ConfigMap (Source of Truth - Git Version Controlled)   │
├─────────────────────────────────────────────────────────────────┤
│ apiVersion: v1                                                  │
│ kind: ConfigMap                                                 │
│ metadata:                                                       │
│   name: configuration-template-asmm8                            │
│ data:                                                           │
│   subfinderconfig.yaml: |                                       │
│     # subfinder configuration                                   │
│   subfinderprovider-config.yaml: |                              │
│     # API keys                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ▼ Init Container Copies
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: emptyDir Volume (Writable Temporary Storage)           │
├─────────────────────────────────────────────────────────────────┤
│ initContainers:                                                 │
│ - name: fix-app-ownership                                       │
│   command:                                                      │
│   - sh                                                          │
│   - -c                                                          │
│   - |                                                           │
│     # Copy ConfigMap templates → emptyDir                       │
│     cp -r /config-templates/* /config-writable/                 │
│     chown -R 10001:10001 /config-writable                       │
│   volumeMounts:                                                 │
│   - name: config-volume                                         │
│     mountPath: /config-templates  # ConfigMap (read-only)       │
│   - name: config-writable                                       │
│     mountPath: /config-writable    # emptyDir (writable)        │
│                                                                 │
│ volumes:                                                        │
│ - name: config-writable                                         │
│   emptyDir: {}  # Writable temporary storage                    │
└─────────────────────────────────────────────────────────────────┘
                              ▼ subPath Mounts
┌─────────────────────────────────────────────────────────────────┐
│ Step 3: Main Container (Application Access)                    │
├─────────────────────────────────────────────────────────────────┤
│ containers:                                                     │
│ - name: asmm8                                                   │
│   volumeMounts:                                                 │
│   # Individual config files from emptyDir (all writable!)       │
│   - name: config-writable                                       │
│     mountPath: /app/configs/subfinderconfig.yaml               │
│     subPath: subfinderconfig.yaml                               │
│   - name: config-writable                                       │
│     mountPath: /app/configs/subfinderprovider-config.yaml       │
│     subPath: subfinderprovider-config.yaml                      │
└─────────────────────────────────────────────────────────────────┘
```

**Why This Works:**

1. **ConfigMap** = Source of truth (version controlled, persistent)
2. **Init container** copies ConfigMap → emptyDir (makes it writable)
3. **emptyDir** = Writable storage (ephemeral, lost on pod restart)
4. **subPath mounts** overlay specific files without hiding Docker image files (wordlists)

**Two Update Workflows:**

**Workflow 1: Quick Live Edit (Ephemeral)**
```bash
# Edit file directly in running pod
kubectl exec -it deployment/asmm8 -n cptm8-dev -- \
  vi /app/configs/subfinderconfig.yaml

# ✅ Changes take effect immediately
# ❌ Changes lost on pod restart (emptyDir is ephemeral)
```

**Use cases:** Testing, debugging, rapid iteration

**Workflow 2: Persistent ConfigMap Update**
```bash
# Update ConfigMap (version controlled)
kubectl edit configmap configuration-template-asmm8 -n cptm8-dev

# Restart pod to reinitialize from updated ConfigMap
kubectl rollout restart deployment/asmm8 -n cptm8-dev

# ✅ Changes survive pod restarts
# ✅ Version controlled in git
# ✅ Can be rolled back
```

**Use cases:** Production changes, permanent configuration

**Key Benefits:**

| Aspect | ConfigMap Only | emptyDir + ConfigMap Pattern |
|--------|---------------|------------------------------|
| **Writability** | ❌ Read-only | ✅ Writable |
| **Live edits** | ❌ No | ✅ Yes (ephemeral) |
| **Persistence** | ✅ Yes | ✅ Yes (via ConfigMap) |
| **Version control** | ✅ Yes | ✅ Yes |
| **Docker image files** | ⚠️ Hidden by mount | ✅ Preserved (subPath) |

**Advanced: Preserving Docker Image Files**

Your implementation uses **subPath mounts** to overlay only specific config files:

```yaml
# ❌ Wrong: Mounting entire directory hides wordlists
volumeMounts:
- name: config-writable
  mountPath: /app/configs  # ❌ Hides all Docker image files!

# ✅ Correct: subPath mounts overlay specific files
volumeMounts:
- name: config-writable
  mountPath: /app/configs/subfinderconfig.yaml  # ✅ Only this file
  subPath: subfinderconfig.yaml
# Docker image's /app/configs/wordlist/ remains accessible!
```

**Result:**
```
/app/configs/
├── wordlist/                    # ✅ From Docker image (static)
├── subfinderconfig.yaml         # ✅ From emptyDir (writable)
└── subfinderprovider-config.yaml # ✅ From emptyDir (writable)
```

**When to Use This Pattern:**

| Environment | Use Pattern? | Why |
|-------------|-------------|-----|
| **Development** | ✅ Yes | Fast iteration, live debugging |
| **Staging** | ⚠️ Consider PVC | Persistent live edits for testing |
| **Production** | ❌ No | Use immutable ConfigMaps with versioning |

> **🎓 Learning**: This pattern gives development teams the flexibility to quickly test config changes while maintaining GitOps best practices for production deployments. It's the best of both worlds: rapid development iteration + production-grade configuration management.

### **7. Persistent Volume Architecture**

**The Storage Hierarchy:**

```
StorageClass (how to provision storage)
    ↓
PersistentVolume (actual storage resource)
    ↓
PersistentVolumeClaim (request for storage)
    ↓
Pod (uses the claim)
```

**1. StorageClass - The Provisioner**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner  # Kind local storage
volumeBindingMode: WaitForFirstConsumer
```

**What it does:**
- Defines **how** storage is provisioned (local disk, AWS EBS, GCP Persistent Disk, etc.)
- `WaitForFirstConsumer`: Don't create PV until a pod actually needs it (prevents unschedulable pods)

**2. PersistentVolume (PV) - The Actual Storage**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgresql-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce  # Can be mounted by one pod at a time
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/postgresql  # On Kind node
```

**3. PersistentVolumeClaim (PVC) - The Request**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: local-storage
```

**Think of it like:**
- **StorageClass**: "How do I rent storage?" (rental agency)
- **PV**: "Here's available storage" (actual apartment)
- **PVC**: "I need 2GB storage" (rental application)
- **Pod**: "Mount my PVC at /var/lib/postgresql" (tenant moving in)

**Access Modes Explained:**

| Mode | Abbreviation | Use Case | Your Usage |
|------|--------------|----------|------------|
| **ReadWriteOnce** | RWO | Single pod mounts for read/write | PostgreSQL, MongoDB data directories |
| **ReadOnlyMany** | ROX | Multiple pods mount read-only | Shared config files |
| **ReadWriteMany** | RWX | Multiple pods mount for read/write | **Log files shared between app and Vector** |

**Why Your Log Volumes Need RWX:**

```yaml
# Application pod writes logs
volumeMounts:
- name: asmm8-logs
  mountPath: /var/log/asmm8

# Vector pod reads logs (same volume!)
volumeMounts:
- name: asmm8-logs
  mountPath: /var/log/asmm8
  readOnly: true
```

**Two pods, same volume = ReadWriteMany required!**

**Dynamic vs Static Provisioning:**

```yaml
# Static (you create PV manually) - Used in Kind
kubectl apply -f storage/postgresql-pv.yaml

# Dynamic (cloud provider creates PV automatically) - Used in AWS/GCP
# Just create PVC, PV is auto-created based on StorageClass
```

**Check Storage Status:**
```bash
# View storage classes
kubectl get storageclass

# View persistent volumes (cluster-wide)
kubectl get pv

# View claims (namespace-scoped)
kubectl get pvc -n cptm8-dev

# See which pod is using which PVC
kubectl get pods -n cptm8-dev -o json | jq '.items[] | {name: .metadata.name, volumes: .spec.volumes}'
```

> **🎓 Learning**: Persistent storage in Kubernetes separates the storage lifecycle from the pod lifecycle. Your data survives pod restarts, deletions, and rescheduling.

### **7. Services - The Networking Magic**

**What Services Do:**
- Provide **stable endpoints** even when pods restart
- **Load balance** across multiple pod replicas
- Enable **service discovery** via DNS

**Service Types - The Complete Picture:**

| Type | Use Case | External Access | Your Usage |
|------|----------|-----------------|------------|
| **ClusterIP** | Internal communication only | No | Backend services (PostgreSQL, RabbitMQ) |
| **NodePort** | Expose on each node's IP at static port | Yes (Kind development) | Frontend apps on Kind (3000→30080, 4000→30081) |
| **LoadBalancer** | Cloud load balancer | Yes (cloud only) | Frontend in staging/production |
| **Headless** | Direct pod DNS (ClusterIP: None) | No | StatefulSet databases |

**1. ClusterIP (Default) - Internal Only**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-service
spec:
  type: ClusterIP  # Default, can be omitted
  selector:
    app: postgresqlm8
  ports:
  - port: 5432
    targetPort: 5432
```

**Access:**
- Only from **within cluster**: `postgresql-service:5432`
- DNS: `postgresql-service.cptm8-dev.svc.cluster.local`
- **Not accessible** from outside cluster

**2. NodePort - Development/Testing**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: dashboardm8-nodeport
spec:
  type: NodePort
  selector:
    app: dashboardm8
  ports:
  - port: 3000        # Internal cluster port
    targetPort: 3000  # Pod's container port
    nodePort: 30080   # External port on each node (30000-32767 range)
```

**Access:**
- Internal: `dashboardm8-nodeport:3000`
- External: `<node-ip>:30080`
- On Kind with extraPortMappings: `localhost:3000` (magic!)

**Why Kind extraPortMappings is special:**
```yaml
# Kind cluster config
extraPortMappings:
- containerPort: 30080  # NodePort inside Kind container
  hostPort: 3000        # Port on your actual machine
```

This creates the chain: `localhost:3000` → Kind container `30080` → Service `30080` → Pod `3000`

**3. LoadBalancer - Cloud Production**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: dashboardm8-external
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"  # AWS NLB
spec:
  type: LoadBalancer
  selector:
    app: dashboardm8
  ports:
  - port: 3000
    targetPort: 3000
```

**What happens:**
- Cloud provider creates real load balancer (AWS ALB/NLB, GCP Load Balancer)
- Gets public IP/DNS: `a1b2c3d4.us-east-1.elb.amazonaws.com`
- Routes traffic to healthy pods across all nodes

**On Kind:** LoadBalancer services stay `<pending>` forever (no cloud provider)

**4. Headless Service - Direct Pod Access**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-headless
spec:
  clusterIP: None  # This makes it headless
  selector:
    app: postgresqlm8
```

**Creates individual pod DNS:**
```bash
# Regular service (load balanced)
postgresql-service  → random pod

# Headless service (specific pods)
postgresqlm8-0.postgresql-headless.cptm8-dev.svc.cluster.local
postgresqlm8-1.postgresql-headless.cptm8-dev.svc.cluster.local
```

**StatefulSet Data Persistence - What Survives Restarts?**

A common question: "If RabbitMQ/PostgreSQL/MongoDB restarts, does all data vanish?"

**Answer: It depends on your configuration!**

| Component | With StatefulSet + PVC | Without Persistent Storage |
|-----------|----------------------|---------------------------|
| **Pod data** (databases, queues) | ✅ Survives restarts | ❌ Lost on restart |
| **Durable queues/exchanges** | ✅ Persist to disk | ❌ Lost (no disk to persist to) |
| **Messages marked persistent** | ✅ Survive restarts | ❌ Lost |
| **Active connections/consumers** | ❌ Must reconnect | ❌ Must reconnect |

**Your Setup (Production-Ready):**

```yaml
# StatefulSet with PersistentVolumeClaim
kind: StatefulSet
spec:
  volumeClaimTemplates:
  - metadata:
      name: rabbitmq-vct
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: cptm8-dev-ssd-retain  # ✅ Retain policy!
      resources:
        requests:
          storage: 30Gi

  template:
    spec:
      containers:
      - name: rabbitmq
        volumeMounts:
        - name: rabbitmq-vct
          mountPath: /var/lib/rabbitmq  # All RabbitMQ data persisted here
```

**What This Gives You:**

1. **Durable exchanges** declared with `durable: true` → **Survive restarts** ✅
2. **Durable queues** declared with `durable: true` → **Survive restarts** ✅
3. **Persistent messages** (delivery_mode=2) in durable queues → **Survive restarts** ✅
4. **Non-durable queues/exchanges** → **Lost on restart** (by design)
5. **Consumers/connections** → **Always must reconnect** (this is normal behavior)

**Best Practices for Data Durability:**

```go
// Example: Declare durable queue and exchange in your Go code
channel.ExchangeDeclare(
    "cptm8_exchange",  // name
    "topic",            // type
    true,               // durable ✅ - survives broker restart
    false,              // auto-deleted
    false,              // internal
    false,              // no-wait
    nil,                // arguments
)

channel.QueueDeclare(
    "my_queue",  // name
    true,        // durable ✅ - survives broker restart
    false,       // delete when unused
    false,       // exclusive
    false,       // no-wait
    nil,         // arguments
)

// Publish persistent messages
err = channel.Publish(
    "cptm8_exchange",
    "routing.key",
    false,
    false,
    amqp.Publishing{
        DeliveryMode: amqp.Persistent,  // ✅ Message persists to disk
        ContentType:  "application/json",
        Body:        []byte(message),
    },
)
```

**Consumer Reconnection (Always Required):**

```go
// Implement auto-reconnection in your application code
func connectWithRetry() (*amqp.Connection, error) {
    var conn *amqp.Connection
    var err error

    for i := 0; i < 10; i++ {
        conn, err = amqp.Dial("amqp://rabbitmq-service:5672/")
        if err == nil {
            log.Println("Connected to RabbitMQ")
            return conn, nil
        }
        log.Printf("Failed to connect (attempt %d/10): %v", i+1, err)
        time.Sleep(time.Second * time.Duration(math.Pow(2, float64(i)))) // Exponential backoff
    }
    return nil, err
}
```

**What Happens During a Restart:**

```bash
# Scenario: RabbitMQ pod crashes or is restarted
kubectl delete pod rabbitmq-0 -n cptm8-dev

# StatefulSet immediately creates new pod
# ✅ Same pod name: rabbitmq-0
# ✅ Same PVC attached: rabbitmq-vct-rabbitmq-0
# ✅ All data in /var/lib/rabbitmq preserved
# ✅ Exchanges, queues, messages all intact

# ❌ Consumers disconnected (must reconnect)
# ❌ In-flight messages may need redelivery
```

**Verify Data Persistence:**

```bash
# Check if PVC is properly bound
kubectl get pvc -n cptm8-dev | grep rabbitmq
# Should show: rabbitmq-vct-rabbitmq-0   Bound

# View RabbitMQ data directory size
kubectl exec -n cptm8-dev rabbitmq-0 -- du -sh /var/lib/rabbitmq

# Test persistence
# 1. Create a durable queue via management UI
# 2. Delete the pod: kubectl delete pod rabbitmq-0 -n cptm8-dev
# 3. Wait for new pod to start
# 4. Check management UI - queue still exists! ✅
```

> **🎓 Learning**: StatefulSets + PersistentVolumes give you production-grade data durability. Your RabbitMQ configuration ensures exchanges, queues, and messages survive pod restarts, just like a traditional VM-based deployment.

**Service Selector Magic:**

Services find pods using **label selectors**:

```yaml
# Service selector
selector:
  app: dashboardm8
  tier: frontend

# Pod labels (must match!)
metadata:
  labels:
    app: dashboardm8
    tier: frontend
```

**If labels don't match = service has no endpoints = traffic goes nowhere!**

**Check Service Endpoints:**
```bash
# View which pods are behind a service
kubectl get endpoints -n cptm8-dev postgresql-service

# Expected output:
# NAME                 ENDPOINTS
# postgresql-service   10.244.0.5:5432

# If empty, labels don't match!
kubectl get pods -n cptm8-dev --show-labels
```

> **🌐 Networking Insight**: Services abstract away the complexity of pod IPs changing. They provide stable DNS and automatic load balancing.

## 🚧 Migration Challenges You Solved

### **Challenge 1: Dependencies Without `depends_on`**

**Docker Compose approach:**
```yaml
depends_on:
  rabbitmqm8:
    condition: service_healthy
```

**Your Kubernetes solution:**
1. **Custom health endpoints**: `/ready` checks if dependencies are actually available
2. **Init containers**: Vector waits for OpenSearch cluster health  
3. **Readiness probes**: Kubernetes traffic routing waits for services to be ready

**Why this is better:**
- Kubernetes **continuously** monitors health, not just at startup
- Your `/ready` endpoint checks **actual connectivity**, not just "is the pod running?"
- More resilient to network issues and database restarts

### **Challenge 2: Shared Log Volumes**

**Docker way:**
```yaml
volumes:
  - ./services/asmm8/app/log:/var/log/asmm8  # Host filesystem
```

**Your Kubernetes solution:**
```yaml
# ReadWriteMany PVC shared between app and Vector
volumes:
- name: asmm8-logs
  persistentVolumeClaim:
    claimName: asmm8-logs-pvc
```

**Benefits:**
- Works across **multiple nodes** (unlike host volumes)
- **Persistent** even if pods restart
- **Shareable** between application and log aggregator

### **Challenge 3: Secret Management**

**Docker way:**
```bash
# Plain text files (security risk!)
secrets:
  postgresql_root_password:
    file: ./secrets/postgresql_root_password.txt
```

**Your Kubernetes solution:**
```bash
# SOPS encryption + Kubernetes secrets
sops -d secrets/secrets-dev.encrypted.yaml | kubectl apply -f -

# When decrypting a file with the corresponding identity, SOPS will look for a text file name keys.txt located in a sops subdirectory of your user configuration directory.

# Linux
#  Looks for keys.txt in $XDG_CONFIG_HOME/sops/age/keys.txt;
#  Falls back to $HOME/.config/sops/age/keys.txt if $XDG_CONFIG_HOME isn’t set.
# macOS
#  Looks for keys.txt in $XDG_CONFIG_HOME/sops/age/keys.txt;
#  Falls back to $HOME/Library/Application Support/sops/age/keys.txt if $XDG_CONFIG_HOME isn’t set.
# Windows
# Looks for keys.txt in %AppData%\sops\age\keys.txt`.
# You can override the default lookup by:

# setting the environment variable SOPS_AGE_KEY_FILE;
# setting the SOPS_AGE_KEY environment variable;
# providing a command to output the age keys by setting the SOPS_AGE_KEY_CMD environment variable..

```


**Security improvements:**
- Secrets **encrypted in git** (safe to commit)
- **Decrypted only during deployment** (not stored plain text)
- **Base64 encoded** in Kubernetes (additional encoding layer)

## 🌍 Environment-Specific Deployment Strategies

**One Platform, Three Environments:**

Your CPTM8 platform needs different configurations for development, staging, and production. Here's how Kubernetes concepts apply differently across environments.

### **Development (Kind) - Local Learning**

**Infrastructure:**
- **Cluster**: Kind (Kubernetes in Docker)
- **Storage**: hostPath volumes (maps to Docker container filesystem)
- **Networking**: NodePort + Kind extraPortMappings
- **Load Balancing**: None (single node cluster)

**Key Differences:**
```yaml
# Storage (development only)
spec:
  hostPath:
    path: /mnt/data/postgresql  # Path inside Kind container

# Services (development only)
type: NodePort
nodePort: 30080  # Fixed port for Kind port mapping
```

**Why this works:**
- Kind's `extraPortMappings` forwards `localhost:3000` to NodePort `30080`
- Single-node means no distributed complexity
- Fast iteration (cluster creates in seconds)

**Limitations:**
- ❌ LoadBalancer services stay `<pending>` (no cloud provider)
- ❌ hostPath only works on single node (data loss if node restarts)
- ❌ No real load balancing between replicas

### **Staging (Cloud) - Production Preview**

**Infrastructure:**
- **Cluster**: Managed Kubernetes (EKS, GKE, AKS)
- **Storage**: Cloud persistent disks (EBS, Persistent Disk, Azure Disk)
- **Networking**: Ingress + real cloud load balancer
- **Load Balancing**: Multi-node, cross-AZ

**Key Changes from Dev:**
```yaml
# Storage (cloud dynamic provisioning)
storageClassName: gp3  # AWS EBS GP3
# No hostPath! Cloud provider creates real volumes

# Services (cloud LoadBalancer)
type: LoadBalancer
# Cloud creates real load balancer with public IP
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

**Benefits:**
- ✅ Real load balancing across multiple nodes
- ✅ Persistent storage survives node failures
- ✅ External access via real DNS names
- ✅ Testing production patterns without production risk

### **Production (Cloud) - Battle Hardened**

**Infrastructure:**
- **Cluster**: Managed Kubernetes with HA control plane
- **Storage**: High-performance cloud disks with backup
- **Networking**: Ingress with SSL/TLS (cert-manager or ACM)
- **Security**: Network policies, Pod Security Standards, private subnets

**Production Hardening:**

**1. High Availability**
```yaml
# Multiple replicas for all services
spec:
  replicas: 3  # Not 1!

# Pod anti-affinity (spread across nodes/AZs)
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - asmm8
      topologyKey: topology.kubernetes.io/zone
```

**2. Resource Limits (strict)**
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"  # Hard limit in production
    cpu: "500m"
```

**3. Security**
```yaml
# Run as non-root
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true

# Network policies (allow only necessary traffic)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
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
```

**4. Monitoring & Alerting**
```yaml
# Prometheus annotations
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

**Environment Comparison Table:**

| Feature | Development (Kind) | Staging (Cloud) | Production (Cloud) |
|---------|-------------------|-----------------|---------------------|
| **Cluster** | Single node | Multi-node | Multi-node HA |
| **Storage** | hostPath | Cloud dynamic | Cloud dynamic + backup |
| **External Access** | NodePort + extraPortMappings | LoadBalancer or Ingress | Ingress + SSL/TLS |
| **Replicas** | 1 | 1-2 | 3+ |
| **Resource Limits** | Relaxed | Medium | Strict |
| **Security** | Basic | RBAC + TLS | RBAC + TLS + NetPol + PSS |
| **Monitoring** | Logs only | Logs + basic metrics | Full observability stack |
| **Cost** | Free (local) | $50-200/month | $500+/month |

> **🎓 Learning**: The same Kubernetes primitives work everywhere, but configuration varies by environment. Kustomize overlays let you maintain one codebase with environment-specific overrides.

## 🔧 Advanced Patterns You Implemented

### **1. Automated ECR Authentication with CronJob**

**The Problem:**

AWS ECR (Elastic Container Registry) authentication tokens expire every **12 hours**. Without automation, you'd need to:
1. Run `aws ecr get-login-password` every 12 hours
2. Create/update Kubernetes secret manually
3. Restart deployments to use new token

This is unsustainable for development and impossible in production.

**Your Solution - The Complete Flow:**

```yaml
# CronJob that runs every 8 hours (before 12-hour expiry)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ecr-token-refresher
  namespace: cptm8-dev
spec:
  schedule: "0 */8 * * *"  # Cron syntax: minute hour day month weekday
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: ecr-token-refresher  # RBAC identity
          restartPolicy: OnFailure
          containers:
          - name: refresh-token
            image: amazon/aws-cli:latest
            env:
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: aws-ecr-credentials
                  key: aws-access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: aws-ecr-credentials
                  key: aws-secret-access-key
            - name: AWS_DEFAULT_REGION
              value: "us-east-1"
            - name: ECR_REGISTRY
              value: "123456789012.dkr.ecr.us-east-1.amazonaws.com"
            command:
            - /bin/sh
            - -c
            - |
              # Install kubectl in the container
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/

              # Get new ECR token
              TOKEN=$(aws ecr get-login-password --region $AWS_DEFAULT_REGION)

              # Create/update Kubernetes secret with new token
              kubectl create secret docker-registry ecr-registry-secret \
                --docker-server=$ECR_REGISTRY \
                --docker-username=AWS \
                --docker-password=$TOKEN \
                --namespace=cptm8-dev \
                --dry-run=client -o yaml | kubectl apply -f -

              echo "ECR token refreshed at $(date)"
```

**How It Actually Works:**

**Step 1: CronJob triggers at scheduled time**
```bash
# Kubernetes creates a Job from the CronJob template
# Job creates a Pod
# Pod runs the container with your script
```

**Step 2: Pod authenticates to AWS**
```bash
# Uses AWS credentials from Kubernetes Secret
# AWS IAM validates credentials
# Returns ECR token valid for 12 hours
```

**Step 3: Pod updates Kubernetes secret**
```bash
# Uses ServiceAccount RBAC permissions
# Creates/updates docker-registry secret
# Secret named: ecr-registry-secret
```

**Step 4: Deployments reference the secret**
```yaml
# Your deployments use this secret to pull images
spec:
  template:
    spec:
      imagePullSecrets:
      - name: ecr-registry-secret  # Auto-updated every 8 hours!
```

**First-Time Manual Trigger:**

The CronJob won't run until the first scheduled time (up to 8 hours wait). For immediate deployment:

```bash
# Manually create a Job from the CronJob
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-initial -n cptm8-dev

# Wait for it to complete
kubectl wait --for=condition=complete job/ecr-token-initial -n cptm8-dev --timeout=60s

# Verify the secret was created
kubectl get secret ecr-registry-secret -n cptm8-dev

# Now deployments can pull images!
kubectl apply -f deployments/
```

**RBAC Permissions Breakdown:**

```yaml
# ServiceAccount (identity)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ecr-token-refresher
  namespace: cptm8-dev
---
# Role (what actions are allowed)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ecr-secret-manager
  namespace: cptm8-dev
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "create", "patch", "delete"]  # Only secrets, only in cptm8-dev
  resourceNames: ["ecr-registry-secret"]  # Only this specific secret!
---
# RoleBinding (connect identity to permissions)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ecr-token-refresher-binding
  namespace: cptm8-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ecr-secret-manager
subjects:
- kind: ServiceAccount
  name: ecr-token-refresher
  namespace: cptm8-dev
```

**AWS IAM Policy (Least Privilege):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "arn:aws:ecr:us-east-1:123456789012:repository/cptm8/*"
    }
  ]
}
```

**Why this is production-ready:**
- **Automated token rotation** - runs before expiry (8 hours < 12 hour expiry)
- **Least-privilege IAM** - dedicated AWS user, only ECR pull permissions
- **Least-privilege RBAC** - only manage one specific secret in one namespace
- **Self-healing** - CronJob retries on failure (restartPolicy: OnFailure)
- **Idempotent** - `kubectl apply` safely updates existing secret
- **Logging** - View Job logs to debug issues

**Monitoring the CronJob:**

```bash
# View CronJob status
kubectl get cronjob -n cptm8-dev ecr-token-refresher

# Check last run time
kubectl get cronjob -n cptm8-dev ecr-token-refresher -o jsonpath='{.status.lastScheduleTime}'

# View Job history (Kubernetes keeps last 3 by default)
kubectl get jobs -n cptm8-dev | grep ecr-token

# Check specific Job logs
kubectl logs -n cptm8-dev job/ecr-token-refresher-28475821

# Check if secret exists and when it was updated
kubectl get secret ecr-registry-secret -n cptm8-dev -o yaml | grep creationTimestamp
```

**Debugging Issues:**

```bash
# CronJob not creating Jobs?
kubectl describe cronjob -n cptm8-dev ecr-token-refresher

# Job failed?
kubectl describe job -n cptm8-dev <job-name>
kubectl logs -n cptm8-dev job/<job-name>

# Check RBAC permissions
kubectl auth can-i create secrets --as=system:serviceaccount:cptm8-dev:ecr-token-refresher -n cptm8-dev

# AWS credentials invalid?
kubectl get secret aws-ecr-credentials -n cptm8-dev -o yaml
# Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are correct
```

> **🎓 Learning**: CronJobs enable time-based automation within Kubernetes. Combined with RBAC, they provide secure, automated maintenance tasks without external dependencies.

### **2. Health Checks Done Right**

**Your Go services implement:**
- **`/health`** - Is the service itself working? (CPU, memory, basic functionality)
- **`/ready`** - Are dependencies available? (database connections, external APIs)

**Why this matters:**
```yaml
livenessProbe:   # Uses /health - if fails, restart the pod
  httpGet:
    path: /health
readinessProbe:  # Uses /ready - if fails, remove from service traffic
  httpGet:
    path: /ready
```

> **🎓 Learning**: Kubernetes uses these endpoints to make intelligent decisions about your application health.

### **3. OpenSearch Cluster Setup - StatefulSet Mastery**

**Why OpenSearch is Complex:**

OpenSearch is a **distributed search engine** that requires:
- **Stable network identity** - nodes need to find each other by consistent hostnames
- **Persistent storage** - index data must survive pod restarts
- **Ordered startup** - cluster formation requires sequential node initialization
- **Cluster coordination** - nodes communicate to elect master, distribute data

This makes it a perfect use case for **StatefulSets**.

**Your OpenSearch StatefulSet:**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch
  namespace: cptm8-dev
spec:
  serviceName: opensearch-headless  # Required! Headless service for stable DNS
  replicas: 3  # 3-node cluster for quorum
  selector:
    matchLabels:
      app: opensearch
  template:
    metadata:
      labels:
        app: opensearch
    spec:
      # Init container: Set system parameters before OpenSearch starts
      initContainers:
      - name: init-sysctl
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          # OpenSearch requires this kernel parameter
          sysctl -w vm.max_map_count=262144
        securityContext:
          privileged: true  # Required to modify kernel parameters

      containers:
      - name: opensearch
        image: opensearchproject/opensearch:2.11.0
        env:
        - name: cluster.name
          value: "cptm8-cluster"
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name  # Pod name becomes node name
        - name: discovery.seed_hosts
          value: "opensearch-0.opensearch-headless,opensearch-1.opensearch-headless,opensearch-2.opensearch-headless"
        - name: cluster.initial_master_nodes
          value: "opensearch-0,opensearch-1,opensearch-2"
        - name: bootstrap.memory_lock
          value: "true"
        - name: OPENSEARCH_JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        volumeMounts:
        - name: data
          mountPath: /usr/share/opensearch/data
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport  # Cluster communication

  # VolumeClaimTemplates: Each pod gets its own PVC
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-storage
      resources:
        requests:
          storage: 10Gi
```

**How StatefulSet Naming Works:**

```bash
# StatefulSet creates pods with predictable names
opensearch-0  # First pod, always this name
opensearch-1  # Second pod
opensearch-2  # Third pod

# Each pod gets its own PVC
opensearch-data-opensearch-0  # PVC for pod 0
opensearch-data-opensearch-1  # PVC for pod 1
opensearch-data-opensearch-2  # PVC for pod 2
```

**Headless Service for DNS:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: opensearch-headless
  namespace: cptm8-dev
spec:
  clusterIP: None  # Headless!
  selector:
    app: opensearch
  ports:
  - port: 9200
    name: http
  - port: 9300
    name: transport
```

**This creates stable DNS names:**
```bash
# Individual pod DNS (used for cluster formation)
opensearch-0.opensearch-headless.cptm8-dev.svc.cluster.local
opensearch-1.opensearch-headless.cptm8-dev.svc.cluster.local
opensearch-2.opensearch-headless.cptm8-dev.svc.cluster.local

# Service DNS (load balanced across all pods)
opensearch-service.cptm8-dev.svc.cluster.local  # Regular ClusterIP service
```

**Ordered Startup Process:**

```bash
# StatefulSet starts pods sequentially
1. opensearch-0 starts → Running → Ready
2. opensearch-1 starts (only after 0 is Ready)
3. opensearch-2 starts (only after 1 is Ready)

# Cluster forms as nodes discover each other via DNS
opensearch-0: "I'm the first node, I'll be master"
opensearch-1: "I found opensearch-0, joining cluster"
opensearch-2: "I found opensearch-0 and opensearch-1, joining cluster"
```

**Why This Matters:**

Without ordered startup, all 3 nodes might try to be master simultaneously, causing split-brain scenarios and cluster formation failures.

**Vector Init Container - Waiting for OpenSearch:**

```yaml
# Vector deployment waits for OpenSearch cluster health
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vector
spec:
  template:
    spec:
      initContainers:
      - name: wait-for-opensearch
        image: curlimages/curl:latest
        command:
        - sh
        - -c
        - |
          until curl -s "http://opensearch-service:9200/_cluster/health" | grep -q "green\|yellow"; do
            echo "Waiting for OpenSearch cluster to be ready..."
            sleep 10
          done
          echo "OpenSearch cluster is ready!"

      containers:
      - name: vector
        image: timberio/vector:latest
        # Now Vector can safely send logs to OpenSearch
```

**Why not just port check?**
- Port 9200 opens immediately when OpenSearch starts
- But cluster might not be ready to accept data yet
- Checking `/_cluster/health` ensures cluster is **actually functional**

**Check OpenSearch Cluster Status:**

```bash
# View cluster health
kubectl exec -n cptm8-dev opensearch-0 -- curl -s http://localhost:9200/_cluster/health | jq

# Expected output:
{
  "cluster_name": "cptm8-cluster",
  "status": "green",  # green = all good, yellow = replicas missing, red = data loss
  "number_of_nodes": 3,
  "active_primary_shards": 5,
  "active_shards": 15
}

# View nodes in cluster
kubectl exec -n cptm8-dev opensearch-0 -- curl -s http://localhost:9200/_cat/nodes

# View StatefulSet status
kubectl get statefulset -n cptm8-dev opensearch

# View PVCs created by StatefulSet
kubectl get pvc -n cptm8-dev | grep opensearch
```

> **🎓 Learning**: StatefulSets provide the primitives needed for distributed systems: stable identity, persistent storage, and ordered deployment. OpenSearch showcases all of these features.

### **4. Init Containers for Smart Dependencies**

**Where you used them:**
```yaml
# Vector waits for OpenSearch cluster to be truly ready
initContainers:
- name: wait-for-opensearch
  # Checks /_cluster/health endpoint, not just port connectivity
```

**When to use init containers:**
- **External dependencies** that must be fully ready before your app starts
- **One-time setup tasks** (database migrations, file downloads, sysctl configuration)
- **Complex readiness checks** that go beyond simple port connectivity

### **4. Resource Management**

**Every deployment has:**
```yaml
resources:
  requests:    # "I need at least this much"
    memory: "128Mi" 
    cpu: "100m"
  limits:      # "Never give me more than this"
    memory: "512Mi"
    cpu: "500m"
```

**Why this prevents production disasters:**
- **Requests**: Kubernetes knows how much resource to reserve
- **Limits**: Prevents one service from starving others
- **Quality of Service**: Kubernetes prioritizes your pods appropriately

### **5. Kustomize - Deployment Orchestration**

**What is Kustomize?**

Kustomize is a **built-into-kubectl** configuration management tool that lets you customize Kubernetes YAML without templating (unlike Helm). Think "overlays" on base configurations.

**The challenge**: Complex applications need careful deployment ordering.

**Your solution:**
```yaml
# kustomization.yaml - Deploy everything in correct order
resources:
  - storage/storageclass-dev.yaml
  - configmaps/
  - services/services-dev.yaml
  - deployments/postgresql-dev.yaml
  - deployments/mongodb-dev.yaml
  - deployments/rabbitmq-dev.yaml
  - deployments/opensearch-dev.yaml
  - deployments/vector-dev.yaml
  - deployments/orchestratorm8-dev.yaml
  # ... more services
  - deployments/dashboardm8-dev.yaml
  - deployments/socketm8-dev.yaml
```

**What this gives you:**
```bash
# One command replaces 15+ manual steps
kubectl apply -k .

# Kustomize processes files in order, waits for each to be created
```

**Kustomize vs Raw YAML vs Helm:**

| Approach | Pros | Cons | Your Use Case |
|----------|------|------|---------------|
| **Raw YAML** | Simple, direct | Hard to manage multiple environments | ❌ Too many manual steps |
| **Kustomize** | Built-in, overlay-based, no templating | Less flexible than Helm | ✅ Perfect for dev/staging/prod variants |
| **Helm** | Powerful templating, package manager | Complex, learning curve | ⚠️ Overkill for your setup |

**Kustomize Features You Use:**

**1. Common Labels and Annotations**
```yaml
commonLabels:
  app: cptm8
  environment: development
  managed-by: kustomize

# Applied to ALL resources automatically!
```

**2. Namespace Management**
```yaml
namespace: cptm8-dev

# All resources deployed to this namespace
```

**3. Resource Ordering**
Kustomize applies resources in this order:
1. Namespace
2. ResourceQuota, LimitRange
3. ServiceAccount, Secret, ConfigMap
4. StorageClass, PersistentVolume, PersistentVolumeClaim
5. Deployment, StatefulSet, Job, CronJob
6. Service, Ingress

**4. Environment Overlays (Advanced)**

```bash
# Directory structure for multiple environments
.
├── base/                    # Common resources
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml   # Dev-specific overrides
│   ├── staging/
│   │   └── kustomization.yaml   # Staging overrides
│   └── prod/
│       └── kustomization.yaml   # Production overrides

# Deploy to specific environment
kubectl apply -k overlays/dev
kubectl apply -k overlays/prod
```

**Example overlay:**
```yaml
# overlays/prod/kustomization.yaml
bases:
  - ../../base

# Override just what's different in production
namespace: cptm8-prod
commonLabels:
  environment: production

# Increase replicas for production
replicas:
  - name: asmm8
    count: 3
  - name: orchestratorm8
    count: 3

# Use production secrets
secretGenerator:
  - name: postgresql-secrets
    files:
      - secrets/prod/postgresql-password.txt
```

**Why this is better than manual deployment:**
- **No more coordination headaches** - dependencies managed automatically
- **Consistent labeling** - all resources tagged with `environment: development`
- **Atomic operations** - either everything deploys or nothing does
- **Reproducible** - same order every time
- **Environment variants** - same base config, different overlays for dev/staging/prod
- **No templating complexity** - just YAML patches and overlays

**Kustomize Commands:**
```bash
# Preview what will be applied (dry-run)
kubectl kustomize .

# Apply with Kustomize
kubectl apply -k .

# Delete everything managed by Kustomize
kubectl delete -k .

# Build Kustomize output without applying
kustomize build . > output.yaml
```

> **🎓 Learning**: Kustomize lets you maintain one set of YAML and customize it per environment without copy-pasting or complex templates.

## 📁 Your Architecture Overview

```
🏗️ CPTM8 Platform on Kubernetes
├── 🗂️ Namespace: cptm8-dev (isolation)
├── 💾 Storage: StorageClass + PVCs (persistent data)
├── ⚙️ Configuration: ConfigMaps (non-sensitive) + Secrets (sensitive, SOPS encrypted)
├── 🌐 Networking: Services (stable endpoints) + Ingress (external access)
├── 🗄️ Databases: StatefulSets (PostgreSQL, MongoDB, RabbitMQ)
├── 📊 Search: OpenSearch cluster (StatefulSet)
├── 📝 Logging: Vector (Deployment with init containers)
├── 🔧 Microservices: 6 Go services (Deployments with health checks)
└── 🖥️ Frontend: DashboardM8 + SocketM8 (Deployments with external access)
```

## 🎯 What Makes Your Setup Production-Ready

✅ **Self-healing**: Kubernetes restarts failed pods automatically
✅ **Scalable**: Can easily add replicas with `kubectl scale`
✅ **Secure**: SOPS encryption, non-root containers, resource limits, least-privilege IAM
✅ **Observable**: Health endpoints, centralized logging, monitoring-ready
✅ **Resilient**: Proper dependency handling, shared storage, service discovery
✅ **Maintainable**: Clear separation of concerns, declarative configuration
✅ **Automated**: CronJob-based credential rotation eliminates manual token management  

## 🔄 Migration Path from Docker Compose

**Your Step-by-Step Migration Strategy:**

When migrating from Docker Compose to Kubernetes, you don't convert everything at once. Here's the practical, tested approach you followed:

### **Phase 1: Understand Docker Compose Concepts**

**Map Docker Compose → Kubernetes:**

| Docker Compose | Kubernetes Equivalent | Notes |
|----------------|----------------------|-------|
| `services:` | `Deployment` or `StatefulSet` | Deployment for stateless, StatefulSet for databases |
| `image:` | `spec.template.spec.containers[].image` | Same image names work |
| `ports:` | `Service` + `containerPort` | Services provide stable networking |
| `volumes:` | `PersistentVolumeClaim` | Kubernetes storage is more complex but more powerful |
| `environment:` | `ConfigMap` + `Secret` | Split non-sensitive (ConfigMap) from sensitive (Secret) |
| `depends_on:` | Init containers + readiness probes | More intelligent than simple startup order |
| `networks:` | `Namespace` + `Service` | Built-in service discovery via DNS |
| `restart: always` | `restartPolicy: Always` | Default in Kubernetes |

### **Phase 2: Migrate Stateless Services First**

**Start with your simplest Go microservices:**

**Docker Compose (before):**
```yaml
services:
  asmm8:
    image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/cptm8/asmm8:latest
    ports:
      - "8000:8000"
    environment:
      - POSTGRESQL_HOSTNAME=postgresqlm8
      - POSTGRESQL_PORT=5432
    depends_on:
      postgresqlm8:
        condition: service_healthy
    restart: always
```

**Kubernetes (after):**

**1. ConfigMap for environment variables:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: asmm8-config
  namespace: cptm8-dev
data:
  POSTGRESQL_HOSTNAME: "postgresql-service.cptm8-dev.svc.cluster.local"
  POSTGRESQL_PORT: "5432"
```

**2. Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
  namespace: cptm8-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: asmm8
  template:
    metadata:
      labels:
        app: asmm8
    spec:
      imagePullSecrets:
      - name: ecr-registry-secret  # NEW: ECR authentication
      containers:
      - name: asmm8
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/cptm8/asmm8:latest
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: asmm8-config  # Load all ConfigMap values
        env:
        - name: POSTGRESQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-secrets
              key: password
        readinessProbe:  # NEW: Replace depends_on with intelligent health checks
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
```

**3. Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: asmm8-service
  namespace: cptm8-dev
spec:
  selector:
    app: asmm8
  ports:
  - port: 8000
    targetPort: 8000
  type: ClusterIP  # Internal only
```

### **Phase 3: Migrate Stateful Services (Databases)**

**Docker Compose (before):**
```yaml
services:
  postgresqlm8:
    image: postgres:16-alpine
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgresql_root_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
```

**Kubernetes (after):**

**1. StatefulSet (not Deployment!):**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresqlm8
  namespace: cptm8-dev
spec:
  serviceName: postgresql-headless
  replicas: 1
  selector:
    matchLabels:
      app: postgresqlm8
  template:
    metadata:
      labels:
        app: postgresqlm8
    spec:
      containers:
      - name: postgresql
        image: postgres:16-alpine
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-secrets
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - pg_isready -U postgres
          initialDelaySeconds: 30
  volumeClaimTemplates:  # StatefulSet creates PVCs automatically
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-storage
      resources:
        requests:
          storage: 2Gi
```

### **Phase 4: Handle Shared Volumes**

**Docker Compose shared volume (before):**
```yaml
services:
  asmm8:
    volumes:
      - ./services/asmm8/app/log:/var/log/asmm8

  vector:
    volumes:
      - ./services/asmm8/app/log:/var/log/asmm8:ro
```

**Kubernetes PVC with ReadWriteMany (after):**

**1. Create RWX PVC:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: asmm8-logs-pvc
  namespace: cptm8-dev
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods can mount
  storageClassName: local-storage
  resources:
    requests:
      storage: 1Gi
```

**2. Mount in both pods:**
```yaml
# asmm8 deployment
volumeMounts:
- name: logs
  mountPath: /var/log/asmm8
volumes:
- name: logs
  persistentVolumeClaim:
    claimName: asmm8-logs-pvc

# vector deployment
volumeMounts:
- name: asmm8-logs
  mountPath: /var/log/asmm8
  readOnly: true
volumes:
- name: asmm8-logs
  persistentVolumeClaim:
    claimName: asmm8-logs-pvc
```

### **Phase 5: Replace `depends_on` with Init Containers**

**Docker Compose dependency (before):**
```yaml
services:
  vector:
    depends_on:
      opensearch-node1:
        condition: service_healthy
```

**Kubernetes init container (after):**
```yaml
spec:
  initContainers:
  - name: wait-for-opensearch
    image: curlimages/curl:latest
    command:
    - sh
    - -c
    - |
      until curl -s "http://opensearch-service:9200/_cluster/health" | grep -q "green\|yellow"; do
        echo "Waiting for OpenSearch..."
        sleep 10
      done
```

### **Phase 6: Organize with Kustomize**

**Before:** 50+ manual `kubectl apply` commands in specific order

**After:** Single command with proper ordering
```yaml
# kustomization.yaml
resources:
  - storage/storageclass-dev.yaml
  - configmaps/
  - services/services-dev.yaml
  - deployments/postgresql-dev.yaml
  - deployments/asmm8-dev.yaml
  # ... all resources in dependency order

# One command deployment
kubectl apply -k .
```

### **Migration Checklist:**

- ✅ **Inventory**: List all Docker Compose services, volumes, networks
- ✅ **Categorize**: Stateless vs Stateful
- ✅ **Split secrets**: Extract passwords to SOPS-encrypted Secrets
- ✅ **Create namespaces**: Organize by environment (dev, staging, prod)
- ✅ **Migrate stateless first**: Easier, fewer dependencies
- ✅ **Convert volumes**: hostPath (dev) or cloud storage (prod)
- ✅ **Replace depends_on**: Use init containers + readiness probes
- ✅ **Add health checks**: Liveness and readiness probes
- ✅ **Create Services**: For networking and service discovery
- ✅ **Test incrementally**: Deploy one service, test, then next
- ✅ **Use Kustomize**: Automate deployment orchestration

### **Common Migration Gotchas:**

| Issue | Docker Compose Behavior | Kubernetes Fix |
|-------|------------------------|----------------|
| **Service discovery** | Works via service name | Must use `service-name.namespace.svc.cluster.local` or create proper Services |
| **Restart order** | `depends_on` ensures order | Use init containers or readiness probes |
| **Shared volumes** | Just mount same host path | Need ReadWriteMany PVC (may require special StorageClass) |
| **Environment variables** | Inline in compose file | Split into ConfigMaps (non-sensitive) and Secrets (sensitive) |
| **Port conflicts** | Docker handles port mapping | Kubernetes Services handle routing, no host port conflicts |
| **Logs** | `docker-compose logs` | `kubectl logs` or centralized logging (Vector → OpenSearch) |
| **Updates** | `docker-compose up --build` | Build image, push to registry, `kubectl rollout restart` |

> **🎓 Learning**: Migration isn't about converting YAML 1:1. It's about understanding the **why** behind each Kubernetes concept and applying it appropriately.

## 🔍 Troubleshooting Philosophy - Think Like Kubernetes

**The Kubernetes Debugging Mindset:**

Unlike Docker Compose where everything is on one machine, Kubernetes is **distributed**. Debugging requires thinking in layers.

### **The Debugging Hierarchy:**

```
1. Cluster Level (Is Kubernetes working?)
   ↓
2. Namespace Level (Are resources created?)
   ↓
3. Resource Level (Is the Deployment/StatefulSet configured correctly?)
   ↓
4. Pod Level (Is the pod running?)
   ↓
5. Container Level (Is the application working?)
   ↓
6. Application Level (Are dependencies available?)
```

### **Level 1: Cluster Health**

**Check cluster basics:**
```bash
# Is kubectl connected?
kubectl cluster-info

# Are nodes healthy?
kubectl get nodes
# All should show Ready

# Is the control plane responsive?
kubectl get componentstatuses  # Deprecated but still useful

# Check system pods
kubectl get pods -n kube-system
# All should be Running
```

### **Level 2: Namespace Resources**

**Check what exists:**
```bash
# List all resources in your namespace
kubectl get all -n cptm8-dev

# Check for events (error messages)
kubectl get events -n cptm8-dev --sort-by='.lastTimestamp'
# Look for warnings or errors

# Verify RBAC
kubectl get serviceaccounts,roles,rolebindings -n cptm8-dev
```

### **Level 3: Resource Configuration**

**Inspect resource definitions:**
```bash
# View deployment details
kubectl describe deployment asmm8 -n cptm8-dev
# Look for:
# - Replicas (desired vs available)
# - Events (recent errors)
# - Conditions (Progressing, Available)

# Check if labels match selectors
kubectl get deployment asmm8 -n cptm8-dev -o yaml | grep -A5 selector
kubectl get pods -n cptm8-dev --show-labels | grep asmm8
# Labels must match!
```

### **Level 4: Pod Status**

**Understand pod states:**

| Pod Status | Meaning | Common Causes | Debug Command |
|------------|---------|---------------|---------------|
| **Pending** | Can't be scheduled | No resources, PVC not bound, node selector mismatch | `kubectl describe pod` |
| **ImagePullBackOff** | Can't pull image | Wrong image name, registry auth failure | `kubectl describe pod`, check `imagePullSecrets` |
| **CrashLoopBackOff** | Container keeps crashing | Application error, missing dependencies | `kubectl logs pod-name` |
| **Running** | Container is running | Might still have issues | Check logs and health probes |
| **Terminating** | Pod is shutting down | Delete in progress, might be stuck | `kubectl delete pod --force --grace-period=0` |

**Debug pod issues:**
```bash
# Why is pod pending?
kubectl describe pod asmm8-abc123 -n cptm8-dev | grep -A10 Events
# Look for: FailedScheduling, FailedMount, FailedAttachVolume

# Check resource requests vs available
kubectl describe node | grep -A5 "Allocated resources"

# ImagePullBackOff?
kubectl describe pod asmm8-abc123 -n cptm8-dev | grep -A10 "Failed to pull image"
# Common fixes:
# - kubectl get secret ecr-registry-secret -n cptm8-dev (exists?)
# - kubectl create job --from=cronjob/ecr-token-refresher ecr-manual -n cptm8-dev
```

### **Level 5: Container Logs**

**Read application logs:**
```bash
# Current logs
kubectl logs -f deployment/asmm8 -n cptm8-dev

# Previous crashed container
kubectl logs deployment/asmm8 -n cptm8-dev --previous

# Specific container in multi-container pod
kubectl logs pod-name -n cptm8-dev -c container-name

# Last N lines
kubectl logs deployment/asmm8 -n cptm8-dev --tail=50

# Logs with timestamps
kubectl logs deployment/asmm8 -n cptm8-dev --timestamps
```

### **Level 6: Application Dependencies**

**Test connectivity from inside the pod:**
```bash
# Shell into running pod
kubectl exec -it deployment/asmm8 -n cptm8-dev -- /bin/sh

# Test database connection
nc -zv postgresql-service 5432
# Or
telnet postgresql-service 5432

# Test HTTP endpoints
curl -v http://postgresql-service:5432
curl -v http://opensearch-service:9200/_cluster/health

# Check DNS resolution
nslookup postgresql-service
nslookup postgresql-service.cptm8-dev.svc.cluster.local

# View environment variables
env | grep POSTGRESQL
```

### **Common Debugging Scenarios:**

**Scenario 1: Service has no endpoints**
```bash
# Symptom: Requests to service fail
kubectl get endpoints asmm8-service -n cptm8-dev
# Shows no endpoints

# Cause: Label mismatch
kubectl get svc asmm8-service -n cptm8-dev -o yaml | grep selector -A3
kubectl get pods -n cptm8-dev -l app=asmm8 --show-labels

# Fix: Update labels to match
```

**Scenario 2: PVC stuck in Pending**
```bash
# Symptom: Pod pending, waiting for volume
kubectl get pvc -n cptm8-dev

# Causes:
# 1. No PV matches the claim
kubectl get pv | grep Available
# 2. StorageClass doesn't exist
kubectl get storageclass
# 3. Access mode mismatch (RWX required but only RWO available)

# Fix: Create matching PV or fix StorageClass
```

**Scenario 3: Init container failing**
```bash
# Symptom: Pod stuck in Init:Error or Init:CrashLoopBackOff
kubectl describe pod vector-abc123 -n cptm8-dev

# View init container logs
kubectl logs vector-abc123 -n cptm8-dev -c wait-for-opensearch

# Common fix: Dependency not ready yet
kubectl get pods -n cptm8-dev | grep opensearch
```

**Scenario 4: Readiness probe failing**
```bash
# Symptom: Pod Running but not receiving traffic
kubectl get pods -n cptm8-dev
# Shows 0/1 READY

# Check probe configuration
kubectl describe pod asmm8-abc123 -n cptm8-dev | grep -A10 "Readiness"

# Test probe endpoint manually
kubectl exec asmm8-abc123 -n cptm8-dev -- curl -f http://localhost:8000/ready

# If returns error, fix application
# If returns success, check probe configuration (path, port, delay)
```

### **Power Debugging Commands:**

```bash
# Watch resources update in real-time
kubectl get pods -n cptm8-dev -w

# Get all pod logs simultaneously
kubectl logs -n cptm8-dev -l tier=application --all-containers=true

# Port forward for local testing
kubectl port-forward -n cptm8-dev deployment/asmm8 8000:8000
# Access via localhost:8000

# Copy files from pod for analysis
kubectl cp cptm8-dev/asmm8-abc123:/var/log/app.log ./app.log

# Run one-off debugging pod
kubectl run debug --image=busybox --rm -it -n cptm8-dev -- sh
# Test networking from inside cluster

# View resource usage
kubectl top pods -n cptm8-dev
kubectl top nodes
```

### **The "5 Whys" Debugging Approach:**

**Example: Pod not starting**

1. **Why is the pod failing?** → ImagePullBackOff
2. **Why can't it pull the image?** → Authentication failure
3. **Why is authentication failing?** → ecr-registry-secret doesn't exist
4. **Why doesn't the secret exist?** → CronJob hasn't run yet
5. **Why hasn't the CronJob run?** → First scheduled run is in 6 hours

**Solution:** Manually trigger the CronJob job
```bash
kubectl create job --from=cronjob/ecr-token-refresher ecr-initial -n cptm8-dev
```

> **🎓 Learning**: Kubernetes errors often have cascading causes. Start at the symptom (pod status) and work backwards through dependencies until you find the root cause.

## 🚀 Advanced Learning Opportunities

### **When You're Ready for More:**

1. **Horizontal Pod Autoscaling (HPA)**
   ```bash
   kubectl autoscale deployment asmm8 --cpu-percent=50 --min=1 --max=10
   ```

2. **Network Policies** (micro-segmentation)
   ```yaml
   # Only allow frontend to talk to backend services
   spec:
     policyTypes: ["Ingress", "Egress"]
   ```

3. **Monitoring Stack** (Prometheus + Grafana)
   - Collect metrics from your `/health` endpoints
   - Set up alerts for service failures

4. **GitOps Deployment** (ArgoCD)
   - Automatically deploy when you push to git
   - Declarative deployment pipeline

## 🎉 Your Learning Achievement

**You've mastered:**
- **Core Kubernetes concepts** through hands-on migration
- **Production patterns** that most teams take months to learn
- **Security best practices** with encrypted secret management and least-privilege IAM
- **Advanced networking** with service discovery and ingress
- **StatefulSet architecture** including the two-service pattern (headless + regular ClusterIP)
- **Data persistence** with PersistentVolumes and understanding what survives restarts
- **Operational excellence** with health checks and resource management
- **Automation patterns** with CronJobs for credential rotation and maintenance tasks

**Specifically, you now understand:**
- ✅ **Why StatefulSets need TWO services** (headless for pod identity, regular for app access)
- ✅ **When to use headless service DNS** (clustering, peer discovery) vs regular service (application connections)
- ✅ **How data persistence works** in RabbitMQ/PostgreSQL/MongoDB with StatefulSets
- ✅ **What survives restarts** (durable queues/messages) vs what doesn't (consumers/connections)
- ✅ **Common pitfalls** like using headless services for app connections or missing `clusterIP: None`
- ✅ **Live configuration updates** using the emptyDir + ConfigMap pattern for development flexibility
- ✅ **ConfigMap writability limitations** and how to work around them with init containers
- ✅ **subPath mounts** to overlay specific files without hiding Docker image content (wordlists)

> **🏆 Congratulations!** You've successfully learned Kubernetes by migrating a real, complex microservices platform. This knowledge directly applies to production environments and gives you a solid foundation for advanced Kubernetes topics.

## 📚 Documentation References

- **Practical deployment**: See **DEPLOYMENT-GUIDE.md**
- **Frontend access**: See **FRONTEND-EXPOSURE-GUIDE.md**
- **Kubernetes concepts**: This guide (k8s-migration-guide.md)