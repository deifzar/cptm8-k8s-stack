{{/*
Get environment from global or default
*/}}
{{- define "opensearch.environment" -}}
{{- if .Values.global }}
{{- .Values.global.environment | default "dev" }}
{{- else }}
{{- "dev" }}
{{- end }}
{{- end }}

{{/*
Get the namespace
*/}}
{{- define "opensearch.namespace" -}}
{{- printf "cptm8-%s" (include "opensearch.environment" .) | default .Release.Namespace }}
{{- end }}


{{/*
Expand the name of the chart.
*/}}
{{- define "opensearch.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "opensearch.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opensearch.labels" -}}
helm.sh/chart: {{ include "opensearch.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Get the storage class
*/}}
{{- define "opensearch.storageClass" -}}
{{- if .Values.global }}
{{- if .Values.global.storageClass }}
{{- .Values.global.storageClass }}
{{- else }}
{{- .Values.persistence.storageClass | default "standard" }}
{{- end }}
{{- else }}
{{- .Values.persistence.storageClass | default "standard" }}
{{- end }}
{{- end }}

{{/*
Generate discovery seed hosts
*/}}
{{- define "opensearch.discoveryHosts" -}}
{{- $namespace := include "opensearch.namespace" . -}}
{{- $clusterName := .Values.clusterName -}}
{{- $hosts := list -}}
{{- range $nodeName, $nodeConfig := .Values.nodes }}
{{- if $nodeConfig.enabled }}
{{- $host := printf "opensearch-%s-0.%s.%s.svc.cluster.local" $nodeName $clusterName $namespace -}}
{{- $hosts = append $hosts $host -}}
{{- end }}
{{- end }}
{{- join "," $hosts }}
{{- end }}

{{/*
Generate initial cluster manager nodes
*/}}
{{- define "opensearch.initialMasterNodes" -}}
{{- $nodes := list -}}
{{- range $nodeName, $nodeConfig := .Values.nodes }}
{{- if $nodeConfig.enabled }}
{{- $nodes = append $nodes (printf "opensearch-%s" $nodeName) -}}
{{- end }}
{{- end }}
{{- join "," $nodes }}
{{- end }}

{{/*
OpenSearch service URL for dashboard
*/}}
{{- define "opensearch.serviceUrl" -}}
{{- $namespace := include "opensearch.namespace" . -}}
{{- printf "http://opensearch-service.%s.svc.cluster.local:%d" $namespace (int .Values.service.httpPort) }}
{{- end }}
