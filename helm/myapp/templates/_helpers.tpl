{{/*
Resource name: <release>-<chart>, or just <release> if it already contains the chart name.
Truncated to 63 characters (DNS label limit).
*/}}
{{- define "myapp.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Selector labels: the single source for Deployment selector, pod labels and Service selector.
Immutable on a Deployment, so they must not contain anything that changes between releases.
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels for every resource.
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "myapp.selectorLabels" . }}
app.kubernetes.io/version: {{ include "myapp.imageTag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Image tag: explicit value, or the chart's appVersion. Never "latest".
*/}}
{{- define "myapp.imageTag" -}}
{{- .Values.image.tag | default .Chart.AppVersion }}
{{- end }}
