# CPTM8 Kubernetes Architecture Documentation

**Date:** November 19, 2025
**Last Updated:** November 19, 2025
**Version:** 1.0

## Overview

CPTM8 (Continuous Penetration Testing Mate) is a cloud-native, microservices-based platform for automated security testing and attack surface management. The platform is deployed on Kubernetes using a declarative, GitOps-driven approach with Kustomize for configuration management across multiple environments.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              External Access Layer                           │
│                                                                               │
│  ┌──────────────────┐         ┌──────────────────┐                          │
│  │  DNS/Route53     │────────▶│  NGINX Ingress   │                          │
│  │  TLS Termination │         │  Controller      │                          │
│  └──────────────────┘         └──────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Frontend/WebSocket Layer                          │
│                                                                               │
│  ┌──────────────────┐         ┌──────────────────┐                          │
│  │  DashboardM8     │         │  SocketM8        │                          │
│  │  (React/Next.js) │◀───────▶│  (WebSocket)     │                          │
│  │  Port: 3000      │         │  Port: 4000      │                          │
│  └──────────────────┘         └──────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Application/API Layer                               │
│                                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   ASMM8      │  │   NAABUM8    │  │  KATANAM8    │  │    NUM8      │   │
│  │  (Asset Mgmt)│  │  (Notif/     │  │  (Vuln Scan) │  │  (Enum)      │   │
│  │  Port: 8000  │  │   Aggr)      │  │  Port: 8002  │  │  Port: 8003  │   │
│  └──────────────┘  │  Port: 8001  │  └──────────────┘  └──────────────┘   │
│                    └──────────────┘                                          │
│                                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                      │
│  │ OrchestratorM8│  │ ReportingM8  │  │  Additional  │                      │
│  │  (Workflow)   │  │  (Reports)   │  │  Services    │                      │
│  │  Port: 8004   │  │  Port: 8005  │  │              │                      │
│  └──────────────┘  └──────────────┘  └──────────────┘                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Messaging/Queue Layer                              │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────┐            │
│  │                    RabbitMQ Cluster                          │            │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │            │
│  │  │  rabbitmq-0  │  │  rabbitmq-1  │  │  rabbitmq-2  │      │            │
│  │  │  (Primary)   │◀─┤  (Replica)   │◀─┤  (Replica)   │      │            │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │            │
│  │                                                              │            │
│  │  Exchanges: cptm8 (topic), notification (topic)             │            │
│  │  Queues: qasmm8, qnaabum8, qkatanam8, qnum8                │            │
│  │  Ports: 5672 (AMQP), 15672 (Management)                    │            │
│  └─────────────────────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Data Layer                                      │
│                                                                               │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │  PostgreSQL      │  │  MongoDB         │  │  OpenSearch      │          │
│  │  (Relational)    │  │  (Document)      │  │  (Search/Logs)   │          │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │          │
│  │  │postgres-0  │  │  │  │ mongodb-0  │  │  │  │opensearch-0│  │          │
│  │  │(Primary)   │  │  │  │(Primary)   │  │  │  │(Data Node) │  │          │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │          │
│  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │          │
│  │  │postgres-1  │  │  │  │ mongodb-1  │  │  │  │opensearch-1│  │          │
│  │  │(Standby)   │  │  │  │(Secondary) │  │  │  │(Data Node) │  │          │
│  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │          │
│  │                  │  │  ┌────────────┐  │  │  ┌────────────┐  │          │
│  │  Port: 5432      │  │  │ mongodb-2  │  │  │  │opensearch-2│  │          │
│  │  Schema: cptm8   │  │  │(Arbiter)   │  │  │  │(Data Node) │  │          │
│  │                  │  │  └────────────┘  │  │  └────────────┘  │          │
│  │                  │  │                  │  │                  │          │
│  │                  │  │  Port: 27017     │  │  Port: 9200      │          │
│  │                  │  │  Replica Set:    │  │  HTTP API        │          │
│  │                  │  │  rs0             │  │                  │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Observability Layer                                 │
│                                                                               │
│  ┌──────────────────┐         ┌──────────────────┐                          │
│  │  Vector          │────────▶│  OpenSearch      │                          │
│  │  (Log Collector) │         │  (Log Storage)   │                          │
│  │  DaemonSet       │         │                  │                          │
│  └──────────────────┘         └──────────────────┘                          │
│                                                                               │
│  ┌──────────────────┐         ┌──────────────────┐                          │
│  │  Prometheus      │         │  Grafana         │                          │
│  │  (Metrics)       │◀───────▶│  (Dashboards)    │                          │
│  │  Port: 9090      │         │  Port: 3010      │                          │
│  └──────────────────┘         └──────────────────┘                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Ingress Layer (`bases/ingress/`)

