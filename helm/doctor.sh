#!/usr/bin/env bash
# Post-install check for a teable-infra Helm install.
#
#   ./doctor.sh [RELEASE] [NAMESPACE]     defaults: teable opensandbox-system
#   ./doctor.sh --from vYYYY.M.N          additionally list the migrations still
#                                         pending between platform release
#                                         vYYYY.M.N and this checkout's release
#
# Checks that the stack is healthy and that the images running in the cluster
# still match what the Helm release installed (drift happens when images are
# swapped by hand with kubectl set image).
set -euo pipefail

fail=0
drift=0

say() { printf '%s\n' "$*"; }
ok() { say "[ok] $*"; }
warn() { say "[!] $*"; }
bad() { say "[x] $*"; fail=1; }

# --- BEGIN shared doctor block: calver + migration catalog helpers ---
# Keep this block byte-identical between docker/all-in-one/doctor.sh and
# helm/doctor.sh (the repository test suite asserts it).

# True when $1 looks like a platform release id (calver: v<year>.<month>.<seq>).
calver_valid() {
  printf '%s\n' "$1" | grep -Eq '^v[0-9]{4}\.[0-9]{1,2}\.[0-9]+$'
}

# True when release $1 is strictly newer than release $2. Segments compare
# numerically: string order would sort v2026.7.9 after v2026.7.10.
calver_newer() {
  awk -v a="${1#v}" -v b="${2#v}" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      d = (x[i] + 0) - (y[i] + 0)
      if (d != 0) exit (d > 0 ? 0 : 1)
    }
    exit 1
  }'
}

# From the manifest at $1, print the migrationCatalog entries introduced after
# release $2 -- "<introducedIn>|<id>|<irreversible>|<guide>" per line, oldest
# first (the manifest is generated in that order).
pending_migrations() {
  awk '
    function flushrow() { if (id != "") print ver "|" id "|" irr "|" guide; id = "" }
    /^migrationCatalog:/ { inc = 1; next }
    /^[A-Za-z]/          { if (inc) flushrow(); inc = 0 }
    !inc                 { next }
    /^- id: /            { flushrow(); id = $3; ver = ""; irr = "false"; guide = "" }
    /^  guide: /         { guide = $2 }
    /^  introducedIn: /  { ver = $2 }
    /^  irreversible: /  { irr = $2 }
    END                  { flushrow() }
  ' "$1" | while IFS='|' read -r ver id irr guide; do
    [ -n "$ver" ] || continue
    if calver_newer "$ver" "$2"; then
      printf '%s|%s|%s|%s\n' "$ver" "$id" "$irr" "$guide"
    fi
  done
}

# Report what an install still on release $2 must run before upgrading to the
# release described by the manifest at $1.
report_pending_migrations() {
  vf="$1"; from="$2"
  if [ ! -f "$vf" ]; then
    printf '[!] cannot compute pending migrations: %s not found\n' "$vf"
    return 0
  fi
  target="$(awk '/^platformRelease: /{print $2; exit}' "$vf")"
  if ! grep -q '^migrationCatalog:' "$vf"; then
    printf '[!] %s carries no migrationCatalog (predates it); use a checkout of a\n' "$vf"
    printf '    newer platform release to compute pending migrations\n'
    return 0
  fi
  if [ -n "$target" ] && calver_newer "$from" "$target"; then
    printf '[!] --from %s is newer than the release this checkout ships (%s);\n' "$from" "$target"
    printf '    an empty result would be meaningless -- check the value, or run this\n'
    printf '    from a checkout at or above your installed release\n'
    return 0
  fi
  pending="$(pending_migrations "$vf" "$from")"
  printf 'Upgrading %s -> %s:\n' "$from" "${target:-this release}"
  if [ -z "$pending" ]; then
    printf '  no pending migrations -- updated images are the whole upgrade (see VERSIONS.md)\n'
  else
    printf '  pending migrations, run oldest first (details: VERSIONS.md and each guide):\n'
    printf '%s\n' "$pending" | while IFS='|' read -r ver id irr guide; do
      note=""
      [ "$irr" = "true" ] && note=" (irreversible -- back up first)"
      printf '  - %s introduced in %s%s\n      guide: %s\n' "$id" "$ver" "$note" "$guide"
    done
  fi
}
# --- END shared doctor block ---

