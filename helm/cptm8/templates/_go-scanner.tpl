{{/*
=============================================================================
GO SCANNER DEPLOYMENT TEMPLATE
=============================================================================
Renders a complete Deployment for Go-based microservices (scanners, orchestrator, reporting).

Usage:
  {{- include "cptm8.goScannerDeployment" (dict "name" "asmm8" "ctx" .) }}

Parameters:
  - name: Service name (e.g., "asmm8", "naabum8", "orchestratorm8", "reportingm8")
  - ctx: Root context (.)

Supported services:
  - Scanners: asmm8, naabum8, katanam8, num8, orchestratorm8
  - Reporting: reportingm8

Special handling:
  - naabum8: Privileged mode for port scanning
  - num8: Additional nuclei-templates volume
  - orchestratorm8: Read-only root filesystem
  - reportingm8: Additional SMTP and AWS S3 secrets
*/}}
{{- define "cptm8.goScannerDeployment" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- $isReporting := eq $name "reportingm8" -}}
{{- $serviceConfig := ternary (index $ctx.Values.reporting $name) (index $ctx.Values.scanners $name) $isReporting -}}
{{- $port := $serviceConfig.port -}}
{{- $componentType := ternary "reporting" "scanner" $isReporting -}}
{{- $tag := include "cptm8.imageTag" (dict "serviceTag" $serviceConfig.image.tag "globalTag" $ctx.Values.global.imageTag) -}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}
  namespace: {{ include "cptm8.namespace" $ctx }}
  labels:
    {{- if $isReporting }}
    {{- include "cptm8.reportingLabels" (dict "name" $name "ctx" $ctx) | nindent 4 }}
    {{- else }}
    {{- include "cptm8.scannerLabels" (dict "name" $name "ctx" $ctx) | nindent 4 }}
    {{- end }}
spec:
  replicas: {{ $serviceConfig.replicaCount | default 1 }}
  selector:
    matchLabels:
      {{- if $isReporting }}
      {{- include "cptm8.reportingSelectorLabels" (dict "name" $name) | nindent 6 }}
      {{- else }}
      {{- include "cptm8.scannerSelectorLabels" (dict "name" $name) | nindent 6 }}
      {{- end }}
  template:
    metadata:
      labels:
        {{- if $isReporting }}
        {{- include "cptm8.reportingLabels" (dict "name" $name "ctx" $ctx) | nindent 8 }}
        {{- else }}
        {{- include "cptm8.scannerLabels" (dict "name" $name "ctx" $ctx) | nindent 8 }}
        {{- end }}
      annotations:
        # Checksum triggers pod restart when config changes
        checksum/config: {{ $ctx.Values.config | toYaml | sha256sum | trunc 8 }}
    spec:
      {{- include "cptm8.imagePullSecrets" $ctx | nindent 6 }}
      serviceAccountName: {{ $ctx.Values.rbac.serviceAccounts.vector.name | default "default" }}

      # Init container to prepare writable directories
      initContainers:
        {{- include "cptm8.goScannerInitContainer" (dict "name" $name "ctx" $ctx) | nindent 8 }}

      containers:
      - name: {{ $name }}
        image: {{ include "cptm8.image" (dict "registry" $ctx.Values.global.imageRegistry "name" $name "tag" $tag) }}
        imagePullPolicy: {{ $ctx.Values.global.imagePullPolicy }}

        # Environment variables
        env:
        - name: SERVICEM8_NAME
          value: {{ $name | quote }}
        - name: HOME
          value: "/app"
        {{- include "cptm8.commonEnvVars" $ctx | nindent 8 }}
        {{- include "cptm8.scannerSelfEnvVars" (dict "name" $name "ctx" $ctx) | nindent 8 }}
        {{- include "cptm8.scannerPipelineEnvVars" (dict "name" $name "ctx" $ctx) | nindent 8 }}
        {{- if $isReporting }}
        {{- include "cptm8.reportingEnvVars" $ctx | nindent 8 }}
        {{- end }}

        ports:
        - containerPort: {{ $port }}
          name: http
          protocol: TCP

        # Health probes
        {{- include "cptm8.goScannerProbes" (dict "name" $name "port" $port "ctx" $ctx) | nindent 8 }}

        # Security context
        securityContext:
          {{- include "cptm8.goScannerSecurityContext" (dict "name" $name "ctx" $ctx) | nindent 10 }}

        # Resources
        {{- $resources := $serviceConfig.resources | default $ctx.Values.global.resources.scanner }}
        {{- if $resources }}
        resources:
          {{- toYaml $resources | nindent 10 }}
        {{- end }}

        # Volume mounts
        volumeMounts:
        {{- include "cptm8.goScannerVolumeMounts" (dict "name" $name "ctx" $ctx) | nindent 8 }}

      # Volumes
      volumes:
      {{- include "cptm8.goScannerVolumes" (dict "name" $name "ctx" $ctx) | nindent 6 }}

      # Pod security context
      securityContext:
        {{- include "cptm8.goScannerPodSecurityContext" $ctx | nindent 8 }}
{{- end }}