**Purpose:** External traffic routing and TLS termination
**Technology:** NGINX Ingress Controller
**Pattern:** Reverse proxy with path-based routing

**Key Components:**
- `ingress-nginx/` (117 lines) - NGINX controller deployment
- `ingress.yaml` (58 lines) - Ingress rules for all services

**Routing Configuration:**
```yaml
# Example routing rules
- host: cptm8.securetivity.com
  paths:
    - path: /api/asmm8
      backend: asmm8-service:8000
    - path: /api/naabum8
      backend: naabum8-service:8001
    - path: /socket
      backend: socketm8-service:4000
    - path: /
      backend: dashboardm8-service:3000
```

**TLS Configuration:**
- Cert-manager integration for automated certificate management
- Let's Encrypt ACME protocol support
- Certificate renewal automation (90-day certificates)

**Code Size:** 175 lines total

### 2. Frontend Layer

#### DashboardM8 (`bases/dashboardm8/`)
**Purpose:** Web-based user interface
**Technology:** React/Next.js
**Pattern:** Single Page Application (SPA)

**Key Files:**
- `deployment.yaml` (50 lines) - Frontend deployment
- `service.yaml` (14 lines) - ClusterIP service
- `configmap.yaml` - API endpoint configuration

**Features:**
- Real-time scanning dashboard
- Domain and hostname management
- Scan history and reporting
- User authentication interface

**Port:** 3000 (HTTP)
**Replicas:** 2 (staging), 3 (production)

#### SocketM8 (`bases/socketm8/`)
**Purpose:** Real-time WebSocket communication
**Technology:** Go WebSocket server
**Pattern:** Publisher-Subscriber with connection pooling

**Key Files:**
- `deployment.yaml` (50 lines) - WebSocket server
- `service.yaml` (14 lines) - ClusterIP service
- `configmap.yaml` - RabbitMQ and database configuration

**Features:**
- Real-time scan progress updates
- Live notification delivery
- Connection state management
- Message acknowledgment

**Port:** 4000 (WebSocket)
**Replicas:** 2 (staging), 3 (production)

### 3. Application Layer (Go Microservices)

#### ASMM8 (`bases/asmm8/`)
**Purpose:** Attack Surface Management and subdomain enumeration
**Technology:** Go 1.21.5, Gin Web Framework
**Pattern:** RESTful API with RabbitMQ message queue integration

**Key Components:**
- `deployment.yaml` (77 lines) - Main deployment with init containers
- `service.yaml` (14 lines) - ClusterIP service
- `configmap.yaml` (25 lines) - Application configuration
- `secrets/` - Database and RabbitMQ credentials (SOPS encrypted)

**Scanning Workflow:**
```
API Request → Domain Validation → RabbitMQ Queue Check → Tool Installation
                                                              ↓
External Tools (subfinder, dnsx, alterx) → Result Processing → Database Storage
                                                              ↓
                                                    RabbitMQ Notification
```

**External Tools:**
- subfinder v2.9.0 - Passive subdomain enumeration
- dnsx v1.2.2 - DNS resolution and brute-forcing
- alterx v0.0.6 - DNS alteration/permutation generation
- httpx - HTTP probing

**API Endpoints:**
- POST `/api/asmm8/scan` - Launch full scan
- POST `/api/asmm8/scan/passive` - Passive enumeration only
- POST `/api/asmm8/scan/active` - Active enumeration only
- GET `/api/asmm8/domains` - List all domains
- POST `/api/asmm8/domains` - Create new domain
- GET `/api/asmm8/hostnames` - List discovered hostnames

