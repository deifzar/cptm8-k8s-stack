# 📦 CPTM8 Helm Chart Implementation Guide

## Directory Structure

```
helm/
└── cptm8/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-staging.yaml
    ├── values-production.yaml
    ├── templates/
    │   ├── _helpers.tpl
    │   ├── namespace.yaml
    │   ├── configmaps/
    │   │   ├── common-config.yaml
    │   │   ├── app-configs.yaml
    │   │   └── logging-config.yaml
    │   ├── secrets/
    │   │   └── secrets.yaml
    │   ├── storage/
    │   │   ├── storageclass.yaml
    │   │   └── pvcs.yaml
    │   ├── databases/
    │   │   ├── postgresql/
    │   │   │   ├── statefulset.yaml
    │   │   │   ├── service.yaml
    │   │   │   └── service-headless.yaml
    │   │   ├── mongodb/
    │   │   │   ├── statefulset.yaml
    │   │   │   ├── service.yaml
    │   │   │   └── service-headless.yaml
    │   │   ├── rabbitmq/
    │   │   │   ├── statefulset.yaml
    │   │   │   ├── service.yaml
    │   │   │   └── service-headless.yaml
    │   │   └── opensearch/
    │   │       ├── statefulset.yaml
    │   │       ├── service.yaml
    │   │       └── service-headless.yaml
    │   ├── microservices/
    │   │   ├── asmm8.yaml
    │   │   ├── naabum8.yaml
    │   │   ├── katanam8.yaml
    │   │   ├── num8.yaml
    │   │   ├── orchestratorm8.yaml
    │   │   └── reportingm8.yaml
    │   ├── frontend/
    │   │   ├── dashboardm8.yaml
    │   │   └── socketm8.yaml
    │   ├── monitoring/
    │   │   ├── vector.yaml
    │   │   └── servicemonitor.yaml
    │   ├── ingress/
    │   │   └── ingress.yaml
    │   ├── cronjobs/
    │   │   ├── ecr-token-refresher.yaml
    │   │   └── mongodb-init.yaml
    │   ├── rbac/
    │   │   ├── serviceaccounts.yaml
    │   │   ├── roles.yaml
    │   │   └── rolebindings.yaml
    │   ├── autoscaling/
    │   │   └── hpa.yaml
    │   └── networkpolicies/
    │       └── network-policies.yaml
    └── charts/
        └── (external chart dependencies)
```

## Chart.yaml

```yaml
apiVersion: v2
name: cptm8
description: CPTM8 Continuous Penetration Testing Platform
type: application
version: 1.0.0
appVersion: "2024.1"
home: https://github.com/deifzar/cptm8
maintainers:
  - name: Deifzar
    email: deifzar@cptm8.net
dependencies:
  # Optional: Use external charts for databases
  # Uncomment to use Bitnami charts instead of custom StatefulSets
  # - name: postgresql
  #   version: 12.1.0
  #   repository: https://charts.bitnami.com/bitnami
  #   condition: postgresql.enabled
  # - name: mongodb
  #   version: 13.6.0
  #   repository: https://charts.bitnami.com/bitnami
  #   condition: mongodb.enabled
  # - name: rabbitmq
  #   version: 11.9.0
  #   repository: https://charts.bitnami.com/bitnami
  #   condition: rabbitmq.enabled
```

## values.yaml (Default Values)

