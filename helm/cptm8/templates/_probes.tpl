{{/*
=============================================================================
HEALTH PROBE TEMPLATES
=============================================================================
Liveness and readiness probes for all service types.
*/}}

{{/*
Liveness and readiness probes for Go scanners
Usage: {{ include "cptm8.goScannerProbes" (dict "name" "asmm8" "port" 8000 "ctx" .) }}

All Go scanners expose:
  - /health endpoint for liveness
  - /ready endpoint for readiness
*/}}
{{- define "cptm8.goScannerProbes" -}}
{{- $name := .name -}}
{{- $port := .port -}}
{{- $ctx := .ctx -}}
{{- $isReporting := eq $name "reportingm8" -}}
{{- $serviceConfig := dict -}}
{{- if $isReporting }}
{{- $serviceConfig = index $ctx.Values.reporting $name | default dict -}}
{{- else }}
{{- $serviceConfig = index $ctx.Values.scanners $name | default dict -}}
{{- end -}}
{{- $probes := $serviceConfig.probes | default dict -}}
{{- $initialDelaySeconds := $probes.initialDelaySeconds | default 30 -}}
{{- $periodSeconds := $probes.periodSeconds | default 10 -}}
{{- $timeoutSeconds := $probes.timeoutSeconds | default 5 -}}
{{- $failureThreshold := $probes.failureThreshold | default 3 -}}
livenessProbe:
  httpGet:
    path: /health
    port: {{ $port }}
  initialDelaySeconds: {{ $initialDelaySeconds }}
  periodSeconds: {{ $periodSeconds }}
  timeoutSeconds: {{ $timeoutSeconds }}
  successThreshold: 1
  failureThreshold: {{ $failureThreshold }}
readinessProbe:
  httpGet:
    path: /ready
    port: {{ $port }}
  initialDelaySeconds: {{ div $initialDelaySeconds 3 }}
  periodSeconds: {{ div $periodSeconds 2 | default 5 }}
  timeoutSeconds: {{ sub $timeoutSeconds 2 | default 3 }}
  successThreshold: 1
  failureThreshold: {{ $failureThreshold }}
{{- end }}

{{/*
=============================================================================
FRONTEND PROBES
=============================================================================
Liveness and readiness probes for frontend services (Node.js)

Usage: {{ include "cptm8.frontendProbes" (dict "name" "dashboardm8" "port" 3000 "ctx" .) }}

Frontend services typically need longer initial delays due to build/startup time.
*/}}
{{- define "cptm8.frontendProbes" -}}
{{- $name := .name -}}
{{- $port := .port -}}
{{- $ctx := .ctx -}}
{{- $frontend := index $ctx.Values.frontend $name -}}
{{- $probes := $frontend.probes | default dict -}}
{{- $livenessPath := $probes.livenessPath | default $probes.path | default "/health" -}}
{{- $readinessPath := $probes.readinessPath | default $probes.path | default "/health" -}}
{{- $initialDelaySeconds := $probes.initialDelaySeconds | default 180 -}}
{{- $periodSeconds := $probes.periodSeconds | default 5 -}}
{{- $timeoutSeconds := $probes.timeoutSeconds | default 5 -}}
{{- $failureThreshold := $probes.failureThreshold | default 3 -}}
livenessProbe:
  httpGet:
    path: {{ $livenessPath }}
    port: {{ $port }}
  initialDelaySeconds: {{ $initialDelaySeconds }}
  periodSeconds: {{ $periodSeconds }}
  timeoutSeconds: {{ $timeoutSeconds }}
  successThreshold: 1
  failureThreshold: {{ $failureThreshold }}
readinessProbe:
  httpGet:
    path: {{ $readinessPath }}
    port: {{ $port }}
  initialDelaySeconds: {{ div $initialDelaySeconds 3 }}
  periodSeconds: {{ $periodSeconds }}
  timeoutSeconds: {{ sub $timeoutSeconds 2 | default 3 }}
  successThreshold: 1
  failureThreshold: {{ $failureThreshold }}
{{- end }}

{{/*
=============================================================================
DATABASE PROBES
=============================================================================
*/}}

{{/*
Database probes - exec-based for PostgreSQL
Usage: {{ include "cptm8.postgresqlProbes" (dict "username" "postgres") }}
*/}}
{{- define "cptm8.postgresqlProbes" -}}
{{- $username := .username | default "postgres" -}}
livenessProbe:
  exec:
    command:
    - pg_isready
    - -U
    - {{ $username }}
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  exec:
    command:
    - pg_isready
    - -U
    - {{ $username }}
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
{{- end }}

{{/*
Database probes - exec-based for MongoDB
Usage: {{ include "cptm8.mongodbProbes" . }}
*/}}
{{- define "cptm8.mongodbProbes" -}}
livenessProbe:
  exec:
    command:
    - mongosh
    - --eval
    - "db.adminCommand('ping')"
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  exec:
    command:
    - mongosh
    - --eval
    - "db.adminCommand('ping')"
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
{{- end }}

{{/*
Database probes - exec-based for RabbitMQ
Usage: {{ include "cptm8.rabbitmqProbes" . }}
*/}}
{{- define "cptm8.rabbitmqProbes" -}}
livenessProbe:
  exec:
    command:
    - rabbitmq-diagnostics
    - -q
    - ping
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  exec:
    command:
    - rabbitmq-diagnostics
    - -q
    - ping
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
{{- end }}

{{/*
Database probes - HTTP for OpenSearch
Usage: {{ include "cptm8.opensearchProbes" . }}
*/}}
{{- define "cptm8.opensearchProbes" -}}
livenessProbe:
  httpGet:
    path: /_cluster/health?local=true
    port: 9200
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /_cluster/health?local=true
    port: 9200
  initialDelaySeconds: 30
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
{{- end }}

{{/*
OpenSearch Dashboard probes
Usage: {{ include "cptm8.opensearchDashboardProbes" . }}
*/}}
{{- define "cptm8.opensearchDashboardProbes" -}}
livenessProbe:
  httpGet:
    path: /api/status
    port: 5601
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /api/status
    port: 5601
  initialDelaySeconds: 30
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
{{- end }}

{{/*
Vector probes - TCP check on port 9000
Usage: {{ include "cptm8.vectorProbes" . }}
*/}}
{{- define "cptm8.vectorProbes" -}}
livenessProbe:
  httpGet:
    path: /health
    port: 8686
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health
    port: 8686
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
{{- end }}