**Port:** 8000
**Replicas:** 2 (staging), 3 (production)
**Init Containers:** Tool installation (subfinder, dnsx, alterx)

#### NAABUM8 (`bases/naabum8/`)
**Purpose:** Notification aggregation and distribution
**Technology:** Go with RabbitMQ consumer
**Pattern:** Event-driven message processor

**Key Components:**
- `deployment.yaml` (70 lines) - Consumer deployment
- `service.yaml` (14 lines) - ClusterIP service
- `configmap.yaml` - RabbitMQ configuration

**Features:**
- Scan completion notifications
- Error alerting
- Multi-channel distribution (email, webhook, Slack)
- Notification templating

**RabbitMQ Integration:**
- Consumer: cnaabum8
- Queue: qnaabum8
- Exchange: notification (topic)
- Routing Key: `cptm8.notification.#`

**Port:** 8001
**Replicas:** 2 (staging), 3 (production)

#### KATANAM8 (`bases/katanam8/`)
**Purpose:** Vulnerability scanning and assessment
**Technology:** Go with external security tools
**Pattern:** Pipeline processing with result aggregation

**Key Components:**
- `deployment.yaml` (60 lines) - Scanner deployment
- `service.yaml` (14 lines) - ClusterIP service
- `configmap.yaml` - Scanner configuration

**Scanning Tools:**
- nuclei - Vulnerability detection
- nmap - Port scanning
- SSL/TLS analysis tools

**Port:** 8002
**Replicas:** 1 (staging), 2 (production)

#### NUM8 (`bases/num8/`)
**Purpose:** Network enumeration and reconnaissance
**Technology:** Go with network scanning tools
**Pattern:** Concurrent network probing

**Port:** 8003
**Replicas:** 1 (staging), 2 (production)

#### OrchestratorM8 (`bases/orchestratorm8/`)
**Purpose:** Workflow orchestration and task scheduling
**Technology:** Go with RabbitMQ integration
**Pattern:** Workflow engine with state machine

**Features:**
- Multi-stage scan orchestration
- Task dependencies management
- Retry logic with exponential backoff
- Workflow state persistence

**Port:** 8004
**Replicas:** 1 (staging), 2 (production)

#### ReportingM8 (`bases/reportingm8/`)
**Purpose:** Report generation and export
**Technology:** Go with PDF/HTML/JSON export
**Pattern:** Template-based report generation

**Features:**
- Customizable report templates
- Multi-format export (PDF, HTML, JSON, CSV)
- Scheduled report generation
- Report archival

**Port:** 8005
**Replicas:** 1 (staging), 2 (production)

### 4. Data Layer

#### PostgreSQL (`bases/postgres/`)
**Purpose:** Relational data storage for domains, hostnames, scans
**Technology:** PostgreSQL 14
**Pattern:** StatefulSet with persistent volumes

**Key Components:**
- `statefulset.yaml` (96 lines) - PostgreSQL cluster
- `service.yaml` (14 lines) - Headless service
- `configmap.yaml` (20 lines) - Database configuration
- `pvc.yaml` (16 lines) - Persistent volume claims

**Database Schema:**
```sql
-- Core tables
cptm8domain (id, name, companyname, enabled, created_at)
cptm8hostname (id, domain_id, hostname, source, discovered_at)
cptm8scan (id, domain_id, scan_type, status, started_at, completed_at)
cptm8vulnerability (id, hostname_id, severity, title, description)
```

**High Availability:**
- Streaming replication (primary-standby)
- Automatic failover with pg_auto_failover
- Point-in-time recovery (PITR)
- Daily automated backups to S3

**Storage:**
- Volume Size: 10Gi (dev), 50Gi (staging), 100Gi (production)
- Storage Class: gp3 (AWS), standard-rwo (GCP)
- Backup Retention: 7 days (staging), 30 days (production)

**Port:** 5432
**Replicas:** 1 (dev), 2 (staging/production)

#### MongoDB (`bases/mongodb/`)
**Purpose:** Document storage for scan results and logs
**Technology:** MongoDB 6.0
**Pattern:** StatefulSet with replica set configuration

