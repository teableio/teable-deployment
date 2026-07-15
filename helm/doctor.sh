#!/usr/bin/env bash
# Post-install check for a teable-infra Helm install.
#
#   ./doctor.sh [RELEASE] [NAMESPACE]     defaults: teable opensandbox-system
#
# Checks that the stack is healthy and that the images running in the cluster
# still match what the Helm release installed (drift happens when images are
# swapped by hand with kubectl set image).
set -euo pipefail

RELEASE="${1:-teable}"
NAMESPACE="${2:-opensandbox-system}"
fail=0
drift=0

say() { printf '%s\n' "$*"; }
ok() { say "[ok] $*"; }
warn() { say "[!] $*"; }
bad() { say "[x] $*"; fail=1; }

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
