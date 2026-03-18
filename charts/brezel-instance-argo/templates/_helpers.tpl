{{/*
Expand the name of the chart.
*/}}
{{- define "brezel.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "brezel.fullname" -}}
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
{{- define "brezel.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "brezel.labels" -}}
helm.sh/chart: {{ include "brezel.chart" . }}
{{ include "brezel.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "brezel.selectorLabels" -}}
app.kubernetes.io/name: {{ include "brezel.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
MySQL Service Name
*/}}
{{- define "brezel.mysqlServiceName" -}}
brezel-mysql
{{- end }}

{{/*
Runtime Secret Name
*/}}
{{- define "brezel.runtimeSecretName" -}}
{{- if .Values.existing_secret_name -}}
{{- .Values.existing_secret_name -}}
{{- else -}}
brezel-api
{{- end -}}
{{- end }}

{{/*
Image Pull Secret Name
*/}}
{{- define "brezel.imagePullSecretName" -}}
{{- if .Values.existing_image_pull_secret_name -}}
{{- .Values.existing_image_pull_secret_name -}}
{{- else -}}
gitlab-registry
{{- end -}}
{{- end }}

{{/*
Primary API hostname
*/}}
{{- define "brezel.primaryApiHostname" -}}
{{- required "values.api_hostnames must contain at least one hostname" (first .Values.api_hostnames) -}}
{{- end }}

{{/*
Config Version
*/}}
{{- define "brezel.configVersion" -}}
{{- $config := dict "env" .Values.env "secret_env" .Values.secret_env "system_envs" .Values.system_envs "system_secret_envs" .Values.system_secret_envs -}}
{{- sha1sum (toJson $config) -}}
{{- end }}

{{/*
SPA Config Version
*/}}
{{- define "brezel.spaConfigVersion" -}}
{{- $config := dict "secure" .Values.secure "api_hostnames" .Values.api_hostnames -}}
{{- sha1sum (toJson $config) -}}
{{- end }}

{{/*
Bootstrap Job Name
*/}}
{{- define "brezel.bootstrapJobName" -}}
{{- $config := dict "image" .Values.image "bootstrap" .Values.bootstrap "env" .Values.env "secret_env" .Values.secret_env "system_envs" .Values.system_envs "system_secret_envs" .Values.system_secret_envs "default_system" .Values.default_system "db" (dict "with_database_pod" .Values.with_database_pod "db_host" .Values.db_host "db_port" .Values.db_port "db_name" .Values.db_name "db_user" .Values.db_user) "drivers" (dict "session" .Values.session_driver "cache" .Values.cache_driver "queue" .Values.queue_driver) "prepare_storage_script" (include "brezel.prepareStorageScript" .) -}}
{{- printf "brezel-bootstrap-%s" (sha1sum (toJson $config) | trunc 8) -}}
{{- end }}

{{/*
Prepare ephemeral storage with runtime env.
*/}}
{{- define "brezel.prepareStorageScript" -}}
set -eu
mkdir -p /app/storage
printenv | awk -F= 'BEGIN{OFS=FS} {if ($1 ~ /^[[:alpha:]_][[:alnum:]_]*$/) printf "%s=\"%s\"\n", $1, substr($0, index($0,$2))}' > /app/storage/.env
cat > /app/storage/workers.supervisord.conf <<'EOF'
[program:brezel-default-queue]
autostart=false
autorestart=false
startsecs=0
exitcodes=0
command=/bin/sh -c 'exit 0'
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
EOF
{{- end }}

{{/*
Worker command
*/}}
{{- define "brezel.workerCommand" -}}
{{- $worker := .worker -}}
{{- if $worker.command -}}
{{- $worker.command -}}
{{- else -}}
{{- $command := "php bakery work" -}}
{{- if hasKey $worker "sleep" -}}
{{- $command = printf "%s --sleep=%v" $command $worker.sleep -}}
{{- end -}}
{{- if $worker.queues -}}
{{- $command = printf "%s --queue=%s" $command (join "," $worker.queues) -}}
{{- end -}}
{{- if hasKey $worker "tries" -}}
{{- $command = printf "%s --tries=%v" $command $worker.tries -}}
{{- end -}}
{{- if hasKey $worker "timeout" -}}
{{- $command = printf "%s --timeout=%v" $command $worker.timeout -}}
{{- end -}}
{{- $command -}}
{{- end -}}
{{- end -}}
