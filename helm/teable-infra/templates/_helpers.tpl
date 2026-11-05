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

{{- /* appRuntime.customDomains, checked as a whole at render time with the same rules infra-service applies
       at start (it skips entries that fail them): host is a plain DNS name outside the app domain and not one
       of the hosts this release already serves, target is the app's access link, its name or its app ID, and
       no host appears twice. Called with the root context. */ -}}
{{- define "teable-infra.validateAppCustomDomains" -}}
{{- $appDomain := .Values.infraService.appRuntime.domain | default (include "teable-infra.appDomain" .) | lower | trimSuffix "." -}}
{{- $prefix := "" -}}
{{- if eq (.Values.infraService.appRuntime.hostMatchMode | default "suffix") "prefix" -}}
{{- $prefix = .Values.infraService.appRuntime.hostPrefix | default "" | lower -}}
{{- end -}}
{{- $sandboxDomain := include "teable-infra.sandboxWildcard" . | trimPrefix "*." -}}
{{- $reserved := list (.Values.infraService.ingress.host | default (include "teable-infra.infraHost" .)) (include "teable-infra.s3Host" .) -}}
{{- with .Values.gitRegistry.ingress.host }}{{ $reserved = append $reserved . }}{{ end -}}
{{- if .Values.teable.enabled }}{{ $reserved = append $reserved (include "teable-infra.teableHost" .) }}{{ end -}}
{{- $label := "[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?" -}}
{{- $seen := dict -}}
{{- range .Values.appRuntime.customDomains -}}
{{- $host := .host | default "" | toString | lower | trimSuffix "." -}}
{{- $target := .target | default "" | toString | lower | trimSuffix "." -}}
{{- if or (gt (len $host) 253) (not (regexMatch (printf "^(%s\\.)+%s$" $label $label) $host)) -}}
{{- fail (printf "appRuntime.customDomains: host must be a domain name such as portal.example.org (got %q)" (.host | default "")) -}}
{{- end -}}
{{- if or (eq $host $appDomain) (hasSuffix (printf ".%s" $appDomain) $host) (hasSuffix (printf ".%s" $sandboxDomain) $host) (has $host $reserved) -}}
{{- fail (printf "appRuntime.customDomains: %s is already served by this release (app, sandbox, infra, storage or Teable host); pick another domain" $host) -}}
{{- end -}}
{{- if hasKey $seen $host -}}
{{- fail (printf "appRuntime.customDomains lists %s more than once" $host) -}}
{{- end -}}
{{- $_ := set $seen $host true -}}
{{- $name := $target -}}
{{- if contains "." $target -}}
{{- $name = trimSuffix (printf ".%s" $appDomain) $target -}}
{{- if or (eq $name $target) (not (hasPrefix $prefix $name)) -}}
{{- fail (printf "appRuntime.customDomains: %s needs a target such as portal.%s (the app's access link), got %q" $host $appDomain (.target | default "")) -}}
{{- end -}}
{{- end -}}
{{- if not (regexMatch (printf "^%s$" $label) $name) -}}
{{- fail (printf "appRuntime.customDomains: %s needs a target such as portal.%s (the app's access link), got %q" $host $appDomain (.target | default "")) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* Per-domain object name: readable, unique (hash suffix: a-b.example.org and a.b-example.org must not
       collide) and well under the 253-character limit. */ -}}
{{- define "teable-infra.appCustomDomainName" -}}
{{- $host := . | lower | trimSuffix "." -}}
{{- printf "app-domain-%s-%s" ($host | replace "." "-" | trunc 40 | trimSuffix "-") (sha256sum $host | trunc 8) -}}
{{- end -}}

{{- /* APP_RUNTIME_CUSTOM_DOMAINS for infra-service: host=target pairs, comma-separated. */ -}}
{{- define "teable-infra.appCustomDomainsEnv" -}}
{{- $pairs := list -}}
{{- include "teable-infra.validateAppCustomDomains" . -}}
{{- range .Values.appRuntime.customDomains -}}
{{- $pairs = append $pairs (printf "%s=%s" (.host | lower | trimSuffix ".") (.target | lower | trimSuffix ".")) -}}
{{- end -}}
{{- join "," $pairs -}}
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

{{- /* Non-empty ("true") when the opensandbox-server sub-chart has OSEP-0011 secure
       access in effect (gateway enabled with explicit keys or autoGenerate). Delegates
       to the sub-chart helper so "in effect" has a single definition; that helper reads
       values only, so a {Values: <sub-chart values>} context is enough. */}}
{{- define "teable-infra.sandboxSecureAccess" -}}
{{- include "opensandbox-server.secureAccessEnabled" (dict "Values" (index .Values "opensandbox-server")) -}}
{{- end }}

{{- /* Namespaces where browser-driven pod exec (console terminal, sandbox file browser,
       benchmark) is allowed, comma-joined. infra-service/rbac.yaml renders one exec Role per
       entry, and the workload passes the same list as EXEC_NAMESPACES so the service refuses
       any other target -- including the JuiceFS mount namespace it may exec into itself. */}}
{{- define "teable-infra.execNamespaces" -}}
{{- join "," ((.Values.infraService.rbac).execNamespaces | default (list .Values.sandboxNamespace.name)) -}}
{{- end }}
