{{/*
Environment helper - uses global or default'
*/}}
{{- define "cptm8.environment" -}}
{{- if .Values.global }}
{{- .Values.global.environment | default "dev" }}
{{- else }}
{{- "dev" }}
{{- end }}
{{- end }}

{{/*
Namespace helper - uses global.namespace or Release.Namespace
*/}}
{{- define "cptm8.namespace" -}}
{{- printf "cptm8-%s" (include "cptm8.environment" .) | default .Release.Namespace }}
{{- end }}

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
Image pull secrets
*/}}
{{- define "cptm8.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- toYaml .Values.global.imagePullSecrets | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Service DNS suffix
*/}}
{{- define "cptm8.serviceDnsSuffix" -}}
.{{ include "cptm8.namespace" . }}.svc.cluster.local
{{- end }}

{{/*
Full service hostname
Usage: {{ include "cptm8.serviceHostname" (dict "service" "postgresql-service" "ctx" .) }}
*/}}
{{- define "cptm8.serviceHostname" -}}
{{- $service := .service -}}
{{- $ctx := .ctx -}}
{{- printf "%s%s" $service (include "cptm8.serviceDnsSuffix" $ctx) }}
{{- end }}

{{/*
Scanner labels
Usage: {{ include "cptm8.scannerLabels" (dict "name" "asmm8" "ctx" .) }}
*/}}
{{- define "cptm8.scannerLabels" -}}
app: {{ .name }}
tier: application
component: scanner
{{ include "cptm8.labels" .ctx }}
{{- end }}

{{/*
Scanner selector labels
*/}}
{{- define "cptm8.scannerSelectorLabels" -}}
app: {{ .name }}
{{- end }}

{{/*
Reporting labels
Usage: {{ include "cptm8.reportingLabels" (dict "name" "reportingm8" "ctx" .) }}
*/}}
{{- define "cptm8.reportingLabels" -}}
app: {{ .name }}
tier: application
component: reporting
{{ include "cptm8.labels" .ctx }}
{{- end }}

{{/*
Reporting selector labels
*/}}
{{- define "cptm8.reportingSelectorLabels" -}}
app: {{ .name }}
{{- end }}

{{/*
Frontend labels
*/}}
{{- define "cptm8.frontendLabels" -}}
app: {{ .name }}
tier: application
component: frontend
{{ include "cptm8.labels" .ctx }}
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "cptm8.frontendSelectorLabels" -}}
app: {{ .name }}
{{- end }}

{{/*
Database labels
*/}}
{{- define "cptm8.databaseLabels" -}}
app: {{ .name }}
tier: data
{{ include "cptm8.labels" .ctx }}
{{- end }}

{{/*
Database selector labels
*/}}
{{- define "cptm8.databaseSelectorLabels" -}}
app: {{ .name }}
{{- end }}

{{/*
Logging labels
*/}}
{{- define "cptm8.loggingLabels" -}}
app: {{ .name }}
tier: logging
{{ include "cptm8.labels" .ctx }}
{{- end }}

{{/*
Logging selector labels
*/}}
{{- define "cptm8.loggingSelectorLabels" -}}
app: {{ .name }}
{{- end }}

{{/*
Messaging labels
*/}}
{{- define "cptm8.messagingLabels" -}}
app: {{ .name }}
tier: messaging
{{ include "cptm8.labels" .ctx }}
{{- end }}

{{/*
Messaging selector labels
*/}}
{{- define "cptm8.messagingSelectorLabels" -}}
app: {{ .name }}
{{- end }}

{{/*
Common environment variables for all services
*/}}
{{- define "cptm8.commonEnvVars" -}}
- name: RABBITMQ_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: RABBITMQ_HOSTNAME
- name: RABBITMQ_PORT
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: RABBITMQ_PORT
- name: POSTGRESQL_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: POSTGRESQL_HOSTNAME
- name: POSTGRESQL_PORT
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: POSTGRESQL_PORT
- name: POSTGRESQL_USERNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: POSTGRESQL_NON_ROOT_USERNAME
- name: POSTGRESQL_DB
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: POSTGRESQL_DB
- name: POSTGRESQL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgresql-secrets
      key: postgresql-user-password
- name: RABBITMQ_USERNAME
  valueFrom:
    secretKeyRef:
      name: rabbitmq-secrets
      key: rabbitmq-username
- name: RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: rabbitmq-secrets
      key: rabbitmq-password
- name: OPENSEARCH_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: OPENSEARCH_HOSTNAME
- name: OPENSEARCH_PORT
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: OPENSEARCH_PORT
{{- end }}

{{/*
Scanner pipeline environment variables
Each scanner knows its downstream consumer
*/}}
{{- define "cptm8.scannerPipelineEnvVars" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- if eq $name "asmm8" }}
- name: NAABUM8_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NAABUM8_HOSTNAME
- name: NAABUM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NAABUM8_URL
{{- else if eq $name "naabum8" }}
- name: KATANAM8_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: KATANAM8_HOSTNAME
- name: KATANAM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: KATANAM8_URL
{{- else if eq $name "katanam8" }}
- name: NUM8_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NUM8_HOSTNAME
- name: NUM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NUM8_URL
{{- else if eq $name "num8" }}
- name: ASMM8_HOSTNAME
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: ASMM8_HOSTNAME
- name: ASMM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: ASMM8_URL
{{- else if eq $name "orchestratorm8" }}
- name: ASMM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: ASMM8_URL
- name: NAABUM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NAABUM8_URL
- name: KATANAM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: KATANAM8_URL
- name: NUM8_URL
  valueFrom:
    configMapKeyRef:
      name: cptm8-config
      key: NUM8_URL
{{- end }}
{{- end }}

{{/*
Get image tag - uses service-specific or falls back to global
*/}}
{{- define "cptm8.imageTag" -}}
{{- $serviceTag := .serviceTag -}}
{{- $globalTag := .globalTag -}}
{{- if $serviceTag }}
{{- $serviceTag }}
{{- else }}
{{- $globalTag }}
{{- end }}
{{- end }}

{{/*
Full image reference
Usage: {{ include "cptm8.image" (dict "registry" .Values.global.imageRegistry "name" "asmm8" "tag" $tag) }}
*/}}
{{- define "cptm8.image" -}}
{{- printf "%s/cptm8/%s:%s" .registry .name .tag }}
{{- end }}
