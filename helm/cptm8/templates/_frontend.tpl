{{/*
=============================================================================
FRONTEND DEPLOYMENT TEMPLATE
=============================================================================
Renders a complete Deployment for Node.js frontend services.

Usage:
  {{- include "cptm8.frontendDeployment" (dict "name" "dashboardm8" "ctx" .) }}

Parameters:
  - name: Service name ("dashboardm8" or "socketm8")
  - ctx: Root context (.)

Services:
  - dashboardm8: Next.js dashboard (port 3000)
  - socketm8: Socket.io WebSocket server (port 4000)
*/}}
{{- define "cptm8.frontendDeployment" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- $frontend := index $ctx.Values.frontend $name -}}
{{- $port := $frontend.port -}}
{{- $tag := include "cptm8.imageTag" (dict "serviceTag" $frontend.image.tag "globalTag" $ctx.Values.global.imageTag) -}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}
  namespace: {{ include "cptm8.namespace" $ctx }}
  labels:
    {{- include "cptm8.frontendLabels" (dict "name" $name "ctx" $ctx) | nindent 4 }}
spec:
  replicas: {{ $frontend.replicaCount | default 1 }}
  selector:
    matchLabels:
      {{- include "cptm8.frontendSelectorLabels" (dict "name" $name) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "cptm8.frontendLabels" (dict "name" $name "ctx" $ctx) | nindent 8 }}
      annotations:
        # Checksum triggers pod restart when config changes
        checksum/config: {{ $ctx.Values.config | toYaml | sha256sum | trunc 8 }}
    spec:
      {{- include "cptm8.imagePullSecrets" $ctx | nindent 6 }}

      containers:
      - name: {{ $name }}
        image: {{ include "cptm8.image" (dict "registry" $ctx.Values.global.imageRegistry "name" $name "tag" $tag) }}
        imagePullPolicy: {{ $ctx.Values.global.imagePullPolicy }}

        # Environment variables
        env:
        {{- include "cptm8.frontendCommonEnvVars" $ctx | nindent 8 }}
        {{- include "cptm8.frontendSelfEnvVars" (dict "name" $name "ctx" $ctx) | nindent 8 }}
        {{- if eq $name "dashboardm8" }}
        {{- include "cptm8.dashboardEnvVars" $ctx | nindent 8 }}
        {{- else if eq $name "socketm8" }}
        {{- include "cptm8.socketEnvVars" $ctx | nindent 8 }}
        {{- end }}
        {{- include "cptm8.frontendSecretEnvVars" (dict "name" $name "ctx" $ctx) | nindent 8 }}

        ports:
        - containerPort: {{ $port }}
          name: http
          protocol: TCP

        # Health probes
        {{- include "cptm8.frontendProbes" (dict "name" $name "port" $port "ctx" $ctx) | nindent 8 }}

        # Security context
        securityContext:
          {{- include "cptm8.frontendSecurityContext" (dict "name" $name "ctx" $ctx) | nindent 10 }}

        # Resources
        {{- $resources := $frontend.resources | default $ctx.Values.global.resources.frontend }}
        {{- if $resources }}
        resources:
          {{- toYaml $resources | nindent 10 }}
        {{- end }}

        # Volume mounts
        volumeMounts:
        {{- include "cptm8.frontendVolumeMounts" (dict "name" $name "ctx" $ctx) | nindent 8 }}

      # Volumes
      volumes:
      {{- include "cptm8.frontendVolumes" (dict "name" $name "ctx" $ctx) | nindent 6 }}

      # Pod security context
      securityContext:
        {{- include "cptm8.frontendPodSecurityContext" (dict "name" $name "ctx" $ctx) | nindent 8 }}
{{- end }}

{{/*
=============================================================================
FRONTEND COMMON ENVIRONMENT VARIABLES
=============================================================================
Environment variables shared by all frontend services
*/}}
{{- define "cptm8.frontendCommonEnvVars" -}}
- name: NODE_ENV
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NODE_ENV
- name: POSTGRESQL_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: POSTGRESQL_HOSTNAME
- name: SMTP_SERVER
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: SMTP_SERVER
- name: SMTP_EMAILSENDER
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: SMTP_EMAILSENDER
- name: NEXT_DASHBOARD_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NEXT_DASHBOARD_URL
- name: USER_EMAIL_DOMAIN
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: USER_EMAIL_DOMAIN
{{- end }}

{{/*
=============================================================================
FRONTEND SELF ENVIRONMENT VARIABLES
=============================================================================
Each frontend needs its own hostname and port
*/}}
{{- define "cptm8.frontendSelfEnvVars" -}}
{{- $name := .name -}}
{{- $upperName := upper $name -}}
- name: {{ $upperName }}_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: {{ $upperName }}_HOSTNAME
- name: PORT
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: {{ $upperName }}_PORT
{{- end }}

{{/*
=============================================================================
DASHBOARD-SPECIFIC ENVIRONMENT VARIABLES
=============================================================================
*/}}
{{- define "cptm8.dashboardEnvVars" -}}
- name: SMTP_PORT
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: SMTP_PORT
- name: CLOUD_PROVIDER
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: CLOUD_PROVIDER
# AuthJS/NextAuth URL configuration
- name: AUTH_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: AUTH_URL
- name: NEXTAUTH_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NEXTAUTH_URL
{{- end }}

{{/*
=============================================================================
SOCKET-SPECIFIC ENVIRONMENT VARIABLES
=============================================================================
*/}}
{{- define "cptm8.socketEnvVars" -}}
- name: RabbitMQ_EXCHANGE
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: RabbitMQ_EXCHANGE
- name: CORS
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: CORS
{{- end }}

{{/*
=============================================================================
FRONTEND SECRET ENVIRONMENT VARIABLES
=============================================================================
Service-specific secrets
*/}}
{{- define "cptm8.frontendSecretEnvVars" -}}
{{- $name := .name -}}
# Database URLs
- name: PPG_DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: postgresql-secrets
      key: postgresql-database-url
- name: PMG_DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: mongodb-secrets
      key: mongodb-database-url
{{- if eq $name "dashboardm8" }}
# Auth secrets (dashboard only)
- name: AUTH_SECRET
  valueFrom:
    secretKeyRef:
      name: application-secrets
      key: auth-secret
- name: GOOGLE_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: google-secrets
      key: google-client-id
- name: GOOGLE_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: google-secrets
      key: google-client-secret
# AWS S3 credentials (dashboard only)
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
{{- else if eq $name "socketm8" }}
# RabbitMQ URL (socket only)
- name: RabbitMQ_URL
  valueFrom:
    secretKeyRef:
      name: rabbitmq-secrets
      key: rabbitmq-url
{{- end }}
# SMTP credentials (both)
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
{{- end }}

{{/*
=============================================================================
FRONTEND VOLUME MOUNTS
=============================================================================
*/}}
{{- define "cptm8.frontendVolumeMounts" -}}
{{- $name := .name -}}
# Override docker-entrypoint.sh with Kubernetes-compatible version
- name: entrypoint-override
  mountPath: /usr/local/bin/docker-entrypoint.sh
  subPath: docker-entrypoint.sh
  readOnly: true
{{- end }}

{{/*
=============================================================================
FRONTEND VOLUMES
=============================================================================
*/}}
{{- define "cptm8.frontendVolumes" -}}
{{- $name := .name -}}
# ConfigMap with Kubernetes-compatible docker-entrypoint.sh
- name: entrypoint-override
  configMap:
    name: docker-entrypoint-{{ $name }}-frontend
    defaultMode: 0755
{{- end }}
