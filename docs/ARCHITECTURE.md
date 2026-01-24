# CPTM8 Kubernetes Architecture - Component Details

**Date:** November 19, 2025
**Last Updated:** January 2026
**Version:** 2.0

> **Note:** For high-level architecture diagrams, environment comparison matrices, CI/CD pipeline flows, and deployment strategies, see [kubernetes-architecture-diagram.md](./deployment/kubernetes-architecture-diagram.md).

## Overview

CPTM8 (Continuous Penetration Testing Mate) is a cloud-native, microservices-based platform for automated security testing and attack surface management. This document provides detailed component specifications, data schemas, and implementation patterns.

## Component Architecture

### 1. Ingress Layer

**Purpose:** External traffic routing and TLS termination
**Technology:** NGINX Ingress Controller
**Pattern:** Reverse proxy with path-based routing

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

### 2. Frontend Layer

#### DashboardM8
**Purpose:** Web-based user interface
**Technology:** React/Next.js
**Port:** 3000

**Features:**
- Real-time scanning dashboard
- Domain and hostname management
- Scan history and reporting
- User authentication interface

#### SocketM8
**Purpose:** Real-time WebSocket communication
**Technology:** Go WebSocket server
**Pattern:** Publisher-Subscriber with connection pooling
**Port:** 4000

**Features:**
- Real-time scan progress updates
- Live notification delivery
- Connection state management
- Message acknowledgment

### 3. Application Layer (Go Microservices)

#### ASMM8 (Port 8000)
**Purpose:** Attack Surface Management and subdomain enumeration
**Technology:** Go 1.21.5, Gin Web Framework
**Pattern:** RESTful API with RabbitMQ message queue integration

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

#### NAABUM8 (Port 8001)
**Purpose:** Port scanning
**Technology:** Go with RabbitMQ consumer
**Pattern:** Event-driven message processor

**Features:**
- Nmap-based port scanning
- Service fingerprinting
- Multi-channel distribution (email, webhook, Slack)
- Notification templating

**RabbitMQ Integration:**
- Consumer: cnaabum8
- Queue: qnaabum8
- Exchange: notification (topic)
- Routing Key: `cptm8.notification.#`

#### KATANAM8 (Port 8002)
**Purpose:** Web crawling and asset discovery
**Technology:** Go with web crawling tools
**Pattern:** Pipeline processing with result aggregation

**Features:**
- URL extraction
- JavaScript analysis
- Asset cataloging

#### NUM8 (Port 8003)
**Purpose:** Vulnerability scanning with Nuclei
**Technology:** Go with Nuclei integration
**Pattern:** Concurrent vulnerability probing

**Features:**
- Nuclei template execution
- SSL/TLS analysis
- CVE detection

#### OrchestratorM8
**Purpose:** Workflow orchestration, task scheduling, and RabbitMQ queue initialization
**Technology:** Go with RabbitMQ integration
**Pattern:** Workflow engine with state machine

**Features:**
- Multi-stage scan orchestration
- Task dependencies management
- Retry logic with exponential backoff
- Workflow state persistence
- Queue initialization on startup

#### ReportingM8
**Purpose:** Report generation and export
**Technology:** Go with PDF/HTML/JSON export
**Pattern:** Template-based report generation (CronJob)

**Features:**
- Customizable report templates
- Multi-format export (PDF, HTML, JSON, CSV)
- Monthly scheduled generation
- AWS S3 upload

### 4. Data Layer

#### PostgreSQL (StatefulSet)
**Purpose:** Relational data storage for domains, hostnames, scans
**Technology:** PostgreSQL 14

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

**Port:** 5432

#### MongoDB (StatefulSet)
**Purpose:** Document storage for chat messages
**Technology:** MongoDB 6.0
**Pattern:** StatefulSet with replica set configuration

**Collections:**
```javascript
// Chat messages
chat_messages {
  _id, timestamp, user, room, message, attachments
}

// Audit logs
audit_logs {
  _id, timestamp, user, action, resource, details
}
```

**Replica Set Configuration:**
- Replica Set Name: rs0
- Read Preference: primaryPreferred
- Write Concern: majority

**Port:** 27017

#### RabbitMQ (StatefulSet)
**Purpose:** Message queue for inter-service communication
**Technology:** RabbitMQ 3.12 with management plugin

