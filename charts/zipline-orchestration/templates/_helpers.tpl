{{/*
Expand the name of the chart.
*/}}
{{- define "zipline-orchestration.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "zipline-orchestration.fullname" -}}
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
{{- define "zipline-orchestration.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zipline-orchestration.labels" -}}
helm.sh/chart: {{ include "zipline-orchestration.chart" . }}
{{ include "zipline-orchestration.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zipline-orchestration.selectorLabels" -}}
app.kubernetes.io/name: {{ include "zipline-orchestration.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "zipline-orchestration.serviceAccountName" -}}
{{- if .Values.platform.serviceAccount.create }}
{{- default (include "zipline-orchestration.fullname" .) .Values.platform.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.platform.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Kubernetes namespace used for Spark/Flink compute jobs.
Returns the first team's namespace from compute.teams; future Hub-managed
CRDs will replace this single-team bootstrap path.
*/}}
{{- define "zipline-orchestration.computeJobNamespace" -}}
{{- (index .Values.compute.teams 0).namespace -}}
{{- end }}

{{/*
Namespace used for compute control-plane support services.
*/}}
{{- define "zipline-orchestration.computeSystemNamespace" -}}
{{- .Release.Namespace -}}
{{- end }}

{{/*
S3 warehouse bucket name. infra.storage.warehouseBucket is already
name-only (no scheme), so it is returned as-is.
*/}}
{{- define "zipline-orchestration.computeBucketName" -}}
{{- .Values.infra.storage.warehouseBucket -}}
{{- end }}

{{/*
Spark event log directory used by Spark History Server.
Defaults to s3a://<infra.storage.warehouseBucket>/spark-events when
compute.sparkDefaults.eventLogDir is empty.
*/}}
{{- define "zipline-orchestration.sparkEventLogDir" -}}
{{- if .Values.compute.sparkDefaults.eventLogDir -}}
{{- .Values.compute.sparkDefaults.eventLogDir -}}
{{- else if .Values.infra.storage.warehouseBucket -}}
{{- printf "s3a://%s/spark-events" .Values.infra.storage.warehouseBucket -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end }}

{{/*
Spark History Server proxy base path.
*/}}
{{- define "zipline-orchestration.historyServerProxyBase" -}}
{{- printf "/%s" (trimAll "/" (.Values.compute.historyServer.proxyBase | default "spark-history")) -}}
{{- end }}
