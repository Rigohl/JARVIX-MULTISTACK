{{/* Helper templates for jarvix */}}
{{- define "jarvix.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "jarvix.fullname" -}}
{{- printf "%s-%s" (include "jarvix.name" .) .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
