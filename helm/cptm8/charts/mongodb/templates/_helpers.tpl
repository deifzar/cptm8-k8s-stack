{{/*
Get environment from global or default
*/}}
{{- define "mongodb.environment" -}}
{{- if .Values.global }}
{{- .Values.global.environment | default "dev" }}
{{- else }}
{{- "dev" }}
{{- end }}
{{- end }}

{{/*
Get the namespace
*/}}
{{- define "mongodb.namespace" -}}
{{- printf "cptm8-%s" (include "mongodb.environment" .) | default .Release.Namespace }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "mongodb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mongodb.fullname" -}}
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
{{- define "mongodb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mongodb.labels" -}}
helm.sh/chart: {{ include "mongodb.chart" . }}
{{ include "mongodb.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
tier: data
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mongodb.selectorLabels" -}}
app: {{ include "mongodb.fullname" . }}
app.kubernetes.io/name: {{ include "mongodb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get the primary storage class - uses global.storage.primaryClass for critical database data (Retain policy)
*/}}
{{- define "mongodb.storageClass" -}}
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

{{/*
Get the delete storage class - uses global.storage.deleteClass for non-critical/recreatable data (Delete policy)
*/}}
{{- define "mongodb.storageClassDelete" -}}
{{- if .Values.global }}
{{- if .Values.global.storage }}
{{- if .Values.global.storage.deleteClass }}
{{- .Values.global.storage.deleteClass }}
{{- else }}
{{- .Values.persistence.storageClassDelete | default "cptm8-dev-ssd-delete" }}
{{- end }}
{{- else }}
{{- .Values.persistence.storageClassDelete | default "cptm8-dev-ssd-delete" }}
{{- end }}
{{- else }}
{{- .Values.persistence.storageClassDelete | default "cptm8-dev-ssd-delete" }}
{{- end }}
{{- end }}

{{/*
MongoDB service hostname (for init job)
*/}}
{{- define "mongodb.serviceHostname" -}}
{{- printf "%s-headless.%s.svc.cluster.local" (include "mongodb.fullname" .) (include "mongodb.namespace" .) }}
{{- end }}

{{/*
MongoDB comments and commands for init job
*/}}
{{/* Generate echo statements for each replica */}}
{{- define "mongodb.echoHosts" -}}
{{- $fullname := include "mongodb.fullname" . -}}
{{- range $i := until (int .Values.replicaCount) }}
echo "MongoDB Host {{ $i }}: {{ $fullname }}-{{ $i }}.${MONGO_HOST}"
{{- end }}
{{- end }}

{{/* Generate wait loops for each replica */}}
{{- define "mongodb.waitForReplicas" -}}
{{- $fullname := include "mongodb.fullname" . -}}
{{- range $i := until (int .Values.replicaCount) }}
until mongosh --host {{ $fullname }}-{{ $i }}.${MONGO_HOST} --eval "db.adminCommand('ping')" --quiet 2>/dev/null; do
  echo '❌ MongoDB #{{ $i }} is not reachable. Waiting for 2 secs...'
  sleep 2
done
{{- end }}
{{- end }}

{{/* Generate replica set members array */}}
{{- define "mongodb.replicaSetMembers" -}}
{{- $fullname := include "mongodb.fullname" . -}}
{{- $count := int .Values.replicaCount -}}
{{- range $i := until $count }}
{_id: {{ $i }}, host: "{{ $fullname }}-{{ $i }}." + host, priority: {{ sub $count $i }}}{{ if lt $i (sub $count 1) }},{{ end }}
{{- end }}
{{- end }}
