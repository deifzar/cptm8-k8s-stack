{{/*
=============================================================================
INIT CONTAINER TEMPLATES
=============================================================================
Init containers prepare writable directories and fix ownership for non-root users.
*/}}

{{/*
Init container for Go scanners - copies configs and fixes ownership
Usage: {{ include "cptm8.goScannerInitContainer" (dict "name" "asmm8" "ctx" .) }}

This init container:
1. Copies ConfigMap templates to writable emptyDir (dereferencing symlinks)
2. Creates placeholder configuration.yaml
3. Sets ownership for non-root user (uid 10001)
4. Sets secure permissions on directories and files
*/}}
{{- define "cptm8.goScannerInitContainer" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- $runAsUser := $ctx.Values.global.securityContext.runAsUser | default 10001 -}}
{{- $fsGroup := $ctx.Values.global.securityContext.fsGroup | default 10001 -}}
{{- $isPrivileged := false -}}
{{- $scanner := index $ctx.Values.scanners $name | default dict -}}
{{- if $scanner.privileged }}
{{- $isPrivileged = true -}}
{{- end -}}
- name: fix-app-ownership
  image: {{ $ctx.Values.global.initImage | default "busybox:1.35" }}
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - |
    echo "🔧 Preparing writable directories for {{ $name }}..."

    # Copy ConfigMap templates to writable emptyDir (use -L to dereference symlinks)
    if [ -d "/config-templates" ] && [ "$(ls -A /config-templates 2>/dev/null)" ]; then
      echo "Copying config templates..."
      cp -rL /config-templates/* /app/configs/ 2>/dev/null || true
    fi

    # Create placeholder configuration.yaml (will be populated by entrypoint)
    touch /app/configs/configuration.yaml

    #👤 Set ownership for writable directories
    echo "Setting ownership to {{ $runAsUser }}:{{ $fsGroup }}..."
    {{- if $isPrivileged }}
    # Privileged scanner (naabum8) uses root:group ownership
    chown -R 0:{{ $fsGroup }} /app/configs /app/log /app/tmp /app/.config
    {{- else }}
    chown -R {{ $runAsUser }}:{{ $fsGroup }} /app/configs /app/log /app/tmp /app/.config
    {{- end }}
    chmod 750 /app/configs /app/log /app/tmp /app/.config

    {{- if eq $name "num8" }}
    # num8 requires nuclei-templates directory
    chown -R {{ $runAsUser }}:{{ $fsGroup }} /app/nuclei-templates
    chmod 750 /app/nuclei-templates
    {{- end }}

    # Set secure permissions on existing files
    find /app/configs -type f -exec chmod 640 "{}" \; 2>/dev/null || true
    find /app/log -type f -name "*.log" -exec chmod 640 {} \; 2>/dev/null || true

    echo "✅ Directories ready for {{ $name }}"
  volumeMounts:
  - name: log-volume
    mountPath: /app/log
  - name: tmp-volume
    mountPath: /app/tmp
  - name: config-writable
    mountPath: /app/configs
  - name: config-dir-volume
    mountPath: /app/.config
  - name: config-volume
    mountPath: /config-templates
  {{- if eq $name "num8" }}
  - name: dir-nuclei-templates
    mountPath: /app/nuclei-templates
  {{- end }}
  securityContext:
    runAsUser: 0
{{- end }}

{{/*
=============================================================================
FRONTEND INIT CONTAINER
=============================================================================
Minimal setup for Node.js apps (dashboardm8, socketm8)

Usage: {{ include "cptm8.frontendInitContainer" (dict "name" "dashboardm8" "ctx" .) }}
*/}}
{{- define "cptm8.frontendInitContainer" -}}
{{- $name := .name -}}
{{- $ctx := .ctx -}}
{{- $frontend := index $ctx.Values.frontend $name -}}
{{- $sc := $frontend.securityContext | default dict -}}
{{- $runAsUser := $sc.runAsUser | default 1001 -}}
{{- $fsGroup := $sc.fsGroup | default 1001 -}}
- name: fix-app-ownership
  image: {{ $ctx.Values.global.initImage | default "busybox:1.35" }}
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - |
    echo "🔧 Preparing directories for {{ $name }}..."

    # Copy entrypoint script if mounted
    if [ -f /entrypoint-template/docker-entrypoint.sh ]; then
      cp /entrypoint-template/docker-entrypoint.sh /entrypoint/docker-entrypoint.sh
      chmod +x /entrypoint/docker-entrypoint.sh
    fi

    #👤 Set ownership for non-root user
    chown -R {{ $runAsUser }}:{{ $fsGroup }} /entrypoint 2>/dev/null || true

    echo "✅ Directories ready for {{ $name }}"
  volumeMounts:
  - name: entrypoint-volume
    mountPath: /entrypoint
  - name: entrypoint-template
    mountPath: /entrypoint-template
  securityContext:
    runAsUser: 0
{{- end }}

{{/*
=============================================================================
DATABASE INIT CONTAINERS
=============================================================================
Init containers for database services
*/}}

{{/*
PostgreSQL init container - ensures data directory ownership
*/}}
{{- define "cptm8.postgresqlInitContainer" -}}
{{- $ctx := .ctx -}}
- name: fix-permissions
  image: {{ $ctx.Values.global.initImage | default "busybox:1.35" }}
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - |
    echo "🔧 Setting PostgreSQL data directory permissions..."
    chown -R 999:999 /var/lib/postgresql/data
    chmod 700 /var/lib/postgresql/data
    echo "✅ PostgreSQL data directory ready"
  volumeMounts:
  - name: postgresql-data
    mountPath: /var/lib/postgresql/data
  securityContext:
    runAsUser: 0
{{- end }}

{{/*
MongoDB init container - ensures data directory ownership
*/}}
{{- define "cptm8.mongodbInitContainer" -}}
{{- $ctx := .ctx -}}
- name: fix-permissions
  image: {{ $ctx.Values.global.initImage | default "busybox:1.35" }}
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - |
    echo "🔧 Setting MongoDB data directory permissions..."
    chown -R 999:999 /data/db /data/configdb
    chmod 755 /data/db /data/configdb
    echo "✅ MongoDB data directory ready"
  volumeMounts:
  - name: mongodb-data
    mountPath: /data/db
  - name: mongodb-configdb
    mountPath: /data/configdb
  securityContext:
    runAsUser: 0
{{- end }}

{{/*
OpenSearch init container - sets vm.max_map_count and directory permissions
*/}}
{{- define "cptm8.opensearchInitContainer" -}}
{{- $ctx := .ctx -}}
- name: increase-vm-max-map-count
  image: {{ $ctx.Values.global.initImage | default "busybox:1.35" }}
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - |
    echo "🔧 Configuring system settings for OpenSearch..."
    sysctl -w vm.max_map_count=262144 || echo "Cannot set vm.max_map_count (may need privileged mode)"
    echo "✅ System settings configured"
  securityContext:
    privileged: true
    runAsUser: 0
- name: fix-permissions
  image: {{ $ctx.Values.global.initImage | default "busybox:1.35" }}
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - |
    echo "🔧 Setting OpenSearch data directory permissions..."
    chown -R 1000:1000 /usr/share/opensearch/data
    chmod 755 /usr/share/opensearch/data
    echo "✅ OpenSearch data directory ready"
  volumeMounts:
  - name: opensearch-data
    mountPath: /usr/share/opensearch/data
  securityContext:
    runAsUser: 0
{{- end }}
