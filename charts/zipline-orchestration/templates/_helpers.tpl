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
{{- if .Values.serviceAccount.create }}
{{- default (include "zipline-orchestration.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Default Kubernetes namespace used for Spark compute jobs.
*/}}
{{- define "zipline-orchestration.computeDefaultNamespace" -}}
{{- $defaultNamespace := .Values.compute.defaultNamespace | default "" -}}
{{- if $defaultNamespace -}}
{{- $defaultNamespace -}}
{{- else -}}
{{- $namespaces := .Values.compute.namespaces | default list -}}
{{- if gt (len $namespaces) 0 -}}
{{- (index $namespaces 0).name | default "zipline-default" -}}
{{- else -}}
{{- "zipline-default" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Backward-compatible helper for the Hub's current single default namespace.
*/}}
{{- define "zipline-orchestration.computeJobNamespace" -}}
{{- include "zipline-orchestration.computeDefaultNamespace" . -}}
{{- end }}

{{/*
Namespace used for compute control-plane support services.
*/}}
{{- define "zipline-orchestration.computeSystemNamespace" -}}
{{- .Release.Namespace -}}
{{- end }}

{{/*
Bucket name without the URI scheme.
*/}}
{{- define "zipline-orchestration.computeBucketName" -}}
{{- .Values.compute.objectStore.bucket | trimPrefix "s3://" | trimPrefix "s3a://" | trimPrefix "gs://" | trimSuffix "/" -}}
{{- end }}

{{/*
Spark event log directory used by Spark History Server.
*/}}
{{- define "zipline-orchestration.sparkEventLogDir" -}}
{{- if .Values.compute.sparkDefaults.eventLogDir -}}
{{- .Values.compute.sparkDefaults.eventLogDir -}}
{{- else if and .Values.compute.objectStore.bucket (eq (.Values.compute.cloudProvider | default "aws") "aws") -}}
{{- printf "s3a://%s/spark-events" (include "zipline-orchestration.computeBucketName" .) -}}
{{- else if and .Values.compute.objectStore.bucket (eq .Values.compute.cloudProvider "gcp") -}}
{{- printf "gs://%s/spark-events" (include "zipline-orchestration.computeBucketName" .) -}}
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

{{/*
Externally reachable Spark History Server URL, used by the Hub to render
links the operator clicks from a browser. When ingress.ui.host is set the
SHS is exposed behind <ui-host>/<proxyBase>; otherwise the Hub falls back
to the cluster-internal Service DNS which only works from inside the cluster.
*/}}
{{- define "zipline-orchestration.historyServerPublicUrl" -}}
{{- if .Values.ingress.ui.host -}}
{{- printf "https://%s%s" .Values.ingress.ui.host (include "zipline-orchestration.historyServerProxyBase" .) -}}
{{- else -}}
{{- printf "http://spark-history-server.%s.svc.cluster.local:18080" .Release.Namespace -}}
{{- end -}}
{{- end }}