**Key Components:**
- `statefulset.yaml` (115 lines) - MongoDB replica set
- `service.yaml` (14 lines) - Headless service
- `configmap.yaml` (25 lines) - Replica set configuration
- `pvc.yaml` (16 lines) - Persistent volume claims

**Collections:**
```javascript
// Scan results with nested structure
scan_results {
  _id, domain, scan_type, timestamp,
  results: {
    hostnames: [],
    vulnerabilities: [],
    metadata: {}
  }
}

// Audit logs
audit_logs {
  _id, timestamp, user, action, resource, details
}
```

**Replica Set Configuration:**
- Replica Set Name: rs0
- Members: 3 (1 primary, 2 secondaries)
- Read Preference: primaryPreferred
- Write Concern: majority

**Storage:**
- Volume Size: 10Gi (dev), 50Gi (staging), 100Gi (production)
- Backup: Daily snapshots to S3

**Port:** 27017
**Replicas:** 3 (staging/production), 1 (dev)

#### RabbitMQ (`bases/rabbitmq/`)
**Purpose:** Message queue for inter-service communication
**Technology:** RabbitMQ 3.12 with management plugin
**Pattern:** StatefulSet with cluster configuration

**Key Components:**
- `statefulset.yaml` (128 lines) - RabbitMQ cluster
- `service.yaml` (22 lines) - Headless + management service
- `configmap.yaml` (35 lines) - Cluster and queue configuration
- `secrets/` - Admin credentials (SOPS encrypted)

**Cluster Configuration:**
```yaml
# RabbitMQ cluster settings
cluster_formation.peer_discovery_backend = kubernetes
cluster_formation.k8s.host = kubernetes.default.svc.cluster.local
cluster_formation.k8s.address_type = hostname
cluster_partition_handling = autoheal
```

**Exchange Configuration:**
```yaml
Exchanges:
  cptm8:
    type: topic
    durable: true

  notification:
    type: topic
    durable: true
```

**Queue Configuration:**
```yaml
qasmm8:
  exchange: cptm8
  routing_key: "cptm8.asmm8.#"
  max_length: 1
  overflow: reject-publish
  consumer: casmm8

qnaabum8:
  exchange: notification
  routing_key: "cptm8.notification.#"
  consumer: cnaabum8
```

**Advanced Features:**
- Manual acknowledgment mode with delivery tag tracking
- Connection pooling (2-10 connections)
- Automatic connection recovery
- Periodic health checks (30 min)
- Consumer auto-recovery with lifecycle management
- Smart ACK/NACK logic with requeue on failures

**Message Flow:**
```
Producer (ASMM8) → Exchange (cptm8) → Routing Key (cptm8.asmm8.scan)
                                            ↓
                                    Queue (qasmm8)
                                            ↓
                        Consumer (NAABUM8) → deliveryTag extraction
                                            ↓
                        Processing → ACK/NACK based on completion status
```

**Ports:**
- 5672 (AMQP)
- 15672 (Management UI)

**Replicas:** 3 (staging/production), 1 (dev)

**Storage:**
- Volume Size: 5Gi (dev), 20Gi (staging/production)

#### OpenSearch (`bases/opensearch/`)
**Purpose:** Log aggregation, search, and analytics
**Technology:** OpenSearch 2.11 (Elasticsearch fork)
**Pattern:** StatefulSet with data node cluster

**Key Components:**
- `statefulset.yaml` (110 lines) - OpenSearch cluster
- `service.yaml` (20 lines) - Headless + API service
- `configmap.yaml` (30 lines) - Cluster configuration
- `pvc.yaml` (16 lines) - Persistent volume claims

**Cluster Configuration:**
- Cluster Name: cptm8-logs
- Discovery Type: kubernetes
- Minimum Master Nodes: 2

**Indices:**
```
cptm8-logs-*         # Application logs
cptm8-audit-*        # Audit logs
cptm8-metrics-*      # Metrics data
cptm8-scan-results-* # Scan results for analytics
```

**Index Lifecycle Management:**
- Hot phase: 7 days (high-performance storage)
- Warm phase: 30 days (standard storage)
- Delete phase: 90 days