```yaml
# Global values
global:
  environment: development
  domain: cptm8.local
  
  # Image registry settings
  imageRegistry: 123456789012.dkr.ecr.us-east-1.amazonaws.com
  imagePullSecrets:
    - ecr-registry-secret
  
  # Storage settings
  storageClass: local-storage
  
  # Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    
  # Resource defaults
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

# Namespace configuration
namespace:
  create: true
  name: cptm8-dev

# RBAC configuration
rbac:
  create: true
  serviceAccounts:
    - name: vector-sa
      rules:
        - apiGroups: [""]
          resources: ["pods", "nodes"]
          verbs: ["get", "list", "watch"]
    - name: ecr-token-refresher
      rules:
        - apiGroups: [""]
          resources: ["secrets"]
          verbs: ["get", "create", "patch", "delete"]

# Database configurations
postgresql:
  enabled: true
  replicaCount: 1
  image:
    repository: postgres
    tag: "16-alpine"
  auth:
    database: cptm8
    username: cptm8_user
    existingSecret: postgresql-secrets
  persistence:
    enabled: true
    size: 2Gi
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "500m"

mongodb:
  enabled: true
  replicaCount: 1
  image:
    repository: mongo
    tag: "7.0"
  auth:
    enabled: true
    database: cptm8_chat
    existingSecret: mongodb-secrets
  persistence:
    enabled: true
    size: 5Gi
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "500m"

rabbitmq:
  enabled: true
  replicaCount: 1
  image:
    repository: rabbitmq
    tag: "3.12-management-alpine"
  auth:
    existingSecret: rabbitmq-secrets
  persistence:
    enabled: true
    size: 2Gi
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "500m"

opensearch:
  enabled: true
  replicaCount: 1
  image:
    repository: opensearchproject/opensearch
    tag: "2.11.0"
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"

# Microservices configurations
microservices:
  asmm8:
    enabled: true
    replicaCount: 1
    image:
      repository: cptm8/asmm8
      tag: latest
    service:
      port: 8000
    configFiles:
      - name: subfinderconfig.yaml
        content: |
          # Subfinder configuration
      - name: subfinderprovider-config.yaml
        content: |
          # Provider configuration
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  naabum8:
    enabled: true
    replicaCount: 1
    image:
      repository: cptm8/naabum8
      tag: latest
    service:
      port: 8001
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  katanam8:
    enabled: true
    replicaCount: 1
    image:
      repository: cptm8/katanam8
      tag: latest
    service:
      port: 8002
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  num8:
    enabled: true
    replicaCount: 1
    image:
      repository: cptm8/num8
      tag: latest
    service:
      port: 8003
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  orchestratorm8:
    enabled: true
    replicaCount: 1
    image:
      repository: cptm8/orchestratorm8
      tag: latest
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
  
  reportingm8:
    enabled: true
    schedule: "0 0 1 * *"  # Monthly
    image:
      repository: cptm8/reportingm8
      tag: latest

# Frontend configurations
frontend:
  dashboardm8:
    enabled: true
    replicaCount: 1
    image:
      repository: cptm8/dashboardm8
      tag: latest
    service:
      port: 3000
      type: ClusterIP
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  socketm8:
    enabled: true
    replicaCount: 1
    image:
      repository: cptm8/socketm8
      tag: latest
    service:
      port: 4000
      type: ClusterIP
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"

# Monitoring
monitoring:
  vector:
    enabled: true
    image:
      repository: timberio/vector
      tag: latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"

# Ingress configuration
ingress:
  enabled: false
  className: nginx
  annotations: {}
  hosts:
    - host: dashboard.cptm8.local
      paths:
        - path: /
          service: dashboardm8
          port: 3000
    - host: api.cptm8.local
      paths:
        - path: /
          service: socketm8
          port: 4000
  tls: []

# Autoscaling
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Network policies
networkPolicies:
  enabled: false
  policyType: "basic"  # basic, strict, custom

# CronJobs
cronjobs:
  ecrTokenRefresher:
    enabled: true
    schedule: "0 */8 * * *"
    image:
      repository: amazon/aws-cli
      tag: latest
```

## values-staging.yaml

```yaml
# Staging-specific values
global:
  environment: staging
  domain: staging.cptm8.net
  storageClass: staging-gp3-retain
  
  # Staging resource defaults
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "500m"

namespace:
  name: cptm8-staging

# Scale up for staging
postgresql:
  persistence:
    size: 50Gi
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

mongodb:
  persistence:
    size: 100Gi
  replicaCount: 1
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

rabbitmq:
  persistence:
    size: 30Gi
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

opensearch:
  replicaCount: 3
  persistence:
    size: 200Gi
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"

# Scale microservices for staging
microservices:
  asmm8:
    replicaCount: 2
    image:
      tag: staging-latest
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
  
  naabum8:
    replicaCount: 2
    image:
      tag: staging-latest
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
  
  katanam8:
    replicaCount: 2
    image:
      tag: staging-latest
  
  num8:
    replicaCount: 2
    image:
      tag: staging-latest
  
  orchestratorm8:
    replicaCount: 2
    image:
      tag: staging-latest

frontend:
  dashboardm8:
    replicaCount: 2
    image:
      tag: staging-latest
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
  
  socketm8:
    replicaCount: 2
    image:
      tag: staging-latest
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"

# Enable ingress for staging
ingress:
  enabled: true
  className: alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxx
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/healthcheck-path: /health
  hosts:
    - host: dashboard-staging.cptm8.net
      paths:
        - path: /
          service: dashboardm8
          port: 3000
    - host: api-staging.cptm8.net
      paths:
        - path: /
          service: socketm8
          port: 4000
  tls:
    - secretName: staging-tls
      hosts:
        - dashboard-staging.cptm8.net
        - api-staging.cptm8.net

# Enable autoscaling for staging
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Enable network policies for staging
networkPolicies:
  enabled: true
  policyType: "basic"
```

## Key Helm Templates

