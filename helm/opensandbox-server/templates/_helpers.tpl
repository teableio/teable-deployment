{{/*
Expand the name of the chart.
*/}}
{{- define "opensandbox-server.name" -}}
{{- default "opensandbox-server" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "opensandbox-server.fullname" -}}
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
Chart name and version for labels.
*/}}
{{- define "opensandbox-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opensandbox-server.labels" -}}
helm.sh/chart: {{ include "opensandbox-server.chart" . }}
{{ include "opensandbox-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: opensandbox-server
app.kubernetes.io/part-of: opensandbox
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opensandbox-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opensandbox-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Namespace to use
*/}}
{{- define "opensandbox-server.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- print "opensandbox-system" }}
{{- end }}
{{- end }}

{{/*
ServiceAccount name (same as fullname, always created by chart)
*/}}
{{- define "opensandbox-server.serviceAccountName" -}}
{{- include "opensandbox-server.fullname" . }}
{{- end }}

{{/*
Server image with tag (prepend v to semver if missing)
*/}}
{{- define "opensandbox-server.serverImage" -}}
{{- $tag := .Values.server.image.tag | default .Chart.AppVersion }}
{{- $finalTag := $tag }}
{{- if and (not (hasPrefix "v" $tag)) (regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag) }}
{{- $finalTag = printf "v%s" $tag }}
{{- end }}
{{- printf "%s:%s" .Values.server.image.repository $finalTag }}
{{- end }}

{{/*
Image pull policy
*/}}
{{- define "opensandbox-server.imagePullPolicy" -}}
{{- .Values.server.image.pullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
RBAC apiVersion
*/}}
{{- define "opensandbox-server.rbac.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1" }}
{{- print "rbac.authorization.k8s.io/v1" }}
{{- else }}
{{- print "rbac.authorization.k8s.io/v1beta1" }}
{{- end }}
{{- end }}

{{/*
ClusterRole name for server
*/}}
{{- define "opensandbox-server.roleName" -}}
{{- include "opensandbox-server.fullname" . }}-role
{{- end }}

{{/*
Render [ingress] TOML block from server.gateway.
When server.gateway.enabled=true: mode=gateway + gateway.address + gateway.route.mode; otherwise mode=direct.
*/}}
{{- define "opensandbox-server.ingressConfigToml" -}}
[ingress]
mode = {{ .Values.server.gateway.enabled | ternary "gateway" "direct" | quote }}
{{- if .Values.server.gateway.enabled }}

gateway.address = {{ include "opensandbox-server.gatewayHost" . | quote }}
gateway.route.mode = {{ .Values.server.gateway.gatewayRouteMode | quote }}
{{- end }}
{{- if include "opensandbox-server.secureAccessEnabled" . }}

[ingress.secure_access]
active_key = {{ include "opensandbox-server.secureAccessActiveKey" . | quote }}
{{- range fromYamlArray (include "opensandbox-server.secureAccessKeys" .) }}
[[ingress.secure_access.keys]]
key_id = {{ .key_id | quote }}
key = {{ .key | quote }}
{{- end }}
{{- end }}

{{- end }}

{{/*
The server config supports gateway.route.mode=wildcard to generate host-based
endpoint URLs. The standalone ingress gateway binary currently only accepts
header or uri mode, and header mode parses the Host header for wildcard hosts.
*/}}
{{- define "opensandbox-server.ingressGatewayBinaryMode" -}}
{{- if eq .Values.server.gateway.gatewayRouteMode "uri" -}}uri{{- else -}}header{{- end -}}
{{- end }}

{{/*
Gateway fixed name (independent of server)
*/}}
{{- define "opensandbox-server.ingressGatewayFullname" -}}
opensandbox-ingress-gateway
{{- end }}

{{- define "opensandbox-server.ingressGatewaySelectorLabels" -}}
app.kubernetes.io/name: {{ include "opensandbox-server.ingressGatewayFullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "opensandbox-server.ingressGatewayImage" -}}
{{- $tag := .Values.server.gateway.image.tag | default "v1.0.7" }}
{{- printf "%s:%s" .Values.server.gateway.image.repository $tag }}
{{- end }}

{{- /* Server ingress host: explicit value wins; else derived from global.baseDomain
       (infra.<base>, shared with the Infra Service console host); else the
       infra.example.com placeholder so a bare render/lint without baseDomain
       still succeeds (all hostnames become placeholders). */ -}}
{{- define "opensandbox-server.serverIngressHost" -}}
{{- $global := .Values.global | default dict -}}
{{- if .Values.server.ingress.host -}}
{{- .Values.server.ingress.host -}}
{{- else if $global.baseDomain -}}
{{- printf "infra.%s" $global.baseDomain -}}
{{- else -}}
{{- print "infra.example.com" -}}
{{- end -}}
{{- end }}

{{- define "opensandbox-server.serverIngressTlsSecret" -}}
{{- .Values.server.ingress.tls.secretName | default (printf "%s-tls" (include "opensandbox-server.serverIngressHost" .)) }}
{{- end }}

{{- /* Gateway (sandbox preview) host: explicit value wins; else derived from
       global.baseDomain (*.sandbox.<base>); else the legacy placeholder. */ -}}
{{- define "opensandbox-server.gatewayHost" -}}
{{- $global := .Values.global | default dict -}}
{{- if .Values.server.gateway.host -}}
{{- .Values.server.gateway.host -}}
{{- else if $global.baseDomain -}}
{{- printf "*.sandbox.%s" $global.baseDomain -}}
{{- else -}}
{{- print "opensandbox.example.com" -}}
{{- end -}}
{{- end }}

{{- define "opensandbox-server.gatewayIngressHost" -}}
{{- .Values.server.gateway.ingress.host | default (include "opensandbox-server.gatewayHost" .) }}
{{- end }}

{{- define "opensandbox-server.gatewayIngressTlsSecret" -}}
{{- .Values.server.gateway.ingress.tls.secretName | default (printf "%s-tls" (include "opensandbox-server.gatewayIngressHost" . | trimPrefix "*.")) }}
{{- end }}

{{- /* Non-empty ("true") when global.entry.mode=external-nginx: the umbrella-level
       external gateway terminates TLS, so this chart renders no Ingress/Certificate. */}}
{{- define "opensandbox-server.externalEntry" -}}
{{- if eq ((((.Values.global).entry).mode) | toString) "external-nginx" -}}true{{- end -}}
{{- end }}

{{- /* ---- Sandbox scheduling v2 (docs/sandbox-scheduling-v2.md) ----
       Switches live under global.sandboxScheduling so the umbrella chart and
       this chart read one knob. Defaults preserve existing behavior except
       packing (default on: only changes placement of NEW sandboxes). */}}

{{- define "opensandbox-server.schedulingValues" -}}
{{- $gs := dict -}}
{{- with .Values.global }}{{- with .sandboxScheduling }}{{- $gs = . -}}{{- end }}{{- end -}}
{{- toYaml $gs -}}
{{- end }}

{{- define "opensandbox-server.schedulingPackingEnabled" -}}
{{- $gs := fromYaml (include "opensandbox-server.schedulingValues" .) -}}
{{- $enabled := true -}}
{{- with $gs.packing }}{{- if hasKey . "enabled" }}{{- $enabled = .enabled -}}{{- end }}{{- end -}}
{{- if $enabled -}}true{{- end -}}
{{- end }}

{{- define "opensandbox-server.schedulingMemoryLimit" -}}
{{- $gs := fromYaml (include "opensandbox-server.schedulingValues" .) -}}
{{- $gs.memoryLimit | default "" -}}
{{- end }}

{{- /* ---- Sandbox private CA trust (delivery/public/helm/private-ca.md) ----
       global.sandboxPrivateCa is one knob shared with the umbrella chart. When
       enabled, the CA bundle is mounted over the OS trust store inside every
       sandbox, so OpenSSL consumers (curl, git, python ssl, Go) trust it
       without per-tool environment variables. Runtimes that ship their own
       trust store (Node, python-certifi) get env pointers on top. */}}

{{- define "opensandbox-server.privateCaValues" -}}
{{- $ca := dict -}}
{{- with .Values.global }}{{- with .sandboxPrivateCa }}{{- $ca = . -}}{{- end }}{{- end -}}
{{- toYaml $ca -}}
{{- end }}

{{- define "opensandbox-server.privateCaEnabled" -}}
{{- $ca := fromYaml (include "opensandbox-server.privateCaValues" .) -}}
{{- if $ca.enabled -}}true{{- end -}}
{{- end }}

{{- /* ---- Sandbox npm registry mirror (global.sandboxNpmRegistry) ----
       One knob shared with the umbrella chart. When set, every sandbox gets
       NPM_CONFIG_REGISTRY (npm / pnpm / bun / yarn 1) and COREPACK_NPM_REGISTRY
       (corepack downloading the package manager itself) pointed at the mirror,
       so dependency installs work in networks where registry.npmjs.org is slow
       or unreachable. Env entries already present in the operator template win.
       Note these env vars take precedence over a project .npmrc default
       registry; scoped registries (@scope:registry=...) are unaffected. */}}

{{- /* Basic render-time sanity check, shared by the global knob and the App
       Runtime override in the umbrella chart: catch a missing scheme (the
       common typo) at render instead of at runtime. The operator is trusted
       beyond that. Usage: include ... (dict "name" "<values path>" "value" $v) */}}
{{- define "opensandbox-server.validateNpmRegistry" -}}
{{- if and .value (not (or (hasPrefix "http://" .value) (hasPrefix "https://" .value))) -}}
{{- fail (printf "%s must be an http(s) URL, got %q" .name .value) -}}
{{- end -}}
{{- end }}

{{- define "opensandbox-server.sandboxNpmRegistry" -}}
{{- $reg := "" -}}
{{- with .Values.global }}{{- with .sandboxNpmRegistry }}{{- $reg = . -}}{{- end }}{{- end -}}
{{- include "opensandbox-server.validateNpmRegistry" (dict "name" "global.sandboxNpmRegistry" "value" $reg) -}}
{{- $reg -}}
{{- end }}

{{- /* ---- Sandbox security hardening (helm/README.md) ----
       global.sandboxSecurity is one knob shared with the umbrella chart. Unlike
       every other overlay here, these switches WIN over the operator template:
       the shipped templates set runAsUser: 0 explicitly, so "template wins"
       would make the switch a no-op. */}}

{{- define "opensandbox-server.securityValues" -}}
{{- $sec := dict -}}
{{- with .Values.global }}{{- with .sandboxSecurity }}{{- $sec = . -}}{{- end }}{{- end -}}
{{- toYaml $sec -}}
{{- end }}

{{- define "opensandbox-server.securityNonRootEnabled" -}}
{{- $sec := fromYaml (include "opensandbox-server.securityValues" .) -}}
{{- with $sec.nonRoot }}{{- if .enabled -}}true{{- end }}{{- end -}}
{{- end }}

{{- define "opensandbox-server.securitySeccompProfile" -}}
{{- $sec := fromYaml (include "opensandbox-server.securityValues" .) -}}
{{- $sec.seccompProfile | default "" -}}
{{- end }}

{{- define "opensandbox-server.securityEnabled" -}}
{{- if or (include "opensandbox-server.securityNonRootEnabled" .) (include "opensandbox-server.securitySeccompProfile" .) -}}true{{- end -}}
{{- end }}

{{- /* True when a batchsandbox template must be mounted: either the operator
       provided one, or scheduling/private-CA/hardening switches synthesize one.
       config.toml already points at the file path by default, so mounting it
       is always safe. */}}
{{- define "opensandbox-server.hasBatchSandboxTemplate" -}}
{{- if or .Values.server.batchSandboxTemplate (include "opensandbox-server.schedulingPackingEnabled" .) (include "opensandbox-server.schedulingMemoryLimit" .) (include "opensandbox-server.privateCaEnabled" .) (include "opensandbox-server.securityEnabled" .) (include "opensandbox-server.sandboxNpmRegistry" .) -}}true{{- end -}}
{{- end }}

{{- /* Render the batchsandbox template with scheduling switches applied.
       Merge direction: the operator template always wins on conflicts
       (mergeOverwrite dst=overlay src=template). Round-trips through
       fromYaml/toYaml, so comments in the source template are dropped. */}}
{{- define "opensandbox-server.renderedBatchSandboxTemplate" -}}
{{- $packing := include "opensandbox-server.schedulingPackingEnabled" . -}}
{{- $memoryLimit := include "opensandbox-server.schedulingMemoryLimit" . -}}
{{- $privateCa := include "opensandbox-server.privateCaEnabled" . -}}
{{- $nonRoot := include "opensandbox-server.securityNonRootEnabled" . -}}
{{- $seccomp := include "opensandbox-server.securitySeccompProfile" . -}}
{{- $npmRegistry := include "opensandbox-server.sandboxNpmRegistry" . -}}
{{- if not (or $packing $memoryLimit $privateCa $nonRoot $seccomp $npmRegistry) -}}
{{- .Values.server.batchSandboxTemplate -}}
{{- else -}}
{{- $tpl := dict -}}
{{- if .Values.server.batchSandboxTemplate -}}
{{- $tpl = fromYaml .Values.server.batchSandboxTemplate -}}
{{- if not (kindIs "map" $tpl) -}}
{{- fail "server.batchSandboxTemplate is not valid YAML" -}}
{{- end -}}
{{- end -}}
{{- $merged := $tpl -}}
{{- if $packing -}}
{{- /* Prefer co-locating sandboxes on the fullest node (bin packing) instead of
       the scheduler default LeastAllocated spread. opensandbox.io/id is the
       stable label every sandbox pod carries. */ -}}
{{- $affinityOverlay := fromYaml `
spec:
  template:
    spec:
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchExpressions:
                    - key: opensandbox.io/id
                      operator: Exists
` -}}
{{- $merged = mustMergeOverwrite $affinityOverlay $merged -}}
{{- end -}}
{{- if $memoryLimit -}}
{{- $podSpec := dig "spec" "template" "spec" dict $merged -}}
{{- $containers := $podSpec.containers | default list -}}
{{- $touched := false -}}
{{- range $c := $containers -}}
{{- if eq (get $c "name") "sandbox" -}}
{{- $resources := $c.resources | default dict -}}
{{- $limits := $resources.limits | default dict -}}
{{- if not (hasKey $limits "memory") -}}{{- $_ := set $limits "memory" $memoryLimit -}}{{- end -}}
{{- $_ := set $resources "limits" $limits -}}
{{- $_ := set $c "resources" $resources -}}
{{- $touched = true -}}
{{- end -}}
{{- end -}}
{{- if not $touched -}}
{{- /* No sandbox container entry in the template yet: create one so the
       default memory limit applies. The runtime merges its own fields in. */ -}}
{{- $containers = append $containers (dict "name" "sandbox" "resources" (dict "limits" (dict "memory" $memoryLimit))) -}}
{{- end -}}
{{- $spec := $merged.spec | default dict -}}
{{- $template := $spec.template | default dict -}}
{{- $newPodSpec := $template.spec | default dict -}}
{{- $_ := set $newPodSpec "containers" $containers -}}
{{- $_ := set $template "spec" $newPodSpec -}}
{{- $_ := set $spec "template" $template -}}
{{- $_ := set $merged "spec" $spec -}}
{{- end -}}
{{- if $privateCa -}}
{{- $ca := fromYaml (include "opensandbox-server.privateCaValues" .) -}}
{{- $caConfigMap := required "global.sandboxPrivateCa.configMapName is required when global.sandboxPrivateCa.enabled=true" $ca.configMapName -}}
{{- $caKey := $ca.key | default "root-ca.crt" -}}
{{- $caStorePath := $ca.caCertificatesPath | default "/etc/ssl/certs/ca-certificates.crt" -}}
{{- $caFilePath := "/etc/ssl/private-ca/root-ca.crt" -}}
{{- $caVolume := "sandbox-private-ca" -}}
{{- $podSpec := dig "spec" "template" "spec" dict $merged -}}
{{- $containers := $podSpec.containers | default list -}}
{{- /* Overwriting the OS trust store means the ConfigMap must hold a full
       bundle (public roots plus the corporate root), not a single root. */ -}}
{{- $caMounts := list
      (dict "name" $caVolume "mountPath" $caStorePath "subPath" $caKey "readOnly" true)
      (dict "name" $caVolume "mountPath" $caFilePath "subPath" $caKey "readOnly" true) -}}
{{- /* Runtimes that ignore the OS store get explicit pointers.
       NODE_EXTRA_CA_CERTS extends Node's built-in roots; SSL_CERT_FILE covers
       OpenSSL clients that resolve the store lazily (Python's ssl module, Go,
       Ruby); REQUESTS_CA_BUNDLE covers requests/pip, which read certifi. All
       three point at a full bundle, so their replace semantics are safe. */ -}}
{{- $caEnv := list
      (dict "name" "NODE_EXTRA_CA_CERTS" "value" $caFilePath)
      (dict "name" "SSL_CERT_FILE" "value" $caStorePath)
      (dict "name" "REQUESTS_CA_BUNDLE" "value" $caStorePath) -}}
{{- $touched := false -}}
{{- range $c := $containers -}}
{{- if eq (get $c "name") "sandbox" -}}
{{- /* Silently skipping a colliding mount would render happily while leaving
       the sandbox trusting some other file, so a collision is a hard error. */ -}}
{{- $mounts := $c.volumeMounts | default list -}}
{{- range $m := $mounts -}}
{{- if or (eq (get $m "mountPath") $caStorePath) (eq (get $m "mountPath") $caFilePath) -}}
{{- fail (printf "server.batchSandboxTemplate already mounts %s; remove it or disable global.sandboxPrivateCa (the switch owns %s, %s and the volume %q)" (get $m "mountPath") $caStorePath $caFilePath $caVolume) -}}
{{- end -}}
{{- end -}}
{{- $_ := set $c "volumeMounts" (concat $mounts $caMounts) -}}
{{- $env := $c.env | default list -}}
{{- $names := list -}}
{{- range $e := $env }}{{- $names = append $names (get $e "name") -}}{{- end -}}
{{- range $e := $caEnv }}{{- if not (has (get $e "name") $names) }}{{- $env = append $env $e -}}{{- end }}{{- end -}}
{{- $_ := set $c "env" $env -}}
{{- $touched = true -}}
{{- end -}}
{{- end -}}
{{- if not $touched -}}
{{- $containers = append $containers (dict "name" "sandbox" "volumeMounts" $caMounts "env" $caEnv) -}}
{{- end -}}
{{- $volumes := $podSpec.volumes | default list -}}
{{- range $v := $volumes -}}
{{- if eq (get $v "name") $caVolume -}}
{{- fail (printf "server.batchSandboxTemplate already defines the volume %q, which global.sandboxPrivateCa owns; rename it" $caVolume) -}}
{{- end -}}
{{- end -}}
{{- $volumes = append $volumes (dict "name" $caVolume "configMap" (dict "name" $caConfigMap)) -}}
{{- $spec := $merged.spec | default dict -}}
{{- $template := $spec.template | default dict -}}
{{- $newPodSpec := $template.spec | default dict -}}
{{- $_ := set $newPodSpec "containers" $containers -}}
{{- $_ := set $newPodSpec "volumes" $volumes -}}
{{- $_ := set $template "spec" $newPodSpec -}}
{{- $_ := set $spec "template" $template -}}
{{- $_ := set $merged "spec" $spec -}}
{{- end -}}
{{- if $npmRegistry -}}
{{- $npmEnv := list
      (dict "name" "NPM_CONFIG_REGISTRY" "value" $npmRegistry)
      (dict "name" "COREPACK_NPM_REGISTRY" "value" $npmRegistry) -}}
{{- $podSpec := dig "spec" "template" "spec" dict $merged -}}
{{- $containers := $podSpec.containers | default list -}}
{{- $touched := false -}}
{{- range $c := $containers -}}
{{- if eq (get $c "name") "sandbox" -}}
{{- /* Same precedence as the private-CA env: an entry already present in the
       operator template wins, so a single deployment can pin its own
       registry without fighting the global switch. */ -}}
{{- $env := $c.env | default list -}}
{{- $names := list -}}
{{- range $e := $env }}{{- $names = append $names (get $e "name") -}}{{- end -}}
{{- range $e := $npmEnv }}{{- if not (has (get $e "name") $names) }}{{- $env = append $env $e -}}{{- end }}{{- end -}}
{{- $_ := set $c "env" $env -}}
{{- $touched = true -}}
{{- end -}}
{{- end -}}
{{- if not $touched -}}
{{- $containers = append $containers (dict "name" "sandbox" "env" $npmEnv) -}}
{{- end -}}
{{- $spec := $merged.spec | default dict -}}
{{- $template := $spec.template | default dict -}}
{{- $newPodSpec := $template.spec | default dict -}}
{{- $_ := set $newPodSpec "containers" $containers -}}
{{- $_ := set $template "spec" $newPodSpec -}}
{{- $_ := set $spec "template" $template -}}
{{- $_ := set $merged "spec" $spec -}}
{{- end -}}
{{- if or $nonRoot $seccomp -}}
{{- $sec := fromYaml (include "opensandbox-server.securityValues" .) -}}
{{- $podSpec := dig "spec" "template" "spec" dict $merged -}}
{{- $podSc := $podSpec.securityContext | default dict -}}
{{- if $seccomp -}}
{{- $_ := set $podSc "seccompProfile" (dict "type" $seccomp) -}}
{{- end -}}
{{- $containers := $podSpec.containers | default list -}}
{{- /* Container-level securityContext wins over the pod-level one, so every
       field the switches own has to be written at BOTH levels: a template
       carrying a container-level runAsUser: 0 would otherwise contradict
       runAsNonRoot (pod fails to start), and a container-level Unconfined
       profile would survive the seccomp switch. Container-level fields reach
       the pod through the server's template backfill (opensandbox-server >=
       v0.2.0-fix7); older servers drop them. */ -}}
{{- $hardened := dict -}}
{{- if $seccomp -}}
{{- $_ := set $hardened "seccompProfile" (dict "type" $seccomp) -}}
{{- end -}}
{{- if $nonRoot -}}
{{- /* uid/gid are fixed, not configurable: execd only skips the credential
       switch when the identity it runs as equals the identity the command asks
       for, and the agent image bakes in uid/gid 1000. Any other value calls
       setgroups() without CAP_SETGID and every command fails with "operation
       not permitted". */ -}}
{{- $uid := 1000 -}}
{{- $gid := 1000 -}}
{{- $_ := set $podSc "runAsUser" $uid -}}
{{- $_ := set $podSc "runAsGroup" $gid -}}
{{- $_ := set $podSc "runAsNonRoot" true -}}
{{- /* fsGroup: 0 only existed so the root entrypoint could hand volumes over,
       and it now conflicts with the non-root identity. A deliberate non-zero
       fsGroup is how some CSI drivers grant an unprivileged process access to
       a persistent volume, so leave that one alone. */ -}}
{{- if eq (toString ($podSc.fsGroup | default 0)) "0" -}}
{{- $_ := unset $podSc "fsGroup" -}}
{{- $_ := unset $podSc "fsGroupChangePolicy" -}}
{{- end -}}
{{- $_ := set $hardened "runAsUser" $uid -}}
{{- $_ := set $hardened "runAsGroup" $gid -}}
{{- $_ := set $hardened "runAsNonRoot" true -}}
{{- $_ := set $hardened "allowPrivilegeEscalation" false -}}
{{- /* Whole map, not a merge: a template's capabilities.add would survive a
       deep merge and hand the capability straight back after the drop. */ -}}
{{- $_ := set $hardened "capabilities" (dict "drop" (list "ALL")) -}}
{{- end -}}
{{- $touched := false -}}
{{- range $c := $containers -}}
{{- if eq (get $c "name") "sandbox" -}}
{{- $cSc := $c.securityContext | default dict -}}
{{- range $k := keys $hardened }}{{- $_ := set $cSc $k (get $hardened $k) -}}{{- end -}}
{{- $_ := set $c "securityContext" $cSc -}}
{{- $touched = true -}}
{{- end -}}
{{- end -}}
{{- if not $touched -}}
{{- $containers = append $containers (dict "name" "sandbox" "securityContext" $hardened) -}}
{{- end -}}
{{- $spec := $merged.spec | default dict -}}
{{- $template := $spec.template | default dict -}}
{{- $newPodSpec := $template.spec | default dict -}}
{{- $_ := set $newPodSpec "securityContext" $podSc -}}
{{- $_ := set $newPodSpec "containers" $containers -}}
{{- $_ := set $template "spec" $newPodSpec -}}
{{- $_ := set $spec "template" $template -}}
{{- $_ := set $merged "spec" $spec -}}
{{- end -}}
{{- toYaml $merged -}}
{{- end -}}
{{- end }}

{{/*
Active signing key id: explicit activeKey, else the first configured key_id.
activeKey only applies to explicit keys; a generated key is always active.
*/}}
{{- define "opensandbox-server.secureAccessActiveKey" -}}
{{- $sa := .Values.server.gateway.secureAccess -}}
{{- if and $sa.keys $sa.activeKey -}}{{ $sa.activeKey }}{{- else -}}{{ (index (fromYamlArray (include "opensandbox-server.secureAccessKeys" .)) 0).key_id }}{{- end -}}
{{- end }}

{{/*
True when OSEP-0011 signing keys are in effect (explicit keys, or autoGenerate):
the server config then renders as a Secret (it contains the keys) and the
gateway reads its key string from a Secret-backed env var instead of a plain
container arg. Values-only on purpose (no lookup, no randomness), so the
umbrella chart can call it with a {Values: <this chart's values>} context.
*/}}
{{- define "opensandbox-server.secureAccessEnabled" -}}
{{- $sa := .Values.server.gateway.secureAccess -}}
{{- if and .Values.server.gateway.enabled (or $sa.keys $sa.autoGenerate) -}}true{{- end -}}
{{- end }}

{{/*
Effective signing keys as a YAML list (read it back with fromYamlArray).
Explicit secureAccess.keys always win and are passed through untouched.
Otherwise, when autoGenerate is on, a single key with key_id "a" is used (see
secureAccessGeneratedKey). Empty when secure access is not in effect.
*/}}
{{- define "opensandbox-server.secureAccessKeys" -}}
{{- $sa := .Values.server.gateway.secureAccess -}}
{{- if $sa.keys -}}
{{- toYaml $sa.keys -}}
{{- else if include "opensandbox-server.secureAccessEnabled" . -}}
{{- toYaml (list (dict "key_id" "a" "key" (include "opensandbox-server.secureAccessGeneratedKey" .))) -}}
{{- end -}}
{{- end }}

{{/*
Name of the gateway Secret holding the key string. It also persists a
generated key (data key "generated-key") across upgrades.
*/}}
{{- define "opensandbox-server.secureAccessSecretName" -}}
{{- include "opensandbox-server.ingressGatewayFullname" . }}-secure-access
{{- end }}

{{/*
Generated signing key (base64 of 32 random bytes) for autoGenerate.

Persistence: reuse the "generated-key" entry of the gateway Secret written by
an earlier release (lookup); generate a new key only when there is none (first
install, or the Secret was deleted to rotate the key). The entry survives a
detour through explicit keys (apply never prunes data keys written through
stringData), so switching back to autoGenerate reuses the old generated key.

Single value per render: the key lands in four places rendered from two
template files -- the server config Secret plus its checksum annotation
(server/workload.yaml), and the gateway Secret plus its checksum annotation
(gateway/workload.yaml). Each randBytes call returns a different value, so the
first call caches the result in .Values.server.gateway.secureAccess._generatedKey
and every later call returns the cached value. This works because Helm renders
all templates of a chart against one shared .Values map; the cache lives only
in the render-time copy of the values and is never stored in the release.

lookup returns nothing without cluster access (helm template, --dry-run,
Argo CD), so those renderers get a fresh key on every render: they must set
explicit keys instead.
*/}}
{{- define "opensandbox-server.secureAccessGeneratedKey" -}}
{{- $sa := .Values.server.gateway.secureAccess -}}
{{- if not (get $sa "_generatedKey") -}}
{{- $previous := "" -}}
{{- $existing := lookup "v1" "Secret" (include "opensandbox-server.namespace" .) (include "opensandbox-server.secureAccessSecretName" .) -}}
{{- with $existing }}{{- with .data }}{{- with (get . "generated-key") }}{{- $previous = b64dec . -}}{{- end }}{{- end }}{{- end -}}
{{- $_ := set $sa "_generatedKey" ($previous | default (randBytes 32)) -}}
{{- end -}}
{{- get $sa "_generatedKey" -}}
{{- end }}

{{/*
Gateway key string: key_id=base64[,key_id=base64], the --secure-access-keys format.
*/}}
{{- define "opensandbox-server.secureAccessKeyString" -}}
{{- range $i, $k := fromYamlArray (include "opensandbox-server.secureAccessKeys" .) }}{{ if $i }},{{ end }}{{ $k.key_id }}={{ $k.key }}{{- end }}
{{- end }}