**Port:** 9200 (HTTP), 9300 (Transport)
**Replicas:** 3 (staging/production), 1 (dev)

**Storage:**
- Volume Size: 10Gi (dev), 100Gi (staging), 500Gi (production)

### 5. Observability Layer

#### Vector (`bases/vector/`)
**Purpose:** Log collection and forwarding
**Technology:** Vector.dev
**Pattern:** DaemonSet with sidecar injection

**Key Components:**
- `daemonset.yaml` (85 lines) - Log collector
- `configmap.yaml` (45 lines) - Vector configuration

**Log Pipeline:**
```
Container Logs → Vector DaemonSet → Parse/Transform → OpenSearch
                      ↓
                 Filter/Enrich
                      ↓
              Add Kubernetes metadata
```

**Vector Configuration:**
```toml
[sources.kubernetes_logs]
type = "kubernetes_logs"

[transforms.parse_json]
type = "remap"
source = '''
  . |= parse_json!(.message)
  .kubernetes = del(.kubernetes)
'''

[sinks.opensearch]
type = "elasticsearch"
endpoint = "http://opensearch:9200"
index = "cptm8-logs-%Y.%m.%d"
```

**Features:**
- Automatic log parsing
- Kubernetes metadata enrichment
- Multi-destination routing
- Buffer management for reliability

**Deployment:** DaemonSet (1 pod per node)

### 6. Configuration Management

#### Kustomize Structure
```
overlays/
├── dev/
│   ├── kustomization.yaml           # Dev-specific patches
│   ├── namespace.yaml               # cptm8-dev namespace
│   ├── replica-patches/             # 1 replica for all services
│   └── resource-patches/            # Minimal resource requests
│
├── staging/
│   ├── kustomization.yaml           # Staging patches
│   ├── namespace.yaml               # cptm8-staging namespace
│   ├── replica-patches/             # 2-3 replicas
│   ├── resource-patches/            # Moderate resources
│   └── ingress-patches/             # staging.cptm8.securetivity.com
│
└── prod/
    ├── kustomization.yaml           # Production patches
    ├── namespace.yaml               # cptm8-prod namespace
    ├── replica-patches/             # 3+ replicas with HPA
    ├── resource-patches/            # Production resources
    ├── ingress-patches/             # cptm8.securetivity.com
    └── security-patches/            # Pod Security Policies
```

**Kustomization Layering:**
```yaml
# overlays/staging/kustomization.yaml
bases:
  - ../../bases/postgres
  - ../../bases/mongodb
  - ../../bases/rabbitmq
  - ../../bases/opensearch
  - ../../bases/asmm8
  - ../../bases/naabum8
  # ... other services

patchesStrategicMerge:
  - replica-patches/asmm8-replicas.yaml
  - resource-patches/postgres-resources.yaml
  - ingress-patches/ingress.yaml

namespace: cptm8-staging
```

#### Environment-Specific Configuration Matrix

| Component | Dev (Kind) | Staging (AWS/GCP) | Production (AWS/GCP) |
|-----------|-----------|-------------------|---------------------|
| **Replicas** | 1 | 2 | 3+ (HPA) |
| **Resources** | Minimal | Moderate | Full |
| **Storage** | 10Gi | 50Gi | 100Gi+ |
| **Ingress** | localhost | staging.cptm8.securetivity.com | cptm8.securetivity.com |
| **TLS** | Self-signed | Let's Encrypt Staging | Let's Encrypt Production |
| **Monitoring** | Basic logs | Prometheus + Grafana | Full observability stack |
| **Backups** | None | Daily | Daily + PITR |
| **High Availability** | No | Partial | Full (multi-AZ) |

### 7. Security Architecture

#### Network Policies (`security/network-policies/`)
**Purpose:** Network segmentation and traffic control
**Pattern:** Zero-trust network model

**Policy Structure:**
```yaml
# Default deny all ingress/egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

# Allow specific service-to-service communication
- ASMM8 → PostgreSQL (port 5432)
- ASMM8 → RabbitMQ (port 5672)
- NAABUM8 → RabbitMQ (port 5672)
- All services → DNS (port 53)
```