### templates/_helpers.tpl

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "cptm8.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cptm8.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cptm8.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cptm8.labels" -}}
helm.sh/chart: {{ include "cptm8.chart" . }}
{{ include "cptm8.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cptm8.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cptm8.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cptm8.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cptm8.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for HPA
*/}}
{{- define "cptm8.hpa.apiVersion" -}}
{{- if semverCompare ">=1.23-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "autoscaling/v2" -}}
{{- else -}}
{{- print "autoscaling/v2beta2" -}}
{{- end -}}
{{- end -}}
```

### templates/microservices/asmm8.yaml

```yaml
{{- if .Values.microservices.asmm8.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asmm8
  namespace: {{ .Values.namespace.name }}
  labels:
    app: asmm8
    tier: application
    {{- include "cptm8.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.microservices.asmm8.replicaCount }}
  selector:
    matchLabels:
      app: asmm8
      {{- include "cptm8.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        app: asmm8
        tier: application
        {{- include "cptm8.labels" . | nindent 8 }}
    spec:
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.global.securityContext | nindent 8 }}
      
      # Init container to copy configs (ConfigMap + emptyDir pattern)
      initContainers:
      - name: fix-app-ownership
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          cp -r /config-templates/* /config-writable/
          chown -R {{ .Values.global.securityContext.runAsUser }}:{{ .Values.global.securityContext.fsGroup }} /config-writable
        volumeMounts:
        - name: config-volume
          mountPath: /config-templates
        - name: config-writable
          mountPath: /config-writable
      
      containers:
      - name: asmm8
        image: "{{ .Values.global.imageRegistry }}/{{ .Values.microservices.asmm8.image.repository }}:{{ .Values.microservices.asmm8.image.tag }}"
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: {{ .Values.microservices.asmm8.service.port }}
          protocol: TCP
        
        env:
        - name: ENVIRONMENT
          value: {{ .Values.global.environment }}
        - name: POSTGRESQL_HOSTNAME
          value: "postgresql-service.{{ .Values.namespace.name }}.svc.cluster.local"
        - name: POSTGRESQL_PORT
          value: "5432"
        - name: POSTGRESQL_DB
          value: "cptm8"
        - name: POSTGRESQL_USERNAME
          valueFrom:
            secretKeyRef:
              name: postgresql-secrets
              key: username
        - name: POSTGRESQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-secrets
              key: password
        - name: RABBITMQ_HOSTNAME
          value: "rabbitmq-service.{{ .Values.namespace.name }}.svc.cluster.local"
        - name: RABBITMQ_PORT
          value: "5672"
        - name: RABBITMQ_USERNAME
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secrets
              key: username
        - name: RABBITMQ_PASSWORD
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secrets
              key: password
        
        volumeMounts:
        {{- range .Values.microservices.asmm8.configFiles }}
        - name: config-writable
          mountPath: /app/configs/{{ .name }}
          subPath: {{ .name }}
        {{- end }}
        - name: logs
          mountPath: /var/log/asmm8
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /home/appuser/.cache
        
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        resources:
          {{- toYaml .Values.microservices.asmm8.resources | nindent 10 }}
      
      volumes:
      - name: config-volume
        configMap:
          name: configuration-template-asmm8
      - name: config-writable
        emptyDir: {}
      - name: logs
        persistentVolumeClaim:
          claimName: asmm8-logs-pvc
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: asmm8-service
  namespace: {{ .Values.namespace.name }}
  labels:
    app: asmm8
    {{- include "cptm8.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    app: asmm8
    {{- include "cptm8.selectorLabels" . | nindent 4 }}
  ports:
  - port: {{ .Values.microservices.asmm8.service.port }}
    targetPort: http
    protocol: TCP
    name: http
---
{{- if .Values.autoscaling.enabled }}
apiVersion: {{ include "cptm8.hpa.apiVersion" . }}
kind: HorizontalPodAutoscaler
metadata:
  name: asmm8-hpa
  namespace: {{ .Values.namespace.name }}
  labels:
    {{- include "cptm8.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: asmm8
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
{{- end }}
{{- end }}
```

## Deployment Commands

```bash
# Install Helm (if not already installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Package the chart
cd helm/cptm8
helm dependency update
helm package .

# Deploy to staging
helm install cptm8-staging . \
  -f values.yaml \
  -f values-staging.yaml \
  --namespace cptm8-staging \
  --create-namespace

# Upgrade with new values
helm upgrade cptm8-staging . \
  -f values.yaml \
  -f values-staging.yaml \
  --namespace cptm8-staging

# Check status
helm status cptm8-staging -n cptm8-staging

# View values being used
helm get values cptm8-staging -n cptm8-staging

# Rollback if needed
helm rollback cptm8-staging 1 -n cptm8-staging

# Uninstall
helm uninstall cptm8-staging -n cptm8-staging
```

## GitOps with ArgoCD

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cptm8-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/deifzar/cptm8
    targetRevision: staging
    path: helm/cptm8
    helm:
      valueFiles:
        - values.yaml
        - values-staging.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: cptm8-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## Benefits of Helm Over Kustomize

1. **Templating**: Full templating with conditionals and loops
2. **Package Management**: Charts can be versioned and distributed
3. **Dependencies**: Manage external charts as dependencies
4. **Rollback**: Built-in rollback capabilities
5. **Values Inheritance**: Layer values files for different environments
6. **Hooks**: Pre/post install/upgrade/delete hooks
7. **Testing**: Built-in testing framework
8. **Documentation**: Self-documenting with NOTES.txt

---

This Helm chart provides a production-ready, templated approach to deploying your CPTM8 platform across multiple environments with consistent configuration management.
