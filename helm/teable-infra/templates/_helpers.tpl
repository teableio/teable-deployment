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

{{- /* git-registry public URL: the Infra host plus gitRegistry.basePath (default /git).
       Git shares the Infra Service domain -- the production-proven shape -- so a bare
       install needs no dedicated git DNS record. The URL follows basePath, matching
       GIT_REGISTRY_BASE_PATH on the workload. */ -}}
{{- define "teable-infra.gitPublicUrl" -}}
https://{{ include "teable-infra.infraHost" . }}{{ .Values.gitRegistry.basePath }}
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

{{- /* Public S3 (MinIO) host: explicit minio.host wins, else the Infra host. Presigned
       URLs are path-style and route by bucket path prefixes on the shared host, so a
       bare install needs no dedicated s3 DNS record. */ -}}
{{- define "teable-infra.s3Host" -}}
{{- if .Values.minio.host -}}{{ .Values.minio.host }}{{- else -}}{{ include "teable-infra.infraHost" . }}{{- end -}}
{{- end -}}

{{- /* Public S3 URL: https://<s3Host> (presigned URLs and the artifact store endpoint are always TLS). */ -}}
{{- define "teable-infra.s3Url" -}}
https://{{ include "teable-infra.s3Host" . }}
{{- end -}}

{{- /* Non-empty ("true") when global.entry.mode=external-nginx: an external gateway
       terminates TLS and routes to Services, so no Ingress/Certificate objects are
       rendered; templates/nginx-routes.yaml declares the routing contract instead. */}}
{{- define "teable-infra.externalEntry" -}}
{{- if eq ((((.Values.global).entry).mode) | toString) "external-nginx" -}}true{{- end -}}
{{- end }}