**Network Policies:**
- `default-deny.yaml` - Deny all traffic by default
- `allow-postgres.yaml` - Allow database access from specific services
- `allow-rabbitmq.yaml` - Allow message queue access
- `allow-dns.yaml` - Allow DNS resolution
- `allow-ingress.yaml` - Allow traffic from ingress controller

#### Pod Security Standards
**Pattern:** Restricted pod security with least privilege

**Security Context:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

#### RBAC Configuration (`security/rbac/`)
**Purpose:** Role-based access control for services and users

**Service Accounts:**
- `asmm8-sa` - ASMM8 service account
- `vector-sa` - Log collector service account
- `cert-manager-sa` - Certificate management

**Roles and Bindings:**
```yaml
# Service-specific role
kind: Role
metadata:
  name: asmm8-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

#### Secrets Management
**Pattern:** SOPS encryption with age/GPG keys

**Encrypted Secrets:**
- Database credentials
- RabbitMQ credentials
- API keys for external services
- TLS certificates (private keys)

**SOPS Configuration:**
```yaml
# .sops.yaml
creation_rules:
  - path_regex: overlays/.*/secrets/.*\.yaml
    encrypted_regex: ^(data|stringData)$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Data Flow Architecture

### 1. Scan Initiation Flow
```
User Request (DashboardM8) → SocketM8 (WebSocket) → ASMM8 API
                                                        ↓
                            Domain Validation → Database Check → Tool Installation
                                                        ↓
            RabbitMQ Queue Check → Publish Message → Queue (qasmm8)
                                                        ↓
                        OrchestratorM8 Consumer → Acknowledge delivery
                                                        ↓
            Passive Scan (subfinder) → Temporary Results → Active Scan (dnsx, alterx)
                                                        ↓
                        Result Processing → Database Storage (PostgreSQL + MongoDB)
                                                        ↓
            RabbitMQ Publish (notification exchange) → NAABUM8 Consumer
                                                        ↓
                SocketM8 Notification → DashboardM8 Update → User Notification
```

### 2. Message Queue Flow (with Manual Acknowledgment)
```
ASMM8 Scan Complete → RabbitMQ Exchange (cptm8)
                            ↓
                Routing Key: cptm8.asmm8.scan.complete
                            ↓
                    Queue (qasmm8) → deliveryTag: 123
                            ↓
        Consumer (NAABUM8) → Extract deliveryTag → HTTP Request
                            ↓
                X-RabbitMQ-Delivery-Tag: 123 header
                            ↓
        Controller extracts tag → Process scan results
                            ↓
            ┌──────────────┴──────────────┐
            │                             │
    Scan Completes Successfully   Scan Fails (crash/SIGTERM)
            │                             │
        ACK (tag: 123)               NACK + requeue (tag: 123)
            │                             │
    Remove from queue               Return to queue for retry
            ↓
    Publish to notification exchange
            ↓
        NAABUM8 processes notification
```

### 3. Log Aggregation Flow
```
Application Logs (stdout/stderr) → Container Runtime
                                        ↓
            Vector DaemonSet (reads /var/log/pods/*) → Parse JSON logs
                                        ↓
                    Add Kubernetes metadata (namespace, pod, labels)
                                        ↓
                    Transform/Enrich → Filter sensitive data
                                        ↓
                OpenSearch → Index (cptm8-logs-2025.11.19)
                                        ↓
                Grafana Dashboard → Real-time log viewing
```

### 4. Monitoring and Metrics Flow
```
Application Metrics (/metrics endpoint) → Prometheus Scraper
                                              ↓
                        Time-series Database → PromQL queries
                                              ↓
                        Grafana Dashboard → Visualization
                                              ↓
                    Alertmanager → Slack/Email notifications
```

## Deployment Architecture

### 1. Local Development (Kind Cluster)
```bash
# Create Kind cluster with port mappings
kind create cluster --name cptm8-dev --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000  # DashboardM8
    hostPort: 3000
  - containerPort: 30001  # SocketM8
    hostPort: 4000
  - containerPort: 30002  # ASMM8
    hostPort: 8000
EOF

# Deploy to dev environment
kubectl apply -k overlays/dev/

# Access services
- DashboardM8: http://localhost:3000
- SocketM8: ws://localhost:4000
- ASMM8 API: http://localhost:8000
```

