{{/*
Common labels applied to every resource. The release-managed labels
let `kubectl get all -l app.kubernetes.io/part-of=trustacks` find the
whole stack at once.
*/}}
{{- define "quickstart.commonLabels" -}}
app.kubernetes.io/part-of: trustacks
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Per-service labels — pass the service name (e.g., "control-plane")
to get back both common + service-scoped identity labels.
Usage: {{- include "quickstart.serviceLabels" (dict "ctx" . "service" "control-plane") | nindent 4 }}
*/}}
{{- define "quickstart.serviceLabels" -}}
{{- include "quickstart.commonLabels" .ctx }}
app.kubernetes.io/name: {{ .service }}
{{- end }}

{{/*
Selector labels for a service — narrower than serviceLabels; used in
Deployment .spec.selector + Service .spec.selector so chart upgrades
don't churn pod ownership.
*/}}
{{- define "quickstart.serviceSelectorLabels" -}}
app.kubernetes.io/name: {{ .service }}
app.kubernetes.io/part-of: trustacks
{{- end }}

{{/*
Hostname builder. Combines `ingress.hostnameSuffix` with a per-service
prefix to produce hosts like `ui.localtest.me`, `cp.localtest.me`, etc.
The k3d cluster's --port "8080:80@loadbalancer" maps these to traefik
which serves the right backend by Host header.
*/}}
{{- define "quickstart.host" -}}
{{- $prefix := .prefix -}}
{{- $ctx := .ctx -}}
{{- printf "%s.%s" $prefix $ctx.Values.ingress.hostnameSuffix -}}
{{- end }}
