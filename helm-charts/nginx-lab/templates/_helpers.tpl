{{/*
Expand the name of the chart.
*/}}
{{- define "nginx-lab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nginx-lab.fullname" -}}
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
{{- define "nginx-lab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nginx-lab.labels" -}}
helm.sh/chart: {{ include "nginx-lab.chart" . }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{ include "nginx-lab.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.aclab.uk/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.aclab.uk/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nginx-lab.selectorLabels" -}}
app.aclab.uk/name: {{ include "nginx-lab.name" . }}
app.aclab.uk/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nginx-lab.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nginx-lab.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "nginx-lab.serviceNameForPath" -}}
{{- $path := .path -}}
{{- $ctx := .ctx -}}
{{- $suffix := trimPrefix "/" $path | default "root" -}}
{{- printf "%s-%s-svc" (include "nginx-lab.fullname" $ctx) $suffix -}}
{{- end -}}
