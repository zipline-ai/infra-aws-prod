{{/*
Expand the name of the chart.
*/}}
{{- define "crucible.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "crucible.fullname" -}}
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
Common labels.
*/}}
{{- define "crucible.labels" -}}
helm.sh/chart: {{ include "crucible.name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "crucible.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "crucible.selectorLabels" -}}
app.kubernetes.io/name: {{ include "crucible.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "crucible.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "crucible.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Spark observability public path. When historyServer.publicUrl is set, its path
is the source of truth; historyServer.proxyBase is only the path-only fallback.
*/}}
{{- define "crucible.historyServerProxyBase" -}}
{{- $fallback := .Values.historyServer.proxyBase | default "spark-history" -}}
{{- $fallback = printf "/%s" (trimAll "/" $fallback) -}}
{{- $publicURL := .Values.historyServer.publicUrl | default "" | trim -}}
{{- if $publicURL -}}
{{- $parsed := urlParse $publicURL -}}
{{- $path := trimSuffix "/" ($parsed.path | default "") -}}
{{- if or (eq $path "") (eq $path "/") -}}
{{- fail "historyServer.publicUrl must include a non-root path such as https://example.com/spark-history" -}}
{{- end -}}
{{- printf "/%s" (trimAll "/" $path) -}}
{{- else -}}
{{- $fallback -}}
{{- end -}}
{{- end }}

{{/*
Derive the bucket name (without scheme prefix) from objectStore.bucket.
Handles s3://bucket, gs://bucket, https://account.blob.core.windows.net/container, or plain "bucket".
*/}}
{{- define "crucible.bucketName" -}}
{{- .Values.objectStore.bucket | trimPrefix "s3://" | trimPrefix "gs://" | trimPrefix "https://" | trimSuffix "/" }}
{{- end }}

{{/*
Spark event log directory. User override takes precedence; otherwise derived from bucket + cloud.
*/}}
{{- define "crucible.sparkEventLogDir" -}}
{{- if .Values.sparkDefaults.eventLogDir }}
{{- .Values.sparkDefaults.eventLogDir }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "aws") }}
{{- printf "s3a://%s/spark-events" (include "crucible.bucketName" .) }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "gcp") }}
{{- printf "gs://%s/spark-events" (include "crucible.bucketName" .) }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "azure") }}
{{- printf "abfss://%s/spark-events" (include "crucible.bucketName" .) }}
{{- end }}
{{- end }}

{{/*
Flink checkpoint directory. User override takes precedence.
*/}}
{{- define "crucible.flinkCheckpointDir" -}}
{{- if .Values.flinkDefaults.checkpointDir }}
{{- .Values.flinkDefaults.checkpointDir }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "aws") }}
{{- printf "s3://%s/flink/checkpoints" (include "crucible.bucketName" .) }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "gcp") }}
{{- printf "gs://%s/flink/checkpoints" (include "crucible.bucketName" .) }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "azure") }}
{{- printf "abfss://%s/flink/checkpoints" (include "crucible.bucketName" .) }}
{{- end }}
{{- end }}

{{/*
Flink savepoint directory. User override takes precedence.
*/}}
{{- define "crucible.flinkSavepointDir" -}}
{{- if .Values.flinkDefaults.savepointDir }}
{{- .Values.flinkDefaults.savepointDir }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "aws") }}
{{- printf "s3://%s/flink/savepoints" (include "crucible.bucketName" .) }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "gcp") }}
{{- printf "gs://%s/flink/savepoints" (include "crucible.bucketName" .) }}
{{- else if and .Values.objectStore.bucket (eq .Values.cloudProvider "azure") }}
{{- printf "abfss://%s/flink/savepoints" (include "crucible.bucketName" .) }}
{{- end }}
{{- end }}

{{/*
Azure storage account name extracted from objectStore.bucket.
Handles "https://account.blob.core.windows.net/container" and "container@account.dfs.core.windows.net".
*/}}
{{- define "crucible.azureAccountName" -}}
{{- $raw := .Values.objectStore.bucket | default "" }}
{{- if contains "@" $raw }}
{{- /* container@account.dfs.core.windows.net → split on @, take host, first dot-segment */ -}}
{{- $host := index (splitList "@" $raw) 1 }}
{{- index (splitList "." $host) 0 }}
{{- else }}
{{- /* https://account.blob.core.windows.net/container → strip scheme, first dot-segment */ -}}
{{- $stripped := $raw | trimPrefix "https://" | trimPrefix "http://" }}
{{- $host := index (splitList "/" $stripped) 0 }}
{{- index (splitList "." $host) 0 }}
{{- end }}
{{- end }}

{{/*
Azure container name extracted from objectStore.bucket.
Handles "https://account.blob.core.windows.net/container" and "container@account.dfs.core.windows.net".
*/}}
{{- define "crucible.azureContainerName" -}}
{{- $raw := .Values.objectStore.bucket | default "" }}
{{- if contains "@" $raw }}
{{- /* container@account.dfs.core.windows.net → part before @ */ -}}
{{- $parts := splitList "@" $raw }}
{{- index $parts 0 }}
{{- else }}
{{- /* https://account.blob.core.windows.net/container → last path segment */ -}}
{{- $stripped := $raw | trimPrefix "https://" | trimPrefix "http://" | trimSuffix "/" }}
{{- $segments := splitList "/" $stripped }}
{{- index $segments (sub (len $segments) 1) }}
{{- end }}
{{- end }}