### 2. Staging Deployment (Cloud)
```bash
# AWS EKS cluster
eksctl create cluster \
  --name cptm8-staging \
  --region eu-south-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5

# Deploy to staging
kubectl apply -k overlays/staging/

# Ingress endpoint
- https://staging.cptm8.securetivity.com
```

### 3. Production Deployment (Cloud with HA)
```bash
# Multi-AZ EKS cluster
eksctl create cluster \
  --name cptm8-prod \
  --region eu-south-2 \
  --nodegroup-name prod-workers \
  --node-type t3.large \
  --nodes 6 \
  --nodes-min 3 \
  --nodes-max 10 \
  --zones eu-south-2a,eu-south-2b,eu-south-2c

# Deploy to production
kubectl apply -k overlays/prod/

# Ingress endpoint
- https://cptm8.securetivity.com
```

### 4. CI/CD Pipeline Architecture
```
GitHub Push → GitHub Actions Workflow
                    ↓
        ┌───────────┴───────────┐
        │                       │
    Build Stage           Test Stage
        │                       │
    Docker Build          Unit Tests
        │                       │
    Image Push            Integration Tests
    (ECR/GCR)                  │
        │                  Security Scan
        └───────────┬───────────┘
                    ↓
            Deploy Stage (staging)
                    ↓
        Smoke Tests → Health Checks
                    ↓
            Manual Approval (production)
                    ↓
            Deploy Stage (production)
                    ↓
        Blue-Green Deployment → Traffic Shift
```

## Scalability Architecture

### 1. Horizontal Pod Autoscaler (HPA)
```yaml
# Production HPA configuration
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
```

### 2. Vertical Scaling Strategy
**Resource Allocation Pattern:**
```yaml
# Development
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Staging
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

# Production
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

### 3. Database Scaling
**PostgreSQL:**
- Vertical scaling via resource increases
- Horizontal read scaling via read replicas
- Connection pooling (PgBouncer)
- Sharding for large datasets (future)

**MongoDB:**
- Replica set with automatic failover
- Sharding for horizontal scaling
- Read preference: primaryPreferred

**RabbitMQ:**
- Cluster with 3 nodes (quorum queues)
- Lazy queues for memory optimization
- Message TTL and dead-letter exchanges

## Error Handling Architecture

### 1. Error Categories
**System Errors:**
- Database connection failures → Retry with exponential backoff
- RabbitMQ connection failures → Auto-recovery with connection pooling
- External tool failures → Fallback to alternative tools

**Business Errors:**
- Invalid domain input → Return 400 Bad Request
- Domain not in scope → Return 403 Forbidden
- Duplicate domain → Return 409 Conflict

**External Errors:**
- External API rate limits → Implement backoff and retry
- DNS resolution failures → Log and continue
- Network timeouts → Configurable timeout with retry

### 2. Retry Logic
```go
// Exponential backoff configuration
type RetryConfig struct {
    MaxAttempts: 3
    InitialDelay: 2 * time.Second
    MaxDelay: 30 * time.Second
    Multiplier: 2.0
}

