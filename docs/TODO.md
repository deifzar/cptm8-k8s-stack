# CPTM8 Kubernetes TODO and Roadmap

**Date:** November 19, 2025
**Last Updated:** November 19, 2025
**Status:** In Progress

## Overview

This document tracks action items, improvements, and the development roadmap for the CPTM8 Kubernetes infrastructure. Items are prioritized by severity and impact, with clear ownership and deadlines.

## Priority Definitions

- **🔴 CRITICAL:** Security vulnerabilities, production outages, data loss risk
- **🟠 HIGH:** Major functionality gaps, performance degradation, compliance issues
- **🟡 MEDIUM:** Feature enhancements, optimizations, technical debt
- **🟢 LOW:** Nice-to-have improvements, documentation updates

## Status Tracking

- **✅ COMPLETED:** Task finished and verified
- **🚧 IN PROGRESS:** Currently being worked on
- **📋 PLANNED:** Scheduled for upcoming sprint
- **💭 BACKLOG:** Future consideration, not yet scheduled

---

## 🔴 CRITICAL ISSUES

### Security Vulnerabilities

#### 1. Remove Hardcoded Credentials
**Status:** 🚧 IN PROGRESS
**Priority:** 🔴 CRITICAL
**Assignee:** Security Team
**Deadline:** 2025-11-22 (3 days)
**Effort:** 4 hours

**Details:**
- Remove Grafana password from `docs/staging/staging-environment-guide.md:372`
- Remove AWS account ID from `CLAUDE.md` and all documentation
- Remove database credentials from `.env` examples
- Implement secrets via SOPS or External Secrets Operator

**Acceptance Criteria:**
- [ ] No plain text credentials in Git repository
- [ ] All secrets encrypted with SOPS
- [ ] Credentials rotated after removal
- [ ] Security scan confirms no exposed secrets

