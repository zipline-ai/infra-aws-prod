{{- define "hub.fullname" -}}
{{- .Release.Name }}-hub
{{- end }}

{{- define "hub.pgname" -}}
{{- .Release.Name }}-postgres
{{- end }}

{{- define "hub.labels" -}}
app.kubernetes.io/name: hub
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "hub.selectorLabels" -}}
app: {{ include "hub.fullname" . }}
{{- end }}

{{- define "hub.pgSelectorLabels" -}}
app: {{ include "hub.pgname" . }}
{{- end }}
