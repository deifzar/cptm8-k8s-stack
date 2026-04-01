{{/*
Get environment from global or default
*/}}
{{- define "postgresql.environment" -}}
{{- if .Values.global }}
{{- .Values.global.environment | default "dev" }}
{{- else }}
{{- "dev" }}
{{- end }}
{{- end }}

{{/*
Get the namespace
*/}}
{{- define "postgresql.namespace" -}}
{{- printf "cptm8-%s" (include "postgresql.environment" .) | default .Release.Namespace }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "postgresql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "postgresql.fullname" -}}
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
{{- define "postgresql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "postgresql.labels" -}}
helm.sh/chart: {{ include "postgresql.chart" . }}
{{ include "postgresql.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
tier: data
{{- end }}

{{/*
Selector labels
*/}}
{{- define "postgresql.selectorLabels" -}}
app: {{ include "postgresql.fullname" . }}
app.kubernetes.io/name: {{ include "postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get the storage class - uses global.storage.primaryClass if set, otherwise subchart value
PostgreSQL uses primary storage class for critical database data (Retain policy)
*/}}
{{- define "postgresql.storageClass" -}}
{{- if .Values.global }}
{{- if .Values.global.storage }}
{{- if .Values.global.storage.primaryClass }}
{{- .Values.global.storage.primaryClass }}
{{- else }}
{{- .Values.persistence.storageClass | default "cptm8-dev-ssd-retain" }}
{{- end }}
{{- else }}
{{- .Values.persistence.storageClass | default "cptm8-dev-ssd-retain" }}
{{- end }}
{{- else }}
{{- .Values.persistence.storageClass | default "cptm8-dev-ssd-retain" }}
{{- end }}
{{- end }}