RELEASE="teable"
NAMESPACE="opensandbox-system"
FROM=""
narg=0
while [ $# -gt 0 ]; do
  case "$1" in
    --from)   [ -n "${2:-}" ] || { say "[x] --from needs a platform release (e.g. --from v2026.7.0)"; exit 2; }
              FROM="$2"; shift 2 ;;
    --from=*) FROM="${1#--from=}"; shift ;;
    -*)       say "[x] unknown flag: $1"; exit 2 ;;
    *)        narg=$((narg+1))
              case "${narg}" in
                1) RELEASE="$1" ;;
                2) NAMESPACE="$1" ;;
                *) say "[x] too many arguments: $1"; exit 2 ;;
              esac
              shift ;;
  esac
done

if [ -n "${FROM}" ]; then
  calver_valid "${FROM}" || { say "[x] --from expects a platform release like v2026.7.0, got: ${FROM}"; exit 2; }
  report_pending_migrations "$(cd "$(dirname "$0")" && pwd)/../versions.yaml" "${FROM}"
  say ""
fi

command -v kubectl >/dev/null || { bad "kubectl not found"; exit 1; }
command -v helm >/dev/null || { bad "helm not found"; exit 1; }

helm status "${RELEASE}" -n "${NAMESPACE}" >/dev/null 2>&1 \
  || { bad "Helm release '${RELEASE}' not found in namespace '${NAMESPACE}'"; exit 1; }
ok "Helm release '${RELEASE}' found"

manifest="$(mktemp)"
trap 'rm -f "${manifest}"' EXIT
helm get manifest "${RELEASE}" -n "${NAMESPACE}" > "${manifest}"

# --- 1. Workload health -------------------------------------------------------
# Every Deployment/DaemonSet the release installed must be fully ready.
while IFS='|' read -r kind name ns; do
  [ -n "${kind}" ] || continue
  ns="${ns:-${NAMESPACE}}"
  case "${kind}" in
    Deployment)
      read -r desired ready < <(kubectl get deploy "${name}" -n "${ns}" \
        -o jsonpath='{.spec.replicas} {.status.readyReplicas}' 2>/dev/null; echo) || true
      ;;
    DaemonSet)
      read -r desired ready < <(kubectl get ds "${name}" -n "${ns}" \
        -o jsonpath='{.status.desiredNumberScheduled} {.status.numberReady}' 2>/dev/null; echo) || true
      ;;
    *) continue ;;
  esac
  if [ -z "${desired:-}" ]; then
    bad "${kind} ${ns}/${name}: not found in cluster"
  elif [ "${ready:-0}" = "${desired}" ]; then
    ok "${kind} ${ns}/${name}: ${ready}/${desired} ready"
  else
    bad "${kind} ${ns}/${name}: ${ready:-0}/${desired} ready"
  fi