// Database connection retry (10 attempts, 5s intervals)
func OpenConnectionWithRetry() (*sql.DB, error) {
    var db *sql.DB
    var err error

    for i := 0; i < 10; i++ {
        db, err = sql.Open("postgres", connectionString)
        if err == nil {
            return db, nil
        }
        log.Warn().Msgf("Database connection attempt %d failed, retrying in 5s", i+1)
        time.Sleep(5 * time.Second)
    }
    return nil, err
}
```

### 3. Circuit Breaker Pattern (Recommended)
```go
// Circuit breaker for external services
type CircuitBreaker struct {
    State: "closed" | "open" | "half-open"
    FailureThreshold: 5
    SuccessThreshold: 2
    Timeout: 60 * time.Second
}
```

## Design Patterns Used

### 1. Kubernetes Patterns
- **Sidecar Pattern:** Vector logging sidecar for observability
- **Ambassador Pattern:** NGINX ingress as reverse proxy
- **Init Container Pattern:** Tool installation before main container starts
- **StatefulSet Pattern:** Databases with persistent identity
- **DaemonSet Pattern:** Vector log collector on every node

### 2. Microservices Patterns
- **API Gateway:** NGINX Ingress as API gateway
- **Event-Driven:** RabbitMQ message queue for async communication
- **CQRS:** Separate read (MongoDB) and write (PostgreSQL) models
- **Service Discovery:** Kubernetes DNS for service resolution
- **Health Check:** Liveness and readiness probes

### 3. Operational Patterns
- **GitOps:** Declarative configuration with Kustomize
- **Infrastructure as Code:** All resources defined in YAML
- **Immutable Infrastructure:** Container images with version tags
- **Blue-Green Deployment:** Zero-downtime updates
- **Canary Deployment:** Gradual rollout with traffic shifting

## Architecture Best Practices

### 1. Followed Practices
✅ Declarative configuration with Kustomize
✅ Separation of concerns (data, app, frontend layers)
✅ Microservices architecture with clear boundaries
✅ Stateless application design (state in databases)
✅ Container orchestration with Kubernetes
✅ Infrastructure as Code
✅ Service mesh ready (Istio/Linkerd compatible)
✅ Observability with logging, metrics, tracing
✅ CI/CD automation with GitHub Actions
✅ Multi-environment support (dev/staging/prod)

### 2. Areas for Improvement
⚠️ Secrets management (currently using SOPS, consider Vault)
⚠️ Service mesh implementation (Istio/Linkerd not yet deployed)
⚠️ Advanced monitoring (distributed tracing with Jaeger)
⚠️ Cost optimization (pod rightsizing, spot instances)
⚠️ Disaster recovery automation
⚠️ Multi-region deployment for global availability
⚠️ Advanced security scanning (OPA policies, Falco runtime security)

### 3. Recommended Additions
🔧 **Service Mesh:** Istio for mTLS, traffic management, observability
🔧 **Distributed Tracing:** Jaeger for request flow visualization
🔧 **Secret Management:** HashiCorp Vault for dynamic secrets
🔧 **GitOps Operator:** ArgoCD/Flux for automated deployments
🔧 **Policy Engine:** Open Policy Agent for admission control
🔧 **Runtime Security:** Falco for threat detection
🔧 **Cost Management:** Kubecost for resource optimization
🔧 **Backup Automation:** Velero for cluster backup/restore

## Future Architecture Considerations

### 1. Multi-Region Deployment
```
                    Global Load Balancer (Route53)
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
    EU Region           US Region           Asia Region
    (eu-south-2)        (us-east-1)         (ap-southeast-1)
        │                     │                     │
    EKS Cluster         EKS Cluster          EKS Cluster
        │                     │                     │
    Regional DB         Regional DB          Regional DB
    (PostgreSQL)        (PostgreSQL)         (PostgreSQL)
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                    Global Database (Aurora Global)
```

### 2. Service Mesh Integration
```
Istio Control Plane (istiod)
        │
        ├── mTLS enforcement (automatic)
        ├── Traffic management (canary, A/B testing)
        ├── Observability (distributed tracing)
        ├── Policy enforcement (rate limiting, quotas)
        └── Circuit breaking
```

### 3. Serverless Integration
```
API Gateway → Lambda Functions → EKS Services
                    │
            Batch Processing (AWS Batch)
                    │
            Event-driven workflows (EventBridge)
```

## Conclusion

The CPTM8 Kubernetes architecture demonstrates a well-designed, cloud-native platform with clear separation of concerns, robust data persistence, and comprehensive observability. The use of Kustomize for multi-environment configuration management provides flexibility while maintaining consistency.

Key strengths include:
- Modular microservices architecture
- Stateful data tier with high availability
- Message queue-driven asynchronous processing
- Comprehensive logging and monitoring
- Multi-environment support with clear configuration strategy

The architecture is production-ready with recommended enhancements for:
- Service mesh implementation
- Advanced secret management
- Multi-region deployment
- Enhanced security controls
- Cost optimization strategies

The platform is well-positioned for future scalability and feature expansion while maintaining operational excellence and security best practices.
