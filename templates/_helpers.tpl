{{- define "sre-technical-challenge.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "sre-technical-challenge.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "sre-technical-challenge.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "sre-technical-challenge.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sre-technical-challenge.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "sre-technical-challenge.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "sre-technical-challenge.selectorLabels" . }}
{{- end }}