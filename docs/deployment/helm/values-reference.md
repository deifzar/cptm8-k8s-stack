# CPTM8 Helm Values Reference

Complete reference for all configurable values in the CPTM8 Helm chart.

---

## Available Values Files

| File | Environment | Description |
|------|-------------|-------------|
| `values.yaml` | Development | Default values, NodePort access |
| `values-dev-ingress.yaml` | Development | Ingress-based local development |
| `values-staging-aws.yaml` | Staging (AWS) | AWS EKS with ALB Ingress |
| `values-staging-azure.yaml` | Staging (Azure) | Azure AKS with NGINX + cert-manager |
| `values-secrets-*.yaml.example` | All | Example secrets templates |

---

## Table of Contents

1. [Global Configuration](#global-configuration)
2. [Namespace](#namespace)
3. [Application Config](#application-config)
4. [Storage](#storage)
5. [Scanners](#scanners)
6. [Reporting](#reporting)
7. [Frontend](#frontend)
8. [Databases](#databases)
9. [Observability](#observability)
10. [Ingress](#ingress)
11. [Network Policies](#network-policies)
12. [CronJobs](#cronjobs)
13. [Secrets](#secrets)
14. [RBAC](#rbac)
15. [Autoscaling](#autoscaling)

---

## Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.environment` | Environment name (dev, staging, prod) | `dev` |
| `global.imageRegistry` | Container registry URL | `""` (empty for local) |
| `global.imageTag` | Default image tag for all services | `dev-latest` |
| `global.imagePullPolicy` | Image pull policy | `IfNotPresent` |
| `global.imagePullSecrets` | Image pull secrets array | `[{name: ecr-registry-secret}]` |
| `global.initImage` | Init container image | `busybox:1.35` |
| `global.storageClass` | Default StorageClass | `cptm8-dev-ssd` |
| `global.logsStorageClass` | Logs StorageClass | `cptm8-dev-logs-shared` |

### Security Context

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.securityContext.runAsUser` | UID for containers | `10001` |
| `global.securityContext.runAsGroup` | GID for containers | `10001` |
| `global.securityContext.fsGroup` | FS group for volumes | `10001` |

### Default Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.resources.scanner.requests.memory` | Scanner memory request | `256Mi` |
| `global.resources.scanner.requests.cpu` | Scanner CPU request | `250m` |
| `global.resources.scanner.limits.memory` | Scanner memory limit | `512Mi` |
| `global.resources.scanner.limits.cpu` | Scanner CPU limit | `500m` |
| `global.resources.frontend.requests.memory` | Frontend memory request | `256Mi` |
| `global.resources.frontend.requests.cpu` | Frontend CPU request | `250m` |
| `global.resources.frontend.limits.memory` | Frontend memory limit | `512Mi` |
| `global.resources.frontend.limits.cpu` | Frontend CPU limit | `500m` |
| `global.resources.database.requests.memory` | Database memory request | `256Mi` |
| `global.resources.database.requests.cpu` | Database CPU request | `250m` |
| `global.resources.database.limits.memory` | Database memory limit | `512Mi` |
| `global.resources.database.limits.cpu` | Database CPU limit | `500m` |

---

## Namespace

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace.create` | Create namespace | `true` |
| `namespace.annotations` | Namespace annotations | `{}` |
| `namespace.resourceQuota.enabled` | Enable ResourceQuota | `false` |
| `namespace.resourceQuota.requests.cpu` | CPU requests quota | `2` |
| `namespace.resourceQuota.requests.memory` | Memory requests quota | `8Gi` |
| `namespace.resourceQuota.limits.cpu` | CPU limits quota | `4` |
| `namespace.resourceQuota.limits.memory` | Memory limits quota | `16Gi` |
| `namespace.resourceQuota.persistentvolumeclaims` | PVC count quota | `10` |

---

## Application Config

Configuration values used in ConfigMaps.

### AWS

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.aws.accountId` | AWS Account ID | `507745009364` |
| `config.aws.region` | AWS Region | `eu-south-2` |

### PostgreSQL

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.postgresql.hostname` | PostgreSQL hostname | `postgresql-service` |
| `config.postgresql.port` | PostgreSQL port | `5432` |
| `config.postgresql.database` | Database name | `cptm8` |
| `config.postgresql.rootUsername` | Root username | `postgres` |
| `config.postgresql.nonRootUsername` | App username | `cpt_dbuser` |

### MongoDB

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.mongodb.hostname` | MongoDB hostname | `mongodb-primary-service` |
| `config.mongodb.port` | MongoDB port | `27017` |
| `config.mongodb.database` | Database name | `cptm8chat` |
| `config.mongodb.collection` | Collection name | `support` |
| `config.mongodb.rootUsername` | Root username | `admin` |
| `config.mongodb.nonRootUsername` | App username | `cpt_dbuser` |

### RabbitMQ

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.rabbitmq.hostname` | RabbitMQ hostname | `rabbitmq-service` |
| `config.rabbitmq.port` | AMQP port | `5672` |
| `config.rabbitmq.managementPort` | Management UI port | `15672` |

### OpenSearch

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.opensearch.hostname` | OpenSearch hostname | `opensearch-service` |
| `config.opensearch.port` | OpenSearch port | `9200` |

### SMTP

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.smtp.server` | SMTP server | `email-smtp.eu-north-1.amazonaws.com` |
| `config.smtp.port` | SMTP port | `587` |
| `config.smtp.emailSender` | Sender email | `no-reply@cptm8.net` |

### Frontend URLs

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.frontend.dashboardUrl` | Dashboard URL | `http://dashboard-dev.cptm8.net:3000` |
| `config.frontend.dashboardPort` | Dashboard port | `3000` |
| `config.frontend.socketUrl` | Socket.io URL | `http://socket-dev.cptm8.net:4000` |
| `config.frontend.socketPort` | Socket.io port | `4000` |
| `config.frontend.authUrl` | Auth URL | `http://dashboard-dev.cptm8.net:3000` |
| `config.frontend.userEmailDomain` | User email domain | `clientcorp.net.au` |
| `config.frontend.cloudProvider` | Cloud provider (AWS/Azure) | `AWS` |

### Reporting

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.reporting.companyName` | Company name in reports | `ACME Corp.` |
| `config.reporting.awsBucketRegion` | S3 bucket region | `eu-north-1` |
| `config.reporting.awsBucketName` | S3 bucket name | `report-cptm8` |

---

## Storage

### Retain StorageClass

| Parameter | Description | Default |
|-----------|-------------|---------|
| `storage.retainStorageClass.create` | Create StorageClass | `true` |
| `storage.retainStorageClass.provisioner` | Provisioner | `rancher.io/local-path` |
| `storage.retainStorageClass.reclaimPolicy` | Reclaim policy | `Retain` |

### Delete StorageClass

| Parameter | Description | Default |
|-----------|-------------|---------|
| `storage.deleteStorageClass.create` | Create StorageClass | `true` |
| `storage.deleteStorageClass.provisioner` | Provisioner | `rancher.io/local-path` |
| `storage.deleteStorageClass.reclaimPolicy` | Reclaim policy | `Delete` |

### AWS EBS StorageClass

| Parameter | Description | Default |
|-----------|-------------|---------|
| `storage.awsEBSStorageClass.create` | Create StorageClass | `true` |
| `storage.awsEBSStorageClass.provisioner` | Provisioner | `ebs.csi.aws.com` |
| `storage.awsEBSStorageClass.parameters.type` | EBS type | `gp3` |
| `storage.awsEBSStorageClass.parameters.encrypted` | Encryption enabled | `true` |
| `storage.awsEBSStorageClass.parameters.iops` | IOPS | `3000` |
| `storage.awsEBSStorageClass.parameters.throughput` | Throughput MB/s | `125` |

### Azure Disk StorageClass

| Parameter | Description | Default |
|-----------|-------------|---------|
| `storage.azureDiskPremiumStorageClass.create` | Create StorageClass | `true` |
| `storage.azureDiskPremiumStorageClass.provisioner` | Provisioner | `disk.csi.azure.com` |
| `storage.azureDiskPremiumStorageClass.parameters.skuName` | SKU | `Premium_LRS` |
| `storage.azureDiskPremiumStorageClass.parameters.enableBursting` | Enable bursting | `true` |

---

## Scanners

Go-based microservices for security scanning.

### Common Scanner Options

Each scanner (asmm8, naabum8, katanam8, num8, orchestratorm8) supports:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scanners.<name>.enabled` | Enable scanner | `true` |
| `scanners.<name>.replicaCount` | Replica count | `1` |
| `scanners.<name>.port` | Container port | varies |
| `scanners.<name>.image.tag` | Image tag override | `""` (uses global) |
| `scanners.<name>.probes.initialDelaySeconds` | Probe initial delay | `30` |
| `scanners.<name>.probes.periodSeconds` | Probe period | `10` |
| `scanners.<name>.probes.timeoutSeconds` | Probe timeout | `5` |
| `scanners.<name>.probes.failureThreshold` | Probe failure threshold | `3` |
| `scanners.<name>.resources` | Resource limits/requests | `{}` (uses global) |

### Scanner-Specific Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scanners.naabum8.privileged` | Run in privileged mode (port scanning) | `true` |
| `scanners.num8.extraVolumes` | Extra volumes (nuclei templates) | `[{name: dir-nuclei-templates, emptyDir: {}}]` |
| `scanners.num8.extraVolumeMounts` | Extra volume mounts | `[{name: dir-nuclei-templates, mountPath: /app/nuclei-templates}]` |
| `scanners.orchestratorm8.readOnlyRootFilesystem` | Read-only root FS | `true` |

---

## Reporting

| Parameter | Description | Default |
|-----------|-------------|---------|
| `reporting.reportingm8.enabled` | Enable reporting service | `true` |
| `reporting.reportingm8.replicaCount` | Replica count | `1` |
| `reporting.reportingm8.port` | Container port | `8004` |
| `reporting.reportingm8.resources` | Resource limits/requests | `{}` |

---

## Frontend

### Dashboard (dashboardm8)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.dashboardm8.enabled` | Enable dashboard | `true` |
| `frontend.dashboardm8.replicaCount` | Replica count | `1` |
| `frontend.dashboardm8.port` | Container port | `3000` |
| `frontend.dashboardm8.securityContext.runAsUser` | UID | `1001` |
| `frontend.dashboardm8.securityContext.runAsGroup` | GID | `1001` |
| `frontend.dashboardm8.securityContext.fsGroup` | FS group | `1001` |
| `frontend.dashboardm8.probes.initialDelaySeconds` | Probe delay | `180` |
| `frontend.dashboardm8.probes.path` | Health check path | `/signin` |

### Socket.io (socketm8)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.socketm8.enabled` | Enable socket server | `true` |
| `frontend.socketm8.replicaCount` | Replica count | `1` |
| `frontend.socketm8.port` | Container port | `4000` |
| `frontend.socketm8.probes.livenessPath` | Liveness path | `/health` |
| `frontend.socketm8.probes.readinessPath` | Readiness path | `/ready` |

---

## Databases

### PostgreSQL

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.image.repository` | Image repository | `postgres` |
| `postgresql.image.tag` | Image tag | `15-alpine` |
| `postgresql.persistence.enabled` | Enable persistence | `true` |
| `postgresql.persistence.size` | PVC size | `30Gi` |
| `postgresql.persistence.storageClass` | StorageClass | `""` (uses global) |

### MongoDB

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mongodb.enabled` | Enable MongoDB | `true` |
| `mongodb.image.repository` | Image repository | `mongo` |
| `mongodb.image.tag` | Image tag | `7.0` |
| `mongodb.replicaSet.name` | Replica set name | `rs0` |
| `mongodb.persistence.dataSize` | Data PVC size | `20Gi` |
| `mongodb.persistence.configSize` | Config PVC size | `1Gi` |
| `mongodb.initJob.enabled` | Enable init job | `true` |
| `mongodb.initJob.ttlSecondsAfterFinished` | Job TTL | `3600` |

### RabbitMQ

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rabbitmq.enabled` | Enable RabbitMQ | `true` |
| `rabbitmq.image.repository` | Image repository | `rabbitmq` |
| `rabbitmq.image.tag` | Image tag | `3.12-management-alpine` |
| `rabbitmq.persistence.enabled` | Enable persistence | `true` |
| `rabbitmq.persistence.size` | PVC size | `10Gi` |

### OpenSearch

| Parameter | Description | Default |
|-----------|-------------|---------|
| `opensearch.enabled` | Enable OpenSearch | `true` |
| `opensearch.image.repository` | Image repository | `opensearchproject/opensearch` |
| `opensearch.image.tag` | Image tag | `2.11.1` |
| `opensearch.nodeCount` | Node count | `2` |
| `opensearch.persistence.enabled` | Enable persistence | `true` |
| `opensearch.persistence.size` | PVC size per node | `10Gi` |
| `opensearch.javaOpts` | JVM options | `-Xms512m -Xmx512m` |
| `opensearch.disableSecurity` | Disable security plugin | `true` |
| `opensearch.dashboard.enabled` | Enable Dashboards | `true` |
| `opensearch.dashboard.image.repository` | Dashboards image | `opensearchproject/opensearch-dashboards` |
| `opensearch.dashboard.image.tag` | Dashboards tag | `2.11.1` |

---

## Observability

### Vector

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vector.enabled` | Enable Vector | `true` |
| `vector.image.repository` | Image repository | `timberio/vector` |
| `vector.image.tag` | Image tag | `0.34.1-alpine` |
| `vector.serviceAccount.name` | ServiceAccount name | `vector-sa` |
| `vector.serviceAccount.create` | Create ServiceAccount | `true` |
| `vector.resources.requests.memory` | Memory request | `256Mi` |
| `vector.resources.requests.cpu` | CPU request | `250m` |
| `vector.resources.limits.memory` | Memory limit | `512Mi` |
| `vector.resources.limits.cpu` | CPU limit | `500m` |

---

## Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class (nginx, alb, azure-application-gateway) | `nginx` |
| `ingress.annotations` | Additional annotations | `{}` |
| `ingress.hosts` | Host configurations | `[]` |
| `ingress.tls` | TLS configuration | `[]` |

### Rate Limiting (NGINX)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.rateLimit.enabled` | Enable rate limiting | `false` |
| `ingress.rateLimit.rps` | Requests per second | `100` |
| `ingress.rateLimit.connections` | Max connections | `50` |

### cert-manager

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.certManager.enabled` | Enable cert-manager | `false` |
| `ingress.certManager.clusterIssuer` | ClusterIssuer name | `letsencrypt-prod` |
| `ingress.certManager.email` | ACME email | `""` |
| `ingress.certManager.createClusterIssuers` | Create ClusterIssuers | `false` |

### AWS ALB

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.alb.scheme` | ALB scheme | `internet-facing` |
| `ingress.alb.targetType` | Target type | `ip` |
| `ingress.alb.certificateArn` | ACM certificate ARN | `""` |
| `ingress.alb.healthcheckPath` | Health check path | `/health` |
| `ingress.alb.securityGroups` | Security groups | `""` |
| `ingress.alb.wafAclArn` | WAF ACL ARN | `""` |

### Azure AGIC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.agic.wafPolicyId` | WAF policy ID | `""` |
| `ingress.agic.cookieBasedAffinity` | Cookie affinity | `false` |

---

## Network Policies

| Parameter | Description | Default |
|-----------|-------------|---------|
| `networkPolicies.enabled` | Enable NetworkPolicies | `true` |

---

## CronJobs

### ECR Token Refresher

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cronjobs.ecrTokenRefresher.enabled` | Enable ECR token refresher | `true` |
| `cronjobs.ecrTokenRefresher.schedule` | Cron schedule | `0 */8 * * *` |
| `cronjobs.ecrTokenRefresher.image` | AWS CLI image | `amazon/aws-cli:latest` |

### ACR Token Refresher

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cronjobs.acrTokenRefresher.enabled` | Enable ACR token refresher | `false` |
| `cronjobs.acrTokenRefresher.schedule` | Cron schedule | `0 */8 * * *` |
| `cronjobs.acrTokenRefresher.image` | Azure CLI image | `mcr.microsoft.com/azure-cli:latest` |

---

## Secrets

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secrets.method` | Secrets method (inline, sops, external-secrets) | `inline` |

### External Secrets

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secrets.externalSecrets.enabled` | Enable External Secrets | `false` |
| `secrets.externalSecrets.secretStore` | Secret store name | `aws-secrets-manager` |
| `secrets.externalSecrets.refreshInterval` | Refresh interval | `1h` |

### Inline Secrets Data

| Parameter | Description |
|-----------|-------------|
| `secrets.data.postgresql.rootPassword` | PostgreSQL root password |
| `secrets.data.postgresql.userPassword` | PostgreSQL user password |
| `secrets.data.postgresql.databaseUrl` | Full database URL |
| `secrets.data.mongodb.rootPassword` | MongoDB root password |
| `secrets.data.mongodb.userPassword` | MongoDB user password |
| `secrets.data.rabbitmq.password` | RabbitMQ password |
| `secrets.data.opensearch.adminPassword` | OpenSearch admin password |
| `secrets.data.application.authSecret` | NextAuth secret |
| `secrets.data.smtp.username` | SMTP username |
| `secrets.data.smtp.password` | SMTP password |
| `secrets.data.aws.s3AccessKey` | S3 access key |
| `secrets.data.aws.s3SecretKey` | S3 secret key |
| `secrets.data.aws.ecrAccessKeyId` | ECR access key ID |
| `secrets.data.aws.ecrSecretAccessKey` | ECR secret access key |
| `secrets.data.google.clientId` | Google OAuth client ID |
| `secrets.data.google.clientSecret` | Google OAuth client secret |

---

## RBAC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rbac.create` | Create RBAC resources | `true` |
| `rbac.serviceAccounts.vector.create` | Create Vector SA | `true` |
| `rbac.serviceAccounts.vector.name` | Vector SA name | `vector-sa` |
| `rbac.serviceAccounts.ecrTokenRefresher.create` | Create ECR refresher SA | `true` |
| `rbac.serviceAccounts.ecrTokenRefresher.name` | ECR refresher SA name | `ecr-token-refresher` |
| `rbac.serviceAccounts.acrTokenRefresher.create` | Create ACR refresher SA | `true` |
| `rbac.serviceAccounts.acrTokenRefresher.name` | ACR refresher SA name | `acr-token-refresher` |

---

## Autoscaling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `3` |
| `autoscaling.targetCPUUtilizationPercentage` | CPU target | `70` |
| `autoscaling.targetMemoryUtilizationPercentage` | Memory target | `80` |

---

## NodePort (Dev Only)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodePort.enabled` | Enable NodePort services | `true` |
| `nodePort.dashboard.port` | Dashboard NodePort | `30000` |
| `nodePort.socket.port` | Socket.io NodePort | `30001` |
| `nodePort.rabbitmq.port` | RabbitMQ NodePort | `30672` |