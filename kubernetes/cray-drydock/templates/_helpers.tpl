{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "cray-drydock.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cray-drydock.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cray-drydock.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "cray-drydock.labels" -}}
helm.sh/chart: {{ include "cray-drydock.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Get an image prefix
*/}}
{{- define "cray-drydock.image-prefix" -}}
{{- if .imagesHost -}}
{{- printf "%s/" .imagesHost -}}
{{- else -}}
{{- printf "" -}}
{{- end -}}
{{- end -}}

{{/*
The Cray build process fills in the Chart appVersion based on the image tag that it generated.
This can be overridden by setting the image tag in values.yaml.
If neither is set then `latest` is used.
*/}}
{{- define "cray-drydock.watcher-tag" -}}
{{- if .Values.sonar.jobsWatcher.image.tag -}}
{{- .Values.sonar.jobsWatcher.image.tag -}}
{{- else -}}
{{- .Chart.AppVersion | default "latest" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