**Cluster Configuration:**
```yaml
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

**Ports:**
- 5672 (AMQP)
- 15672 (Management UI)

#### OpenSearch (StatefulSet)
**Purpose:** Log aggregation, search, and analytics
**Technology:** OpenSearch 2.11 (Elasticsearch fork)

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

### 5. Observability Layer

#### Vector (DaemonSet)
**Purpose:** Log collection and forwarding
**Technology:** Vector.dev

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

## Data Flow Architecture

### Scan Pipeline Flow (with Manual Acknowledgment)
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

### Log Aggregation Flow
```
Application Logs (stdout/stderr) → Container Runtime
                                        ↓
            Vector DaemonSet (reads /var/log/pods/*) → Parse JSON logs
                                        ↓
                    Add Kubernetes metadata (namespace, pod, labels)
                                        ↓
                    Transform/Enrich → Filter sensitive data
                                        ↓
                OpenSearch → Index (cptm8-logs-YYYY.MM.DD)
                                        ↓
                Grafana Dashboard → Real-time log viewing
```

## Error Handling Architecture

### Error Categories

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

### Retry Logic
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

### Circuit Breaker Pattern (Recommended)
```go
// Circuit breaker for external services
type CircuitBreaker struct {
    State: "closed" | "open" | "half-open"
    FailureThreshold: 5
    SuccessThreshold: 2
    Timeout: 60 * time.Second
}
```

## Design Patterns

### Kubernetes Patterns
- **Sidecar Pattern:** Vector logging sidecar for observability
- **Ambassador Pattern:** NGINX ingress as reverse proxy
- **Init Container Pattern:** Tool installation before main container starts
- **StatefulSet Pattern:** Databases with persistent identity
- **DaemonSet Pattern:** Vector log collector on every node

### Microservices Patterns
- **API Gateway:** NGINX Ingress as API gateway
- **Event-Driven:** RabbitMQ message queue for async communication
- **CQRS:** Separate read (MongoDB) and write (PostgreSQL) models
- **Service Discovery:** Kubernetes DNS for service resolution
- **Health Check:** Liveness and readiness probes

### Operational Patterns
- **GitOps:** Declarative configuration with Kustomize
- **Infrastructure as Code:** All resources defined in YAML
- **Immutable Infrastructure:** Container images with version tags
- **Blue-Green Deployment:** Zero-downtime updates
- **Canary Deployment:** Gradual rollout with traffic shifting

## Architecture Best Practices

### Followed Practices
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

### Areas for Improvement
⚠️ Secrets management (currently using SOPS, consider Vault)
⚠️ Service mesh implementation (Istio/Linkerd not yet deployed)
⚠️ Advanced monitoring (distributed tracing with Jaeger)
⚠️ Cost optimization (pod rightsizing, spot instances)
⚠️ Disaster recovery automation
⚠️ Multi-region deployment for global availability
⚠️ Advanced security scanning (OPA policies, Falco runtime security)

### Recommended Additions
🔧 **Service Mesh:** Istio for mTLS, traffic management, observability
🔧 **Distributed Tracing:** Jaeger for request flow visualization
🔧 **Secret Management:** HashiCorp Vault for dynamic secrets
🔧 **GitOps Operator:** ArgoCD/Flux for automated deployments
🔧 **Policy Engine:** Open Policy Agent for admission control
🔧 **Runtime Security:** Falco for threat detection
🔧 **Cost Management:** Kubecost for resource optimization
🔧 **Backup Automation:** Velero for cluster backup/restore

## Future Architecture Considerations

### Multi-Region Deployment
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
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                    Global Database (Aurora Global)
```

### Service Mesh Integration
```
Istio Control Plane (istiod)
        │
        ├── mTLS enforcement (automatic)
        ├── Traffic management (canary, A/B testing)
        ├── Observability (distributed tracing)
        ├── Policy enforcement (rate limiting, quotas)
        └── Circuit breaking
```

### Serverless Integration
```
API Gateway → Lambda Functions → EKS Services
                    │
            Batch Processing (AWS Batch)
                    │
            Event-driven workflows (EventBridge)
```

## Conclusion

The CPTM8 Kubernetes architecture demonstrates a well-designed, cloud-native platform with clear separation of concerns, robust data persistence, and comprehensive observability.

Key strengths include:
- Modular microservices architecture
- Stateful data tier with high availability
- Message queue-driven asynchronous processing
- Comprehensive logging and monitoring
- Multi-environment support with clear configuration strategy

The platform is well-positioned for future scalability and feature expansion while maintaining operational excellence and security best practices.