{{/*
=============================================================================
SCANNER SELF ENVIRONMENT VARIABLES
=============================================================================
Each scanner needs its own hostname and URL env vars
*/}}
{{- define "cptm8.scannerSelfEnvVars" -}}
{{- $name := .name -}}
{{- $upperName := upper $name -}}
- name: {{ $upperName }}_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: {{ $upperName }}_HOSTNAME
- name: {{ $upperName }}_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: {{ $upperName }}_URL
{{- end }}

{{/*
=============================================================================
REPORTING-SPECIFIC ENVIRONMENT VARIABLES
=============================================================================
Additional secrets for reportingm8 (SMTP, AWS S3)
*/}}
{{- define "cptm8.reportingEnvVars" -}}
- name: SMTP_USERNAME
  valueFrom:
    secretKeyRef:
      name: smtp-secrets
      key: smtp-username
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: smtp-secrets
      key: smtp-password
- name: AWS_KEY
  valueFrom:
    secretKeyRef:
      name: aws-s3-credentials
      key: aws-key
- name: AWS_SECRET
  valueFrom:
    secretKeyRef:
      name: aws-s3-credentials
      key: aws-secret
{{- end }}

{{/*
=============================================================================
GO SCANNER VOLUME MOUNTS
=============================================================================
Standard volume mounts plus service-specific ones
*/}}
{{- define "cptm8.goScannerVolumeMounts" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
# Writable config directory (populated by init container)
- name: config-writable
  mountPath: /app/configs
# Persistent log volume
- name: log-volume
  mountPath: /app/log
# Temporary directory (ephemeral)
- name: tmp-volume
  mountPath: /app/tmp
# Config directory for tools (ephemeral)
- name: config-dir-volume
  mountPath: /app/.config
  readOnly: false
# Kubernetes-compatible docker-entrypoint.sh override
- name: entrypoint-override
  mountPath: /usr/local/bin/docker-entrypoint.sh
  subPath: docker-entrypoint.sh
  readOnly: true
{{- if eq $name "num8" }}
# Nuclei templates directory
- name: dir-nuclei-templates
  mountPath: /app/nuclei-templates
{{- end }}
{{- end }}

{{/*
=============================================================================
GO SCANNER VOLUMES
=============================================================================
Standard volumes plus service-specific ones
*/}}
{{- define "cptm8.goScannerVolumes" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
# Writable emptyDir for configuration files
- name: config-writable
  emptyDir: {}
# ConfigMap with service-specific config templates
- name: config-volume
  configMap:
    name: configuration-template-{{ $name }}
    defaultMode: 0644
# Persistent log volume
- name: log-volume
  persistentVolumeClaim:
    claimName: {{ $name }}-logs-pvc
# Temporary directory
- name: tmp-volume
  emptyDir: {}
# Config directory for tools
- name: config-dir-volume
  emptyDir: {}
# Kubernetes-compatible docker-entrypoint.sh
- name: entrypoint-override
  configMap:
    name: docker-entrypoint-backend
    defaultMode: 0755
{{- if eq $name "num8" }}
# Nuclei templates directory
- name: dir-nuclei-templates
  emptyDir: {}
{{- end }}
{{- end }}

{{/*
=============================================================================
GO SCANNER PVC TEMPLATE
=============================================================================
Renders a PersistentVolumeClaim for scanner logs

Usage:
  {{- include "cptm8.goScannerPVC" (dict "name" "asmm8" "ctx" .) }}
*/}}
{{- define "cptm8.goScannerPVC" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ $name }}-logs-pvc
  namespace: {{ include "cptm8.namespace" $ctx }}
  labels:
    app: {{ $name }}
    {{- include "cptm8.labels" $ctx | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: {{ $ctx.Values.global.logsStorageClass | default $ctx.Values.global.storageClass }}
  resources:
    requests:
      storage: 1Gi
{{- end }}
