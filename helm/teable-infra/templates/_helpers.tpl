{{- /*
Root-domain helpers: derive per-service hostnames from global.baseDomain.
Every helper falls back to the legacy example.com placeholder (or "") when
global.baseDomain is blank, so behavior only changes when baseDomain is set.
Explicit values in a profile/values file always win: templates use these
helpers only as the `default` fallback of the corresponding field.
*/}}

{{- /* Root domain. Falls back to the example.com placeholder when global.baseDomain is unset, so a
       bare `helm install`/`helm lint` renders cleanly (all hostnames become placeholders) instead of
       hitting `required`. Setting global.baseDomain switches every derived hostname to the real domain. */ -}}
{{- define "teable-infra.baseDomain" -}}
{{- $global := .Values.global | default dict -}}
{{- $global.baseDomain | default "example.com" -}}
{{- end -}}

{{- /* Infra Service public host: infra.<baseDomain>, else the example.com placeholder. */ -}}
{{- define "teable-infra.infraHost" -}}
{{- $base := include "teable-infra.baseDomain" . -}}
{{- if $base -}}infra.{{ $base }}{{- else -}}infra.example.com{{- end -}}
{{- end -}}

{{- /* Infra Service public origin: https://<infraHost>. */ -}}
{{- define "teable-infra.infraUrl" -}}
https://{{ include "teable-infra.infraHost" . }}
{{- end -}}

{{- /* Sandbox preview wildcard: *.sandbox.<baseDomain>, else the example.com placeholder. */ -}}
{{- define "teable-infra.sandboxWildcard" -}}
{{- $base := include "teable-infra.baseDomain" . -}}
{{- if $base -}}*.sandbox.{{ $base }}{{- else -}}*.sandbox.example.com{{- end -}}
{{- end -}}

{{- /* App Runtime apex domain: app.<baseDomain>, else the example.com placeholder. */ -}}
{{- define "teable-infra.appDomain" -}}
{{- $base := include "teable-infra.baseDomain" . -}}
{{- if $base -}}app.{{ $base }}{{- else -}}app.example.com{{- end -}}
{{- end -}}

{{- /* App Runtime wildcard: *.app.<baseDomain>, else the example.com placeholder. */ -}}
{{- define "teable-infra.appWildcard" -}}
{{- $base := include "teable-infra.baseDomain" . -}}
{{- if $base -}}*.app.{{ $base }}{{- else -}}*.app.example.com{{- end -}}
{{- end -}}

{{- /* git-registry public URL: https://git.<baseDomain> plus gitRegistry.basePath.
       The derived host serves at the root by default (basePath ""), so the URL must
       not carry a path segment the server never strips; when basePath is set the
       URL follows it, matching GIT_REGISTRY_BASE_PATH on the workload. */ -}}
{{- define "teable-infra.gitPublicUrl" -}}
{{- $base := include "teable-infra.baseDomain" . -}}
{{- if $base -}}https://git.{{ $base }}{{ .Values.gitRegistry.basePath }}{{- end -}}
{{- end -}}

{{- /* Teable app host: explicit teable.host wins, else the apex of baseDomain (the app owns the root of the domain), else an example.org placeholder. */ -}}
{{- define "teable-infra.teableHost" -}}
{{- $base := include "teable-infra.baseDomain" . -}}
{{- if .Values.teable.host -}}{{ .Values.teable.host }}{{- else if $base -}}{{ $base }}{{- else -}}teable.example.org{{- end -}}
{{- end -}}

{{- /* Teable app public origin: explicit teable.publicOrigin wins, else https://<teableHost>. */ -}}
{{- define "teable-infra.teableOrigin" -}}
{{- if .Values.teable.publicOrigin -}}{{ .Values.teable.publicOrigin }}{{- else -}}https://{{ include "teable-infra.teableHost" . }}{{- end -}}
{{- end -}}

{{- /* Public S3 (MinIO) host: explicit minio.host wins, else s3.<baseDomain>, else an example.org placeholder. */ -}}
{{- define "teable-infra.s3Host" -}}
{{- $base := include "teable-infra.baseDomain" . -}}
{{- if .Values.minio.host -}}{{ .Values.minio.host }}{{- else if $base -}}s3.{{ $base }}{{- else -}}s3.example.org{{- end -}}
{{- end -}}

{{- /* Public S3 URL: https://<s3Host> (presigned URLs and the artifact store endpoint are always TLS). */ -}}
{{- define "teable-infra.s3Url" -}}
https://{{ include "teable-infra.s3Host" . }}
{{- end -}}
