{{/*
=============================================================================
SECURITY CONTEXT TEMPLATES
=============================================================================
Security contexts for containers and pods across all service types.
*/}}

{{/*
Container security context for Go scanners
Handles special cases like naabum8 which requires elevated privileges

Usage: {{ include "cptm8.goScannerSecurityContext" (dict "name" "asmm8" "ctx" .) }}

Security profiles:
  - Standard scanner: Non-root (uid 10001), minimal capabilities
  - naabum8: Root user, elevated network capabilities for port scanning
  - orchestratorm8: Non-root with readOnlyRootFilesystem
*/}}
{{- define "cptm8.goScannerSecurityContext" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- $isReporting := eq $name "reportingm8" -}}
{{- $serviceConfig := dict -}}
{{- if $isReporting }}
{{- $serviceConfig = index $ctx.Values.reporting $name | default dict -}}
{{- else }}
{{- $serviceConfig = index $ctx.Values.scanners $name | default dict -}}
{{- end -}}
{{- if $serviceConfig.privileged }}
# {{ $name }} requires elevated privileges for port scanning
runAsNonRoot: false
runAsUser: 0
allowPrivilegeEscalation: true
readOnlyRootFilesystem: false
capabilities:
  add:
  - NET_RAW
  - NET_ADMIN
  - NET_BIND_SERVICE
{{- else }}
runAsNonRoot: true
runAsUser: {{ $ctx.Values.global.securityContext.runAsUser | default 10001 }}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: {{ $serviceConfig.readOnlyRootFilesystem | default false }}
capabilities:
  drop:
  - ALL
  add:
  - NET_RAW
{{- end }}
{{- end }}

{{/*
=============================================================================
FRONTEND SECURITY CONTEXT
=============================================================================
Security context for frontend services (Node.js - dashboardm8, socketm8)

Usage: {{ include "cptm8.frontendSecurityContext" (dict "name" "dashboardm8" "ctx" .) }}
*/}}
{{- define "cptm8.frontendSecurityContext" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- $frontend := index $ctx.Values.frontend $name -}}
{{- $sc := $frontend.securityContext | default dict -}}
runAsNonRoot: true
runAsUser: {{ $sc.runAsUser | default 1001 }}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: false
capabilities:
  drop:
  - ALL
{{- end }}

{{/*
=============================================================================
POD SECURITY CONTEXTS
=============================================================================
*/}}

{{/*
Pod security context for Go scanners
Usage: {{ include "cptm8.goScannerPodSecurityContext" . }}
*/}}
{{- define "cptm8.goScannerPodSecurityContext" -}}
{{- $ctx := . -}}
fsGroup: {{ $ctx.Values.global.securityContext.fsGroup | default 10001 }}
{{- end }}

{{/*
Pod security context for frontend services
Usage: {{ include "cptm8.frontendPodSecurityContext" (dict "name" "dashboardm8" "ctx" .) }}
*/}}
{{- define "cptm8.frontendPodSecurityContext" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- $frontend := index $ctx.Values.frontend $name -}}
{{- $sc := $frontend.securityContext | default dict -}}
fsGroup: {{ $sc.fsGroup | default 1001 }}
{{- end }}

{{/*
=============================================================================
DATABASE SECURITY CONTEXTS
=============================================================================
*/}}

{{/*
Container security context for database services
Usage: {{ include "cptm8.databaseSecurityContext" (dict "type" "postgresql" "ctx" .) }}

Supported types: postgresql, mongodb, rabbitmq, opensearch
*/}}
{{- define "cptm8.databaseSecurityContext" -}}
{{- $type := .type -}}
{{- $ctx := .ctx -}}
{{- if eq $type "postgresql" }}
runAsNonRoot: true
runAsUser: 999
allowPrivilegeEscalation: false
capabilities:
  drop:
  - ALL
{{- else if eq $type "mongodb" }}
runAsNonRoot: true
runAsUser: 999
allowPrivilegeEscalation: false
capabilities:
  drop:
  - ALL
{{- else if eq $type "rabbitmq" }}
runAsNonRoot: true
runAsUser: 999
allowPrivilegeEscalation: false
capabilities:
  drop:
  - ALL
{{- else if eq $type "opensearch" }}
runAsNonRoot: true
runAsUser: 1000
allowPrivilegeEscalation: false
capabilities:
  drop:
  - ALL
{{- end }}
{{- end }}

{{/*
Pod security context for database services
Usage: {{ include "cptm8.databasePodSecurityContext" (dict "type" "postgresql") }}
*/}}
{{- define "cptm8.databasePodSecurityContext" -}}
{{- $type := .type -}}
{{- if eq $type "postgresql" }}
fsGroup: 999
{{- else if eq $type "mongodb" }}
fsGroup: 999
{{- else if eq $type "rabbitmq" }}
fsGroup: 999
{{- else if eq $type "opensearch" }}
fsGroup: 1000
{{- end }}
{{- end }}

{{/*
=============================================================================
VECTOR SECURITY CONTEXT
=============================================================================
*/}}

{{/*
Vector container security context
Usage: {{ include "cptm8.vectorSecurityContext" . }}
*/}}
{{- define "cptm8.vectorSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ .Values.global.securityContext.runAsUser | default 10001 }}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
  - ALL
{{- end }}

{{/*
Vector pod security context
Usage: {{ include "cptm8.vectorPodSecurityContext" . }}
*/}}
{{- define "cptm8.vectorPodSecurityContext" -}}
fsGroup: {{ .Values.global.securityContext.fsGroup | default 10001 }}
{{- end }}

{{/*
=============================================================================
NETWORK POLICY SECURITY
=============================================================================
*/}}

{{/*
Default deny network policy for namespace
Usage: {{ include "cptm8.defaultDenyNetworkPolicy" . }}
*/}}
{{- define "cptm8.defaultDenyNetworkPolicy" -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: {{ include "cptm8.namespace" . }}
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
{{- end }}