done < <(awk '
  /^---/ { kind=""; name=""; ns="" }
  /^kind: /       { kind=$2 }
  /^  name: /     { if (name=="") name=$2 }
  /^  namespace: /{ if (ns=="") ns=$2 }
  /^spec:/ && (kind=="Deployment" || kind=="DaemonSet") && name!="" {
    gsub(/"/,"",name); gsub(/"/,"",ns); print kind "|" name "|" ns; kind=""
  }
' "${manifest}")

# --- 2. Image drift -----------------------------------------------------------
# Compare the images the Helm release says each workload runs against what the
# cluster actually runs.
while IFS='|' read -r kind name ns want; do
  [ -n "${kind}" ] || continue
  ns="${ns:-${NAMESPACE}}"
  res="deploy"; [ "${kind}" = "DaemonSet" ] && res="ds"
  live="$(kubectl get "${res}" "${name}" -n "${ns}" \
    -o jsonpath='{range .spec.template.spec.containers[*]}{.image}{","}{end}' 2>/dev/null \
    | sed 's/,$//' || true)"
  if [ -n "${live}" ] && [ "${live}" != "${want}" ]; then
    drift=1
    warn "image drift on ${kind} ${ns}/${name}:"
    say "      release: ${want}"
    say "      cluster: ${live}"
  fi
done < <(awk '
  function flush() {
    if (kind ~ /^(Deployment|DaemonSet)$/ && imgs != "") {
      gsub(/"/, "", name); gsub(/"/, "", ns)
      print kind "|" name "|" ns "|" imgs
    }
    kind=""; name=""; ns=""; imgs=""; incont=0
  }
  /^---/           { flush() }
  /^kind: /        { kind=$2 }
  /^  name: /      { if (name=="") name=$2 }
  /^  namespace: / { if (ns=="") ns=$2 }
  /^      containers:/ { incont=1 }
  /^      [a-zA-Z]/ && !/^      containers:/ { incont=0 }
  incont && /^ +image: / {
    img=$2; gsub(/"/,"",img)
    imgs = (imgs=="" ? img : imgs "," img)
  }
  END { flush() }
' "${manifest}")

if [ "${drift}" = 1 ]; then
  say ""
  warn "Images were changed outside of Helm. This works, but the next"
  warn "'helm upgrade' will silently roll them back. Two ways to fix:"
  say "      1. Re-apply your image pins through Helm so the release matches:"
  say "         helm upgrade ${RELEASE} helm/teable-infra -n ${NAMESPACE} \\"
  say "           --reuse-values -f helm/examples/images.values.yaml"
  say "         (edit that file to the tags you want first; on Helm 4 add"
  say "         --server-side=true --force-conflicts so Helm takes the image"
  say "         field back from kubectl)"
  say "      2. Or keep managing images by hand and diff manifests/default.yaml"
  say "         before every release to see what else changed."
fi

# --- 3. Platform release compatibility -----------------------------------------
# versions.yaml (repo root) pins the component set of a platform release. Compare
# what the cluster actually runs against it: three states -- compatible / upgrade
# the Teable app / unknown combination.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSIONS_FILE="${SCRIPT_DIR}/../versions.yaml"
combo=0
if [ ! -f "${VERSIONS_FILE}" ]; then
  warn "versions.yaml not found at ${VERSIONS_FILE}; skipping the platform release check"
else
  # name|tag|digest per component (name = last path segment; prefix-agnostic so
  # registry mirrors compare equal), plus the release metadata.
  EXPECTED="$(awk '
    /^components:/ { inc=1; next }
    inc && /^[a-zA-Z]/ { inc=0 }
    inc && /^  [a-zA-Z0-9-]+:$/ { comp=$1; sub(":", "", comp); next }
    inc && comp != "" && /^    image: / {
      img=$2; n=split(img, seg, "/"); name_tag=seg[n]
      if (split(name_tag, nt, ":") == 2) { cname=nt[1]; ctag=nt[2] } else { cname=""; ctag="" }
      next
    }
    inc && comp != "" && cname != "" && /^    digest: / { print cname "|" ctag "|" $2 "|" img; comp="" }
    /^platformRelease: / { print "platformRelease||" $2 }
    /^  minRelease: / { print "minRelease||" $2 }
  ' "${VERSIONS_FILE}")"
  PLATFORM="$(printf '%s\n' "${EXPECTED}" | awk -F'|' '$1=="platformRelease"{print $3}')"
  MIN_RELEASE="$(printf '%s\n' "${EXPECTED}" | awk -F'|' '$1=="minRelease"{print $3}')"
  expected_for() { printf '%s\n' "${EXPECTED}" | awk -F'|' -v n="$1" '$1==n{print $2"|"$3"|"$4; exit}'; }

  # Live set as "namespace|image|source" rows: every workload the release
  # installed (cluster truth, so this also covers images swapped outside of
  # Helm), config-driven images that appear in no workload spec (app-runtime
  # base env, snapshot committer argument, engine-injected execd/egress from
  # the live server ConfigMap), and hook workload images (helm get hooks).
  live_all="$(mktemp)"
  {
    while IFS='|' read -r kind name ns; do
      [ -n "${kind}" ] || continue
      ns="${ns:-${NAMESPACE}}"
      res="deploy"; [ "${kind}" = "DaemonSet" ] && res="ds"
      kubectl get "${res}" "${name}" -n "${ns}" \
        -o jsonpath='{range .spec.template.spec.containers[*]}{.image}{"\n"}{end}' 2>/dev/null \
        | awk -v ns="${ns}" 'NF { print ns "|" $0 "|wl" }' || true
      if [ "${res}" = "deploy" ]; then
        # Config-driven images that never appear as workload containers: the
        # app-runtime base (env on infra-service; live value, kubectl set env
        # counts) and the snapshot committer (controller argument).
        arimg="$(kubectl get deploy "${name}" -n "${ns}" \
          -o jsonpath='{.spec.template.spec.containers[*].env[?(@.name=="APP_RUNTIME_DEFAULT_IMAGE")].value}' 2>/dev/null || true)"
        [ -n "${arimg}" ] && printf '%s|%s|cfg\n' "${ns}" "${arimg}"
        cargs="$(kubectl get deploy "${name}" -n "${ns}" \
          -o jsonpath='{.spec.template.spec.containers[*].args[*]}' 2>/dev/null || true)"
        ci="$(printf '%s\n' "${cargs}" | tr ' ' '\n' | sed -n 's/^--image-committer-image=//p' | head -1)"
        [ -n "${ci}" ] && printf '%s|%s|cfg\n' "${ns}" "${ci}"
      fi
    done < <(awk '
      /^---/ { kind=""; name=""; ns="" }
      /^kind: /       { kind=$2 }
      /^  name: /     { if (name=="") name=$2 }
      /^  namespace: /{ if (ns=="") ns=$2 }
      /^spec:/ && (kind=="Deployment" || kind=="DaemonSet") && name!="" {
        gsub(/"/,"",name); gsub(/"/,"",ns); print kind "|" name "|" ns; kind=""
      }
    ' "${manifest}")
    # Hook workloads (minio bucket init, key generation) never show in
    # `helm get manifest`; their images are still part of the release.
    helm get hooks "${RELEASE}" -n "${NAMESPACE}" 2>/dev/null | awk -v dns="${NAMESPACE}" '
      /^---/ { ns="" }
      /^  namespace: / { if (ns=="") { ns=$2; gsub(/"/,"",ns) } }
      /^ +image: / { img=$2; gsub(/"/,"",img); print (ns=="" ? dns : ns) "|" img "|cfg" }
    ' || true
    while IFS='|' read -r cmname cmns; do
      [ -n "${cmname}" ] || continue
      kubectl get cm "${cmname}" -n "${cmns:-${NAMESPACE}}" -o jsonpath='{.data.config\.toml}' 2>/dev/null \
        | sed -n 's/^execd_image = "\([^"]*\)".*/\1/p; s/^image = "\([^"]*\)".*/\1/p' \
        | awk -v ns="${cmns:-${NAMESPACE}}" 'NF { print ns "|" $0 "|cfg" }' || true
    done < <(awk '
      /^---/ { kind=""; name=""; ns=""; hit=0 }
      /^kind: /        { kind=$2 }
      /^  name: /      { if (name=="") name=$2 }
      /^  namespace: / { if (ns=="") ns=$2 }
      /execd_image/    { if (kind=="ConfigMap" && !hit && name!="") { gsub(/"/,"",name); gsub(/"/,"",ns); print name "|" ns; hit=1 } }
    ' "${manifest}")
  } | sort -u > "${live_all}"

  checked=0
  while IFS='|' read -r ns img src; do
    [ -n "${img}" ] || continue
    ref="${img}"; digest_pin=""
    case "${ref}" in *@sha256:*) digest_pin="sha256:${ref#*@sha256:}"; ref="${ref%%@*}" ;; esac
    name_tag="${ref##*/}"
    name="${name_tag%%:*}"
    tag=""; case "${name_tag}" in *:*) tag="${name_tag#*:}" ;; esac
    exp="$(expected_for "${name}")"
    [ -n "${exp}" ] || continue        # not a platform component
    exp_tag="${exp%%|*}"; exp_rest="${exp#*|}"; exp_digest="${exp_rest%%|*}"; exp_img="${exp_rest#*|}"
    checked=$((checked+1))
    if [ -n "${digest_pin}" ]; then
      # Digest pins are conclusive against the canonical registry only
      # (mirrors serve the same content under different digests).
      ref_prefix=""; case "${ref}" in */*) ref_prefix="${ref%/*}" ;; esac
      exp_prefix=""; case "${exp_img}" in */*) exp_prefix="${exp_img%/*}" ;; esac
      if [ "${digest_pin}" = "${exp_digest}" ]; then
        ok "${name} pinned by digest, matches ${PLATFORM:-versions.yaml}"
      elif [ "${ref_prefix}" = "${exp_prefix}" ]; then
        combo=1
        warn "${name}: digest-pinned to a different build than ${PLATFORM:-the release} pins (${exp_tag})"
      else
        warn "${name} digest-pinned from a mirror; digests differ per registry -- re-resolve against the canonical registry to compare"
      fi
    elif [ "${tag}" = "${exp_tag}" ]; then
      ok "${name}:${tag} matches ${PLATFORM:-versions.yaml}"
    elif [ "${tag}" = "latest" ]; then
      # :latest is a channel, not a version -- conclusive only if the digest of
      # what actually runs equals the canonical one (pod imageID; mirrors have
      # different digests). Config-sourced refs have no pods to resolve through.
      digest_hit=0
      if [ "${src}" = "wl" ]; then
        podids="$(kubectl get pods -n "${ns}" \
          -o jsonpath='{range .items[*].status.containerStatuses[*]}{.image}{"|"}{.imageID}{"\n"}{end}' 2>/dev/null \
          | awk -F'|' -v i="${img}" '$1==i{print $2}')"
        if printf '%s\n' "${podids}" | grep -q "${exp_digest}"; then digest_hit=1; fi
      fi
      if [ "${digest_hit}" = 1 ]; then
        ok "${name}:latest currently IS ${exp_tag} (digest match)"
      else
        # Indeterminate, not a combination problem: latest is the stable channel.
        warn "cannot map ${name}:latest to a release pin (mirror pull or newer build); pin the tag in your values to compare exactly"
      fi
    elif [ "${name}" = "teable" ] && [ "${tag#release.}" != "${tag}" ]; then
      # The app has its own release line; the manifest declares a window, not one pin.
      if [ -n "${MIN_RELEASE}" ] && [[ "${tag}" < "${MIN_RELEASE}" ]]; then
        bad "Teable app ${tag} is older than this platform release supports (min: ${MIN_RELEASE}); upgrade the app image first"
      else
        ok "Teable app ${tag} is within the compatibility window (verified: ${exp_tag})"
      fi
    else
      combo=1
      warn "${name}: running ${tag}, ${PLATFORM:-the release} pins ${exp_tag}"
    fi
  done < <(awk -F'|' '!seen[$1 "|" $2]++' "${live_all}")
  rm -f "${live_all}"
  if [ "${checked}" = 0 ]; then
    warn "no running component matched versions.yaml; skipping the platform release verdict"
  elif [ "${combo}" = 1 ]; then
    warn "unknown combination -- this exact set was never verified together."
    say "      Align every component with one platform release (see VERSIONS.md);"
    say "      apply pins via helm/examples/images.values.yaml."
  fi
  # Deployed apps ride the app-runtime base on redeploy: older bases keep
  # running by design, so report them without flagging the combination.
  exp_ar="$(expected_for "teable-app-runtime")"
  if [ -n "${exp_ar}" ]; then
    exp_ar_tag="${exp_ar%%|*}"
    app_ns="$(kubectl get deploy -n "${NAMESPACE}" \
      -o jsonpath='{range .items[*]}{range .spec.template.spec.containers[*]}{range .env[?(@.name=="APP_RUNTIME_NAMESPACE")]}{.value}{"\n"}{end}{end}{end}' 2>/dev/null \
      | awk 'NF {print; exit}')"
    app_ns="${app_ns:-app-deploy}"
    ar_stale=0; ar_total=0
    while IFS= read -r img; do
      [ -n "${img}" ] || continue
      case "${img}" in */teable-app-runtime:*|teable-app-runtime:*) ;; *) continue ;; esac
      ar_total=$((ar_total+1))
      case "${img}" in *:"${exp_ar_tag}") ;; *) ar_stale=$((ar_stale+1)) ;; esac
    done < <(kubectl get deploy -n "${app_ns}" -l app.kubernetes.io/name=teable-app-runtime \
      -o jsonpath='{range .items[*].spec.template.spec.containers[*]}{.image}{"\n"}{end}' 2>/dev/null | sort -u || true)
    if [ "${ar_stale}" -gt 0 ]; then
      warn "${ar_stale} of ${ar_total} deployed app base image(s) predate this release -- apps pick the new base on redeploy (by design, not an unknown combination)"
    elif [ "${ar_total}" -gt 0 ]; then
      ok "all deployed apps run the release app-runtime base (${ar_total} image variant(s))"
    fi
  fi
fi

# --- 4. Certificates (only when cert-manager is installed) --------------------
if kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  notready="$(kubectl get certificate -A \
    -o jsonpath='{range .items[?(@.status.conditions[0].status!="True")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true)"
  if [ -n "${notready}" ]; then
    while IFS= read -r c; do [ -n "${c}" ] && bad "certificate not ready: ${c}"; done <<< "${notready}"
  else
    ok "all certificates ready"
  fi
fi

# --- 5. AI Agent skills storage (checked only when s3Compat is on) -------------
# Skills are files: the app writes them through the /s3 object API on the
# fileBrowser volume, and sandboxes read them back from the teable-agent-juicefs
# claim in the sandbox namespace. Both claims must resolve to ONE shared
# filesystem (README.md here, "AI Agent skills") -- and getting that wrong is
# silent at runtime: the skill saves, the sandbox directory stays empty.

# The literal value the rendered manifest sets for an infra-service env var.
manifest_env() {
  awk -v n="$1" '$0 ~ ("- name: " n "$") { getline; sub(/^ *value: /, ""); gsub(/"/, ""); print; exit }' "${manifest}"
}

if [ "$(manifest_env S3_COMPAT_ENABLED)" != "true" ]; then
  say ""
  say "[..] AI Agent skills: s3Compat is off (the chart default) -- skipping the"
  say "     skills storage checks. Enabling it requires the shared-volume setup in"
  say "     helm/README.md, \"AI Agent skills\"; the switch alone is not enough."
else
  say ""
  # s3Compat serves off the fileBrowser volume: with fileBrowser off every skill save 404s.
  if [ "$(manifest_env FILE_BROWSER_ENABLED)" != "true" ]; then
    bad "skills: s3Compat is on but fileBrowser is off (infraService.fileBrowser.enabled) -- every skill save 404s"
  fi

  infra_ref="$(kubectl get deploy -A \
    -l app.kubernetes.io/name=infra-service,app.kubernetes.io/instance="${RELEASE}" \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1 || true)"
  INFRA_NS="${infra_ref%%|*}"; INFRA_DEPLOY="${infra_ref#*|}"
  if [ -z "${INFRA_DEPLOY}" ]; then
    bad "skills: infra-service deployment not found (label app.kubernetes.io/instance=${RELEASE})"
  else
    # Sandbox dataplane namespace: the opensandbox-server config.toml in the manifest.
    sbx_ns="$(awk '/\[kubernetes\]/{k=1; next} k && /^ *\[/{k=0} k && /namespace = /{sub(/.*= *"/, ""); sub(/".*/, ""); print; exit}' "${manifest}")"
    sbx_ns="${sbx_ns:-teable-sandbox}"
    SBX_CLAIM="teable-agent-juicefs"   # fixed by the app; see README "One share, two PV/PVC pairs"

    # The bucket's directory prefix on the volume (S3_COMPAT_BUCKETS, default /teable).
    bucket_prefix="$(manifest_env S3_COMPAT_BUCKETS | sed -n 's/.*teable-agent[^:]*:[^A-Za-z0-9._/-]*\/*\([A-Za-z0-9._-]*\).*/\1/p')"
    bucket_prefix="${bucket_prefix:-teable}"

    pvc_state() { kubectl get pvc "$2" -n "$1" -o jsonpath='{.status.phase}{"|"}{.spec.volumeName}' 2>/dev/null || true; }

    cp_claim="$(kubectl get deploy "${INFRA_DEPLOY}" -n "${INFRA_NS}" \
      -o jsonpath='{.spec.template.spec.volumes[?(@.name=="juicefs")].persistentVolumeClaim.claimName}' 2>/dev/null || true)"
    cp_pv=""
    if [ -z "${cp_claim}" ]; then
      bad "skills: infra-service has no fileBrowser volume (volume 'juicefs' missing on the deployment)"
    else
      st="$(pvc_state "${INFRA_NS}" "${cp_claim}")"
      if [ -z "${st}" ]; then
        bad "skills: control-plane claim ${INFRA_NS}/${cp_claim} not found"
      elif [ "${st%%|*}" != "Bound" ]; then
        bad "skills: control-plane claim ${cp_claim} is ${st%%|*}, not Bound"
      else
        cp_pv="${st#*|}"
        ok "skills: control-plane claim ${cp_claim} bound (${cp_pv})"
      fi
    fi
    sb_pv=""
    st="$(pvc_state "${sbx_ns}" "${SBX_CLAIM}")"
    if [ -z "${st}" ]; then
      bad "skills: sandbox claim ${sbx_ns}/${SBX_CLAIM} not found -- pre-create it; the engine would otherwise provision its own disk under that name and skills would silently never reach the agent"
    elif [ "${st%%|*}" != "Bound" ]; then
      bad "skills: sandbox claim ${sbx_ns}/${SBX_CLAIM} is ${st%%|*}, not Bound"
    else
      sb_pv="${st#*|}"
      ok "skills: sandbox claim ${sbx_ns}/${SBX_CLAIM} bound (${sb_pv})"
    fi

    # Endpoint probe: PUT/GET/DELETE a nonce through /s3 from inside the pod
    # (localhost, same Bearer key the app uses). Catches env drift, a read-only
    # fileBrowser (write 500s) and volume permission problems.
    api_secret="$(manifest_env OPENSANDBOX_API_KEY_SECRET_NAME)"; api_secret="${api_secret:-opensandbox-api-key}"
    osb_ns="$(manifest_env OPENSANDBOX_NAMESPACE)"; osb_ns="${osb_ns:-${NAMESPACE}}"
    api_key="$(kubectl get secret "${api_secret}" -n "${osb_ns}" -o jsonpath='{.data.api-key}' 2>/dev/null | base64 --decode 2>/dev/null || true)"
    s3req() { # s3req METHOD KEY [BODY] -> "<status>|<body>" ("ERR|" on transport failure)
      kubectl exec -n "${INFRA_NS}" "deploy/${INFRA_DEPLOY}" -c monitor -- node -e '
        const [m, u, k, b] = process.argv.slice(1);
        fetch(u, { method: m, headers: { authorization: "Bearer " + k }, body: b || undefined })
          .then((r) => r.text().then((t) => console.log(r.status + "|" + t)))
          .catch(() => console.log("ERR|"));
      ' "$1" "http://localhost:8080/s3/teable-agent/$2" "${api_key}" "${3:-}" 2>/dev/null | tail -1 || true
    }
    s3_write_ok=0
    if [ -z "${api_key}" ]; then
      warn "skills: cannot read the Infra API key (secret ${osb_ns}/${api_secret}); skipping the /s3 endpoint probe"
    else
      nonce="doctor-$$-${RANDOM}"
      res="$(s3req PUT ".doctor/${nonce}" "${nonce}")"
      case "${res%%|*}" in
        200)
          s3_write_ok=1
          res="$(s3req GET ".doctor/${nonce}")"
          if [ "${res}" = "200|${nonce}" ]; then
            ok "skills: object API /s3/teable-agent write/read"
          else
            bad "skills: object API wrote but read back '${res}' (expected 200|${nonce})"
          fi
          res="$(s3req DELETE ".doctor/${nonce}")"
          [ "${res%%|*}" = "204" ] || warn "skills: probe cleanup DELETE returned ${res%%|*}"
          ;;
        401) bad "skills: /s3 PUT -> 401 -- the key in ${osb_ns}/${api_secret} is not what infra-service verifies against" ;;
        404) bad "skills: /s3 PUT -> 404 -- bucket teable-agent not served (s3Compat/fileBrowser env drift; was the pod restarted after the values change?)" ;;
        500) bad "skills: /s3 PUT -> 500 -- volume not writable (infraService.fileBrowser.readOnly, or volume permissions)" ;;
        *)   bad "skills: /s3 PUT -> ${res%%|*} (kubectl exec into ${INFRA_DEPLOY} failed, or infra-service is not listening on 8080)" ;;
      esac
    fi

    # Same-filesystem verdict. Conclusive when a sandbox pod is running: write a
    # nonce through /s3 into a directory that pod mounts (subPath of the sandbox
    # claim) and read it back through the pod. Without a pod, fall back to
    # comparing the two PVs.
    verified=""
    if [ "${s3_write_ok}" = 1 ]; then
      while IFS= read -r pod; do
        [ -n "${pod}" ] || continue
        # First container mount backed by the sandbox claim whose subPath sits
        # under the bucket prefix; prefer non-skills dirs so a probe file never
        # sits in a skills directory even transiently.
        sel="$(kubectl get pod "${pod}" -n "${sbx_ns}" -o jsonpath='{range .spec.volumes[?(@.persistentVolumeClaim.claimName=="teable-agent-juicefs")]}{.name}{"\n"}{end}{range .spec.containers[*]}{.name}{"\t"}{range .volumeMounts[*]}{.name}{"|"}{.mountPath}{"|"}{.subPath}{";"}{end}{"\n"}{end}' 2>/dev/null \
          | awk -F'\t' -v pfx="${bucket_prefix}/" '
              NF==1 && $1 != "" && v == "" { v=$1; next }
              NF==2 && v != "" {
                n=split($2, a, ";")
                for (i=1; i<=n; i++) {
                  if (split(a[i], f, "|") < 3 || f[1] != v || f[3] == "" || index(f[3], pfx) != 1) continue
                  line=$1 "|" f[2] "|" f[3]
                  if (f[3] ~ /\/skills($|\/)/) { if (alt == "") alt=line } else { best=line; exit }
                }
              }
              END { if (best != "") print best; else if (alt != "") print alt }' || true)"
        [ -n "${sel}" ] || continue
        ctr="${sel%%|*}"; rest="${sel#*|}"; mnt="${rest%%|*}"; subp="${rest#*|}"
        fs_key="${subp#"${bucket_prefix}"/}"
        nonce="doctor-fs-$$-${RANDOM}"
        res="$(s3req PUT "${fs_key}/.${nonce}" "${nonce}")"
        [ "${res%%|*}" = "200" ] || continue   # cannot address this pod's dir through the bucket; try the next pod
        seen=""
        for _try in 1 2 3; do
          seen="$(kubectl exec -n "${sbx_ns}" "${pod}" -c "${ctr}" -- cat "${mnt}/.${nonce}" 2>/dev/null || true)"
          [ "${seen}" = "${nonce}" ] && break
          sleep 2
        done
        s3req DELETE "${fs_key}/.${nonce}" >/dev/null 2>&1 || true
        if [ "${seen}" = "${nonce}" ]; then
          ok "skills: control-plane and sandbox volumes are one filesystem (verified through pod ${pod})"
          verified=same
        else
          bad "skills: a file written through /s3 is NOT visible in sandbox pod ${pod} (${mnt}) -- the two claims do not resolve to one shared filesystem; skills save but never reach the agent (README.md, \"AI Agent skills\")"
          verified=diff
        fi
        break
      done < <(kubectl get pods -n "${sbx_ns}" --field-selector=status.phase=Running -o name 2>/dev/null | sed 's|pod/||' | head -10 || true)
    fi
    if [ -z "${verified}" ] && [ -n "${cp_pv}" ] && [ -n "${sb_pv}" ]; then
      pv_prov() { kubectl get pv "$1" -o jsonpath='{.metadata.annotations.pv\.kubernetes\.io/provisioned-by}' 2>/dev/null || true; }
      pv_src()  { kubectl get pv "$1" -o jsonpath='{.spec.nfs.server}{"|"}{.spec.nfs.path}{"|"}{.spec.csi.driver}{"|"}{.spec.csi.volumeHandle}' 2>/dev/null || true; }
      cp_prov="$(pv_prov "${cp_pv}")"; sb_prov="$(pv_prov "${sb_pv}")"
      if [ -n "${cp_prov}" ] || [ -n "${sb_prov}" ]; then
        bad "skills: dynamically provisioned volume behind ${cp_prov:+${cp_claim} }${sb_prov:+${SBX_CLAIM} }-- dynamic provisioning gives each claim its own volume or subdirectory, so the two sides can never share files; bind both claims to static PVs on one share (README.md, \"One share, two PV/PVC pairs\")"
      else
        IFS='|' read -r cp_srv cp_path cp_drv cp_hdl <<< "$(pv_src "${cp_pv}")"
        IFS='|' read -r sb_srv sb_path sb_drv sb_hdl <<< "$(pv_src "${sb_pv}")"
        if [ -n "${cp_srv}" ] && [ "${cp_srv}|${cp_path}" = "${sb_srv}|${sb_path}" ]; then
          ok "skills: both claims bind static NFS PVs on the same export (${cp_srv}:${cp_path})"
        elif [ -n "${cp_drv}" ] && [ "${cp_drv}|${cp_hdl}" = "${sb_drv}|${sb_hdl}" ]; then
          ok "skills: both claims bind static PVs on the same CSI volume (${cp_drv})"
        else
          warn "skills: cannot statically prove both claims resolve to one share (PVs ${cp_pv} / ${sb_pv});"
          say "      start any AI session (so a sandbox pod is running) and re-run doctor for a"
          say "      conclusive check, or follow the verify steps in README.md, \"AI Agent skills\""
        fi
      fi
    fi
  fi
fi

say ""
if [ "${fail}" = 1 ]; then
  say "[x] doctor found problems -- see the [x] lines above."
  exit 1
fi
if [ "${drift}" = 1 ] || [ "${combo}" = 1 ]; then
  [ "${drift}" = 1 ] && say "[!] stack healthy, with image drift (see above)."
  [ "${combo}" = 1 ] && say "[!] stack healthy, but running a component combination no platform release verified."
else
  say "[ok] all checks passed."
fi