**References:** [SECURITY.md](./SECURITY.md#1-credential-management-high-risk), [SECURITY_REVIEW.md](./staging/SECURITY_REVIEW.md#1-hardcoded-grafana-password)

#### 2. Implement Container Security Contexts
**Status:** 📋 PLANNED
**Priority:** 🔴 CRITICAL
**Assignee:** Platform Team
**Deadline:** 2025-11-25 (6 days)
**Effort:** 8 hours

**Details:**
- Add security context to all deployments and StatefulSets
- Set `runAsNonRoot: true`, `readOnlyRootFilesystem: true`
- Drop all capabilities: `capabilities.drop: ["ALL"]`
- Add volumes for writable directories (`/tmp`, `/cache`)

**Acceptance Criteria:**
- [ ] All pods running as non-root (UID 1000)
- [ ] Read-only root filesystem enabled
- [ ] No capabilities except explicitly required
- [ ] Pod Security Standards (restricted) enforced

**Files Affected:**
- `bases/asmm8/deployment.yaml`
- `bases/naabum8/deployment.yaml`
- `bases/katanam8/deployment.yaml`
- `bases/num8/deployment.yaml`
- `bases/orchestratorm8/deployment.yaml`
- `bases/reportingm8/deployment.yaml`
- `bases/dashboardm8/deployment.yaml`
- `bases/socketm8/deployment.yaml`
- `bases/postgres/statefulset.yaml`
- `bases/mongodb/statefulset.yaml`
- `bases/rabbitmq/statefulset.yaml`

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#4-container-security---missing-security-context), [SECURITY.md](./SECURITY.md#3-container-security-high-risk)

#### 3. Implement Zero-Trust Network Policies
**Status:** 📋 PLANNED
**Priority:** 🔴 CRITICAL
**Assignee:** Network Team
**Deadline:** 2025-11-26 (7 days)
**Effort:** 6 hours

**Details:**
- Create default-deny-all network policy
- Implement explicit allow policies for each service
- Restrict egress to only required destinations
- Document network flow for each microservice

**Acceptance Criteria:**
- [ ] Default deny policy active in all namespaces
- [ ] All service-to-service communication explicitly allowed
- [ ] DNS and external API access restricted
- [ ] Network policy validation tests passing

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#3-network-security---overly-permissive-policies), [SECURITY.md](./SECURITY.md#2-network-security-high-risk)

---

## 🟠 HIGH PRIORITY ISSUES

### Image Security

#### 4. Stop Using `:latest` Image Tags
**Status:** 📋 PLANNED
**Priority:** 🟠 HIGH
**Assignee:** DevOps Team
**Deadline:** 2025-11-29 (10 days)
**Effort:** 4 hours

**Details:**
- Replace `:latest` tags with semantic versions (v1.2.3)
- Include SHA256 digests for immutability
- Update CI/CD to tag images with git commit SHA and version
- Implement image promotion pipeline (dev → staging → prod)

**Acceptance Criteria:**
- [ ] No `:latest` tags in any environment
- [ ] All images tagged with semantic version
- [ ] CI/CD automatically tags with version + SHA
- [ ] Rollback procedure documented and tested

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#1-image-management---using-latest-tag)

#### 5. Implement Image Scanning in CI/CD
**Status:** 📋 PLANNED
**Priority:** 🟠 HIGH
**Assignee:** Security Team
**Deadline:** 2025-12-02 (13 days)
**Effort:** 6 hours

**Details:**
- Integrate Trivy scanning in GitHub Actions
- Block builds with CRITICAL vulnerabilities
- Generate SBOM (Software Bill of Materials)
- Sign images with cosign

**Acceptance Criteria:**
- [ ] All images scanned before push to registry
- [ ] CRITICAL vulnerabilities block pipeline
- [ ] SBOM generated and stored
- [ ] Images signed and signatures verified

**GitHub Actions Workflow:**
```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_TAG }}
    severity: CRITICAL,HIGH
    exit-code: 1
```

### Resource Management

#### 6. Implement Resource Quotas and Limit Ranges
**Status:** 📋 PLANNED
**Priority:** 🟠 HIGH
**Assignee:** Platform Team
**Deadline:** 2025-12-03 (14 days)
**Effort:** 4 hours

**Details:**
- Create ResourceQuota for each namespace
- Define LimitRange for pods and containers
- Set appropriate defaults based on workload analysis
- Monitor resource utilization after implementation

**Acceptance Criteria:**
- [ ] ResourceQuota applied to all namespaces
- [ ] LimitRange prevents resource exhaustion
- [ ] Monitoring dashboards show quota utilization
- [ ] No production impact from quotas

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#2-resource-management---missing-resource-quotas), [PERFORMANCE.md](./PERFORMANCE.md#1-cluster-level-optimizations)

#### 7. Deploy Horizontal Pod Autoscaler (HPA)
**Status:** 📋 PLANNED
**Priority:** 🟠 HIGH
**Assignee:** Platform Team
**Deadline:** 2025-12-05 (16 days)
**Effort:** 6 hours

**Details:**
- Configure HPA for all stateless services
- Use CPU, memory, and custom metrics
- Define min/max replicas per environment
- Test autoscaling behavior under load

**Acceptance Criteria:**
- [ ] HPA configured for all services
- [ ] Metrics server deployed and functional
- [ ] Scaling tested with load testing
- [ ] Alerting configured for scaling events

**References:** [PERFORMANCE.md](./PERFORMANCE.md#2-application-level-optimizations)

### High Availability

#### 8. Increase Database Replicas
**Status:** 📋 PLANNED
**Priority:** 🟠 HIGH
**Assignee:** Database Team
**Deadline:** 2025-12-06 (17 days)
**Effort:** 8 hours

**Details:**
- PostgreSQL: 1 → 2 replicas (staging), 1 → 3 replicas (prod)
- MongoDB: 1 → 3 replicas (staging), maintain 3 (prod)
- RabbitMQ: 1 → 3 replicas (staging), maintain 3 (prod)
- Implement pod anti-affinity
- Test failover scenarios

**Acceptance Criteria:**
- [ ] All databases have ≥2 replicas in staging
- [ ] All databases have ≥3 replicas in production
- [ ] Pod anti-affinity ensures distribution
- [ ] Failover tested and documented

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#3-high-availability---single-point-of-failure)

#### 9. Implement Pod Disruption Budgets (PDBs)
**Status:** 📋 PLANNED
**Priority:** 🟠 HIGH
**Assignee:** Platform Team
**Deadline:** 2025-12-08 (19 days)
**Effort:** 3 hours

**Details:**
- Create PDB for all critical services
- Set `minAvailable` or `maxUnavailable` appropriately
- Test during node drain and upgrades

**Acceptance Criteria:**
- [ ] PDB defined for all services with ≥2 replicas
- [ ] Node drain respects PDBs
- [ ] Cluster upgrades do not violate availability

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#3-service-configuration---no-pod-disruption-budgets)

### Monitoring and Observability

#### 10. Deploy Prometheus and Grafana
**Status:** 📋 PLANNED
**Priority:** 🟠 HIGH
**Assignee:** SRE Team
**Deadline:** 2025-12-10 (21 days)
**Effort:** 12 hours

**Details:**
- Deploy kube-prometheus-stack via Helm
- Configure ServiceMonitors for all services
- Create Grafana dashboards for key metrics
- Set up alerting rules for critical conditions

**Acceptance Criteria:**
- [ ] Prometheus scraping all services
- [ ] Grafana dashboards deployed
- [ ] Alerts configured and tested
- [ ] Runbooks linked from alerts

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#4-monitoring---missing-service-monitors), [PERFORMANCE.md](./PERFORMANCE.md#6-monitoring-and-metrics)

#### 11. Implement Centralized Logging
**Status:** ✅ COMPLETED (Vector + OpenSearch deployed)
**Priority:** 🟠 HIGH
**Assignee:** SRE Team
**Completed:** 2025-11-15

**Details:**
- Vector DaemonSet collecting logs
- OpenSearch storing and indexing
- Index lifecycle management configured

**Follow-up Tasks:**
- [ ] Add Grafana integration for log visualization
- [ ] Implement log-based alerting
- [ ] Configure retention policies per environment

---

## 🟡 MEDIUM PRIORITY ISSUES

### Performance Optimizations

#### 12. Deploy PgBouncer for Connection Pooling
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Database Team
**Deadline:** 2025-12-15 (26 days)
**Effort:** 6 hours

**Details:**
- Deploy PgBouncer between applications and PostgreSQL
- Configure transaction pooling mode
- Update application connection strings
- Monitor connection pool utilization

**Acceptance Criteria:**
- [ ] PgBouncer deployed with 2 replicas
- [ ] All services use PgBouncer
- [ ] Database connection count reduced by 50%+
- [ ] Query performance maintained or improved

**References:** [PERFORMANCE.md](./PERFORMANCE.md#deploy-pgbouncer-for-connection-pooling), [CODE_REVIEW.md](./CODE_REVIEW.md#5-database-configuration---missing-connection-pooling)

#### 13. Optimize PostgreSQL Configuration
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Database Team
**Deadline:** 2025-12-17 (28 days)
**Effort:** 4 hours

**Details:**
- Tune `shared_buffers`, `effective_cache_size`, `work_mem`
- Configure autovacuum for Kubernetes environment
- Enable WAL compression
- Adjust checkpoint settings

**Acceptance Criteria:**
- [ ] Configuration applied via ConfigMap
- [ ] Performance benchmarks show improvement
- [ ] Buffer cache hit ratio ≥98%
- [ ] Query performance improved by ≥20%

**References:** [PERFORMANCE.md](./PERFORMANCE.md#optimize-postgresql-configuration)

#### 14. Implement Storage Class Strategy
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Platform Team
**Deadline:** 2025-12-20 (31 days)
**Effort:** 5 hours

**Details:**
- Create storage classes: fast-ssd, general-purpose, bulk-storage
- Map workloads to appropriate storage class
- Use emptyDir for temporary storage
- Configure PVC expansion policies

**Acceptance Criteria:**
- [ ] 3 storage classes defined
- [ ] All PVCs use explicit storage class
- [ ] Cost reduction from optimized storage
- [ ] Performance improvement for I/O workloads

**References:** [PERFORMANCE.md](./PERFORMANCE.md#4-storage-optimizations), [CODE_REVIEW.md](./CODE_REVIEW.md#4-storage-configuration---no-storageclass-specifications)

### Security Enhancements

#### 15. Implement RBAC for Service Accounts
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Security Team
**Deadline:** 2025-12-22 (33 days)
**Effort:** 8 hours

**Details:**
- Create service account for each microservice
- Define least-privilege roles
- Bind roles to service accounts
- Disable automounting where not needed

**Acceptance Criteria:**
- [ ] All services use dedicated service accounts
- [ ] No service uses default service account
- [ ] Roles follow least-privilege principle
- [ ] RBAC audit shows no excessive permissions

**References:** [SECURITY.md](./SECURITY.md#2-rbac-configuration), [CODE_REVIEW.md](./CODE_REVIEW.md)

#### 16. Add Security Headers to Ingress
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Security Team
**Deadline:** 2025-12-23 (34 days)
**Effort:** 2 hours

**Details:**
- Configure NGINX annotations for security headers
- X-Frame-Options, X-Content-Type-Options, CSP, HSTS
- Test headers with security scanning tools
- Document exceptions for specific paths

**Acceptance Criteria:**
- [ ] All security headers present in responses
- [ ] Security scan shows A+ rating
- [ ] No functional regressions
- [ ] Headers documented

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#2-ingress-configuration---missing-security-headers), [SECURITY.md](./SECURITY.md#1-ingress-security-headers)

#### 17. Implement Rate Limiting
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Platform Team
**Deadline:** 2025-12-25 (36 days)
**Effort:** 4 hours

**Details:**
- Configure NGINX rate limiting annotations
- Set appropriate limits per endpoint
- Implement IP-based and user-based limits
- Monitor rate limit hits

**Acceptance Criteria:**
- [ ] Rate limits configured for all public endpoints
- [ ] 429 responses return appropriate headers
- [ ] Legitimate traffic not impacted
- [ ] DoS attack mitigation verified

**References:** [SECURITY.md](./SECURITY.md#2-rate-limiting)

### CI/CD Improvements

#### 18. Implement GitOps with ArgoCD
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** DevOps Team
**Deadline:** 2026-01-05 (47 days)
**Effort:** 12 hours

**Details:**
- Deploy ArgoCD in management cluster
- Configure ArgoCD applications for each environment
- Implement automated sync policies
- Set up notifications and RBAC

**Acceptance Criteria:**
- [ ] ArgoCD deployed and accessible
- [ ] All environments managed by ArgoCD
- [ ] Automated sync with manual approval for prod
- [ ] Deployment history visible in ArgoCD UI

#### 19. Add Deployment Smoke Tests
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** QA Team
**Deadline:** 2026-01-08 (50 days)
**Effort:** 8 hours

**Details:**
- Create smoke test suite for post-deployment validation
- Test critical paths: health checks, database connectivity, message queue
- Integrate into CI/CD pipeline
- Auto-rollback on smoke test failure

**Acceptance Criteria:**
- [ ] Smoke tests run after every deployment
- [ ] Tests cover all critical services
- [ ] Failed tests trigger rollback
- [ ] Test results visible in pipeline

---

## 🟢 LOW PRIORITY ISSUES

### Documentation

#### 20. Add Runbook Links to Resources
**Status:** 💭 BACKLOG
**Priority:** 🟢 LOW
**Assignee:** SRE Team
**Deadline:** 2026-01-15 (57 days)
**Effort:** 4 hours

**Details:**
- Add annotations with runbook URLs
- Create runbooks for common incidents
- Link PagerDuty services and Slack channels

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#2-documentation---missing-runbook-links)

#### 21. Standardize Resource Naming
**Status:** 💭 BACKLOG
**Priority:** 🟢 LOW
**Assignee:** Platform Team
**Deadline:** 2026-01-20 (62 days)
**Effort:** 6 hours

**Details:**
- Define naming conventions: `-svc`, `-deploy`, `-sts`, `-config`, `-secret`
- Rename existing resources (with backward compatibility)
- Update documentation and templates

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#3-resource-naming---inconsistent-suffixes)

#### 22. Improve Health Check Configuration
**Status:** 💭 BACKLOG
**Priority:** 🟢 LOW
**Assignee:** Development Team
**Deadline:** 2026-01-25 (67 days)
**Effort:** 4 hours

**Details:**
- Add startup probes for slow-starting services
- Tune timeouts and thresholds
- Separate liveness and readiness endpoints
- Document health check behavior

**References:** [CODE_REVIEW.md](./CODE_REVIEW.md#4-health-checks---insufficient-probe-configuration)

---

## Future Enhancements

### Service Mesh (Q1 2026)

#### 23. Implement Istio Service Mesh
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Platform Team
**Deadline:** 2026-03-31 (132 days)
**Effort:** 40 hours

**Details:**
- Install Istio with production profile
- Enable automatic sidecar injection
- Configure mTLS (STRICT mode)
- Implement traffic management (canary, blue-green)
- Set up observability (Jaeger, Kiali)

**Acceptance Criteria:**
- [ ] Istio control plane deployed
- [ ] All services have Envoy sidecars
- [ ] mTLS enabled for service-to-service
- [ ] Traffic policies implemented
- [ ] Distributed tracing functional

**References:** [SECURITY.md](./SECURITY.md#3-mtls-with-service-mesh), [ARCHITECTURE.md](./ARCHITECTURE.md)

### Advanced Monitoring (Q2 2026)

#### 24. Implement Distributed Tracing
**Status:** 💭 BACKLOG
**Priority:** 🟢 LOW
**Assignee:** SRE Team
**Deadline:** 2026-06-30 (224 days)
**Effort:** 20 hours

**Details:**
- Deploy Jaeger or Tempo
- Instrument applications with OpenTelemetry
- Integrate with Istio service mesh
- Create trace-based dashboards

### Cost Optimization (Q2 2026)

#### 25. Implement Cluster Autoscaler
**Status:** 💭 BACKLOG
**Priority:** 🟡 MEDIUM
**Assignee:** Platform Team
**Deadline:** 2026-06-15 (209 days)
**Effort:** 8 hours

**Details:**
- Deploy cluster autoscaler for EKS
- Configure scale-up/scale-down policies
- Use spot instances for non-critical workloads
- Monitor cost savings

#### 26. Deploy Kubecost for Cost Visibility
**Status:** 💭 BACKLOG
**Priority:** 🟢 LOW
**Assignee:** FinOps Team
**Deadline:** 2026-06-30 (224 days)
**Effort:** 6 hours

**Details:**
- Deploy Kubecost via Helm
- Configure AWS cost integration
- Set up cost allocation by team/service
- Create cost dashboards and alerts

---

## Completed Items

### ✅ Recently Completed (November 2025)

#### Infrastructure Setup
- [x] Create Kind cluster configuration with port mappings (2025-11-15)
- [x] Deploy base Kubernetes manifests structure (2025-11-16)
- [x] Implement Kustomize overlays for dev/staging/prod (2025-11-17)
- [x] Deploy Vector for log collection (2025-11-18)
- [x] Deploy OpenSearch for log storage (2025-11-18)
- [x] Create comprehensive documentation (2025-11-19)
  - ARCHITECTURE.md
  - CODE_REVIEW.md
  - DEVELOPMENT.md
  - PERFORMANCE.md
  - SECURITY.md
  - TODO.md (this file)
  - CLAUDE.md

---

## Roadmap Summary

### Week 1 (Nov 19-25, 2025) - Security Critical
- Remove hardcoded credentials
- Implement container security contexts
- Deploy zero-trust network policies

### Week 2-3 (Nov 26 - Dec 9, 2025) - High Priority
- Stop using `:latest` tags
- Implement image scanning
- Deploy resource quotas and limits
- Configure HPA for all services
- Increase database replicas

### Week 4-5 (Dec 10-23, 2025) - Medium Priority
- Deploy monitoring stack (Prometheus + Grafana)
- Implement PDBs
- Deploy PgBouncer
- Configure RBAC
- Add security headers

### Month 2 (Dec 24 - Jan 23, 2026) - Enhancements
- Implement GitOps with ArgoCD
- Add deployment smoke tests
- Optimize storage classes
- Improve documentation

### Q1 2026 (Jan-Mar) - Advanced Features
- Implement service mesh (Istio)
- Deploy runtime security (Falco)
- Implement policy enforcement (OPA)

### Q2 2026 (Apr-Jun) - Optimization
- Distributed tracing
- Cluster autoscaler
- Cost optimization
- Multi-region deployment

---

## Sprint Planning

### Current Sprint (Nov 19-26, 2025)

**Sprint Goals:**
- Remove all hardcoded credentials
- Implement container security contexts
- Deploy zero-trust network policies

**Sprint Capacity:** 40 hours
**Sprint Commitment:** 18 hours (3 critical issues)

### Next Sprint (Nov 27 - Dec 10, 2025)

**Planned Items:**
- Stop using `:latest` tags
- Implement image scanning
- Deploy resource quotas
- Configure HPA
- Increase database replicas
- Implement PDBs

**Estimated Capacity:** 40 hours
**Estimated Commitment:** 35 hours

---

## Metrics and KPIs

### Security Metrics
- **Current:** 20 security issues identified
- **Target (Week 4):** 0 critical, ≤5 high priority
- **Target (Month 3):** 0 critical, 0 high priority

### Availability Metrics
- **Current SLA:** 95% (single replicas, no PDBs)
- **Target (Week 3):** 99% (HA databases, PDBs)
- **Target (Month 2):** 99.9% (full HA stack)

### Performance Metrics
- **Current P95 Latency:** 50-150ms
- **Target (Week 5):** <100ms
- **Target (Month 2):** <50ms

### Cost Metrics
- **Current:** Baseline (not measured)
- **Target (Month 2):** 20% reduction via rightsizing
- **Target (Q2 2026):** 40% reduction via autoscaling + spot

---

## Notes

- All deadlines are estimates and subject to change based on priorities
- Critical security issues take precedence over all other work
- Production deployments require security review and change approval
- Major changes should be tested in dev → staging → production
- This document is a living document and should be updated weekly

**Last Review:** 2025-11-19
**Next Review:** 2025-11-26
**Owner:** Platform Team Lead

---

## References

- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [CODE_REVIEW.md](./CODE_REVIEW.md) - Identified issues and recommendations
- [DEVELOPMENT.md](./DEVELOPMENT.md) - Development workflows
- [PERFORMANCE.md](./PERFORMANCE.md) - Performance optimization guide
- [SECURITY.md](./SECURITY.md) - Security considerations
- [SECURITY_REVIEW.md](./staging/SECURITY_REVIEW.md) - Comprehensive security audit (20 issues)
- [CLAUDE.md](../CLAUDE.md) - Guide for Claude Code instances

## Contact

For questions or concerns about this roadmap, contact:
- Platform Team: platform-team@securetivity.com
- Security Team: security-team@securetivity.com
- Project Manager: pm@securetivity.com
