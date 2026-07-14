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

# --- 3. Certificates (only when cert-manager is installed) --------------------
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
if [ "${drift}" = 1 ]; then
  say "[!] stack healthy, with image drift (see above)."
else
  say "[ok] all checks passed."
fi
