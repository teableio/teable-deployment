#!/usr/bin/env bash
# Teable all-in-one self-check (doctor): post-deploy acceptance + first-layer fault triage.
#   ./doctor.sh                Full check (includes sandbox create/destroy; first image pull may be slow)
#   ./doctor.sh --no-sandbox   Skip sandbox creation (fast mode)
#   ./doctor.sh --from vYYYY.M.N   Additionally list the migrations still pending
#                                  between platform release vYYYY.M.N and this
#                                  checkout's release
# Each check maps to a real failure mode; every FAIL hint names the first layer to inspect.
# Containers being healthy alone does NOT count as passing -- routing, contract env, the three storage planes, and the sandbox chain must all be genuinely verified.
set -uo pipefail
cd "$(dirname "$0")"
# Assets (compose files, .env) live alongside this script; the cd-guard below also supports running it from a parent directory.
[ -f .env ] || [ -f compose.yaml ] || { [ -d ../docker/all-in-one ] && cd ../docker/all-in-one; }

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

NO_SANDBOX=0
FROM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-sandbox) NO_SANDBOX=1; shift ;;
    --from)   [ -n "${2:-}" ] || { printf '[FAIL] --from needs a platform release (e.g. --from v2026.7.0)\n'; exit 2; }
              FROM="$2"; shift 2 ;;
    --from=*) FROM="${1#--from=}"; shift ;;
    *)        printf 'Unknown argument: %s (usage: ./doctor.sh [--no-sandbox] [--from vYYYY.M.N])\n' "$1"; exit 2 ;;
  esac
done

if [ -n "$FROM" ]; then
  calver_valid "$FROM" || { printf '[FAIL] --from expects a platform release like v2026.7.0, got: %s\n' "$FROM"; exit 2; }
  VERSIONS_CAND="../../versions.yaml"
  [ -f "$VERSIONS_CAND" ] || { [ -f ../delivery/public/versions.yaml ] && VERSIONS_CAND="../delivery/public/versions.yaml"; }
  report_pending_migrations "$VERSIONS_CAND" "$FROM"
  printf '\n'
fi

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS+1)); printf '  [ok]   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  [FAIL] %s\n         ↳ First place to look: %s\n' "$1" "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  [skip] %s (%s)\n' "$1" "$2"; }
sec()  { printf '\n== %s ==\n' "$1"; }

# ---------- Environment ----------
sec "Environment"
DOCKER=docker
$DOCKER ps >/dev/null 2>&1 || { command -v sudo >/dev/null 2>&1 && sudo docker ps >/dev/null 2>&1 && DOCKER="sudo docker"; }
if $DOCKER ps >/dev/null 2>&1; then ok "docker available (${DOCKER})"; else
  printf '  [FAIL] docker unavailable\n         ↳ First place to look: install docker / current user permissions (or use sudo)\n'; exit 1; fi
if $DOCKER compose version >/dev/null 2>&1; then ok "docker compose available"; else bad "docker compose unavailable" "install the compose plugin"; fi
if [ -f .env ]; then ok ".env exists"; else
  printf '  [FAIL] .env missing\n         ↳ First place to look: run ./apply.sh local|server [--with-app] first\n'; exit 1; fi
set -a; . ./.env; set +a

APP_MODE=0; case "${COMPOSE_FILE:-}" in *compose.app.yaml*) APP_MODE=1 ;; esac
MODE=local;  case "${COMPOSE_FILE:-}" in *compose.server.yaml*) MODE=server ;; esac
echo "  Mode: ${MODE}$( [ "$APP_MODE" = 1 ] && echo ' + app(all-in-one)' )"

# First start pulls images and runs healthchecks (the app allows up to 120s to boot);
# checking while containers are still starting would misreport a healthy deployment.
waited=0
while :; do
  starting="$($DOCKER compose ps --format '{{.Name}}|{{.Health}}' 2>/dev/null | awk -F'|' '$2=="starting"{print $1}' | paste -sd, -)"
  [ -z "$starting" ] && break
  if [ "$waited" -ge 300 ]; then
    printf '  [..]   still starting after %ss: %s (checking anyway)\n' "$waited" "$starting"
    break
  fi
  [ "$waited" = 0 ] && printf '  [..]   waiting for services to finish starting...\n'
  sleep 5; waited=$((waited+5))
done

# Entry addresses: local goes through localhost + Host header; server uses the real domains
if [ "$MODE" = "server" ]; then
  TEABLE_URL="https://${TEABLE_HOST:-}"
  INFRA_URL="https://${INFRA_HOST:-}"
  S3_HEALTH_URL="https://${INFRA_HOST:-}/minio/health/live"
  req() { curl -s -o /dev/null -w '%{http_code}' -m 20 "$1"; }
else
  TEABLE_URL="http://localhost"
  INFRA_URL="http://localhost"
  S3_HEALTH_URL="http://localhost:9000/minio/health/live"
  req() { # req <url> [host]
    if [ -n "${2:-}" ]; then curl -s -o /dev/null -w '%{http_code}' -m 20 -H "Host: $2" "$1"
    else curl -s -o /dev/null -w '%{http_code}' -m 20 "$1"; fi
  }
fi
INFRA_HOSTHDR="$( [ "$MODE" = server ] && echo "" || echo "infra.localhost" )"

# ---------- Required env ----------
sec "Required env"
need() { local v; eval "v=\${$1:-}"; if [ -n "$v" ]; then ok "$1 is set"; else bad "$1 is empty" "$2"; fi; }
need OPENSANDBOX_API_KEY "run ./apply.sh to auto-generate"
need S3_ACCESS_KEY "run ./apply.sh to auto-generate"
need S3_SECRET_KEY "run ./apply.sh to auto-generate"
if [ "$APP_MODE" = 1 ]; then
  for v in TEABLE_IMAGE PUBLIC_ORIGIN TEABLE_DB_PASSWORD TEABLE_REDIS_PASSWORD \
           SANDBOX_JWT_SECRET BACKEND_STORAGE_ENCRYPTION_KEY BACKEND_STORAGE_ENCRYPTION_IV \
           TEABLE_MINIO_ENDPOINT_HOST; do
    need "$v" "run ./apply.sh ${MODE} --with-app (TEABLE_IMAGE auto-defaults to ghcr latest; pin with ./pin-image.sh for production)"
  done
  if [ "$MODE" = "local" ]; then
    need SANDBOX_PREVIEW_HOST "run ./apply.sh local --with-app (server injects sandbox.<BASE_DOMAIN> via compose, no .env entry needed)"
  fi
  case "${TEABLE_IMAGE:-}" in
    *:latest) ok "TEABLE_IMAGE=latest (fine for Docker deploys; for production pin it with ./pin-image.sh)" ;;
    ?*)       ok "TEABLE_IMAGE is pinned to a version" ;;
  esac
fi

# ---------- Container health ----------
sec "Container health"
health() { $DOCKER inspect "$1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null; }
CONTAINERS="opensandbox-server infra-service git-registry minio caddy"
[ "$APP_MODE" = 1 ] && CONTAINERS="$CONTAINERS teable teable-db teable-redis"
for c in $CONTAINERS; do
  st="$(health "$c")"
  case "$st" in
    healthy|running) ok "$c: $st" ;;
    *) bad "$c: ${st:-missing}" "docker compose logs $c" ;;
  esac
done

# ---------- Routing ----------
sec "Routing (entry -> services)"
code=$(req "${INFRA_URL}/api/health" "$INFRA_HOSTHDR")
[ "$code" = 200 ] && ok "Infra /api/health -> 200" || bad "Infra /api/health -> $code" "infra-service container or entry routing"
code=$(curl -s -o /dev/null -w '%{http_code}' -m 20 ${INFRA_HOSTHDR:+-H "Host: $INFRA_HOSTHDR"} -H "OPEN-SANDBOX-API-KEY: ${OPENSANDBOX_API_KEY:-}" "${INFRA_URL}/v1/sandboxes")
[ "$code" = 200 ] && ok "/v1 split routing (with key) -> 200" || bad "/v1 split routing -> $code" "entry is not forwarding /v1 to opensandbox-server, or the key differs"
code=$(req "$S3_HEALTH_URL")
[ "$code" = 200 ] && ok "MinIO health -> 200" || bad "MinIO health -> $code" "minio container or s3 entry"
# minio-js getBucketRegion sends GET /<bucket>?location -- bare bucket path, NO trailing slash. The entry
# must still hand it to MinIO (expect S3 XML; HTML means it fell through to the console and every storage
# call fails with an empty S3Error). Server mode only: local clients reach MinIO directly on :9000.
if [ "$MODE" = "server" ]; then
  body="$(curl -s -m 20 "${INFRA_URL}/${S3_BUCKET:-teable-app-artifacts}?location" | head -c 100)"
  case "$body" in
    '<?xml'*) ok "Bare bucket path /${S3_BUCKET:-teable-app-artifacts}?location -> S3 XML (handled by MinIO)" ;;
    *) bad "Bare bucket path /${S3_BUCKET:-teable-app-artifacts}?location -> not S3 XML" "caddy @minio matcher must list the bare /<bucket> path next to /<bucket>/*" ;;
  esac
fi
if [ "$APP_MODE" = 1 ]; then
  code=$(req "${TEABLE_URL}/health")
  [ "$code" = 200 ] && ok "Teable /health (fallback route) -> 200" || bad "Teable /health -> $code" "teable container or caddy fallback (is the app Caddyfile mounted?)"
  # The public bucket path must land on MinIO: an anonymous list being denied is 403 (a 404 means it landed on Teable, i.e. bucket path forwarding is missing)
  code=$(req "${TEABLE_URL}/${TEABLE_PUBLIC_BUCKET:-teable-public}/" )
  case "$code" in
    200|403) ok "Public bucket path /${TEABLE_PUBLIC_BUCKET:-teable-public}/ -> $code (handled by MinIO)" ;;
    *) bad "Public bucket path -> $code" "caddy public-bucket forwarding missing (attachments/avatars will 404)" ;;
  esac
  # Same probe without the trailing slash: /x/* does not cover /x, so the bare path needs its own matcher entry.
  body="$(curl -s -m 20 "${TEABLE_URL}/${TEABLE_PUBLIC_BUCKET:-teable-public}?location" | head -c 100)"
  case "$body" in
    '<?xml'*) ok "Bare public bucket path /${TEABLE_PUBLIC_BUCKET:-teable-public}?location -> S3 XML (handled by MinIO)" ;;
    *) bad "Bare public bucket path /${TEABLE_PUBLIC_BUCKET:-teable-public}?location -> not S3 XML" "caddy main-site matcher must list the bare /<bucket> path next to /<bucket>/*" ;;
  esac
fi

# ---------- app -> Infra contract ----------
if [ "$APP_MODE" = 1 ]; then
  sec "app -> Infra contract (live, in-container)"
  vals="$($DOCKER exec teable sh -c 'echo "${SANDBOX_PROVIDER:-}|${APP_DEPLOY_PROVIDER:-}|${SANDBOX_OPENSANDBOX_RUNTIME:-}|${SANDBOX_URL:-}|${TEABLE_INFRA_API_URL:-}"' 2>/dev/null)"
  IFS='|' read -r p_sbx p_dep p_rt p_url p_infra <<EOF
$vals
EOF
  [ "$p_sbx" = "opensandbox" ]    && ok "SANDBOX_PROVIDER=opensandbox" || bad "SANDBOX_PROVIDER=$p_sbx" "compose.app.yaml env"
  [ "$p_dep" = "docker-runtime" ] && ok "APP_DEPLOY_PROVIDER=docker-runtime" || bad "APP_DEPLOY_PROVIDER=$p_dep" "compose.app.yaml env"
  [ "$p_rt" = "docker" ]          && ok "SANDBOX_OPENSANDBOX_RUNTIME=docker" || bad "SANDBOX_OPENSANDBOX_RUNTIME=$p_rt" "without it the provider defaults to kubernetes-style uid pinning and every command inside the sandbox fails with 'operation not permitted'"
  [ -z "$p_url" ]                 && ok "SANDBOX_URL unset (automation executes inside the app)" || bad "SANDBOX_URL=$p_url" "all-in-one must not set this variable"
  case "$p_infra" in
    *infra-service:8080*) bad "TEABLE_INFRA_API_URL points at bare infra-service" "must point at the entry with /v1 split routing (caddy alias), otherwise sandbox creation always fails" ;;
    ?*) ok "TEABLE_INFRA_API_URL=$p_infra" ;;
    *)  bad "TEABLE_INFRA_API_URL is empty" "compose.app.{local,server}.yaml" ;;
  esac
  # Actually connect to the Infra entry once from inside the container (401 = reached the engine, stopped by the auth layer; anything other than 401/200 means the alias or split routing is broken)
  code="$($DOCKER exec teable node -e "fetch(process.env.TEABLE_INFRA_API_URL+'/v1/sandboxes',{signal:AbortSignal.timeout(8000)}).then(r=>console.log(r.status)).catch(()=>console.log('ERR'))" 2>/dev/null | tail -1)"
  case "$code" in
    200|401) ok "Infra entry /v1 reachable from inside container -> $code" ;;
    *) bad "Infra entry from inside container -> $code" "caddy internal alias (infra.localhost / INFRA_HOST) not in effect" ;;
  esac
fi

# ---------- Three storage planes ----------
sec "Three storage planes"
buckets="$($DOCKER run --rm --network "${APP_RUNTIME_DOCKER_NETWORK:-teable-appnet}" --entrypoint sh "${MINIO_MC_IMAGE:-minio/mc:latest}" \
  -c "mc alias set local http://minio:9000 '$S3_ACCESS_KEY' '$S3_SECRET_KEY' >/dev/null 2>&1 && mc ls local/" 2>/dev/null)"
for b in "${S3_BUCKET:-teable-app-artifacts}" $( [ "$APP_MODE" = 1 ] && echo "${TEABLE_PUBLIC_BUCKET:-teable-public} ${TEABLE_PRIVATE_BUCKET:-teable-private}" ); do
  if printf '%s' "$buckets" | grep -q "$b"; then ok "bucket exists: $b"; else bad "bucket missing: $b" "minio-init did not complete (docker compose logs minio-init)"; fi
done
rw="$($DOCKER exec infra-service sh -c 'echo doctor > /mnt/juicefs/.doctor-probe && cat /mnt/juicefs/.doctor-probe && rm -f /mnt/juicefs/.doctor-probe' 2>/dev/null)"
[ "$rw" = "doctor" ] && ok "AI/Sandbox data plane read/write (/mnt/juicefs)" || bad "AI/Sandbox data plane read/write failed" "teable-agent-juicefs volume not mounted (apply.sh pre-creates it)"
# Skills storage plane: the app saves AI Agent skills via PUT /s3/teable-agent/* on the
# Infra entry (same Bearer key as the rest of the Infra API) and sandboxes read them from
# the same teable-agent-juicefs volume. Both mounts come from one docker volume here, so
# what can actually break is env drift (S3_COMPAT_ENABLED) and the entry not routing /s3
# -- probe end to end: PUT via the entry, confirm on the volume, GET, DELETE.
S3_NONCE="doctor-$$-$RANDOM"
S3_PROBE_URL="${INFRA_URL}/s3/teable-agent/.doctor/${S3_NONCE}"
code=$(curl -s -o /dev/null -w '%{http_code}' -m 20 -X PUT ${INFRA_HOSTHDR:+-H "Host: $INFRA_HOSTHDR"} -H "Authorization: Bearer ${OPENSANDBOX_API_KEY:-}" --data-binary "$S3_NONCE" "$S3_PROBE_URL")
case "$code" in
  200)
    landed="$($DOCKER exec infra-service cat "/mnt/juicefs/teable/.doctor/${S3_NONCE}" 2>/dev/null)"
    got="$(curl -s -m 20 ${INFRA_HOSTHDR:+-H "Host: $INFRA_HOSTHDR"} -H "Authorization: Bearer ${OPENSANDBOX_API_KEY:-}" "$S3_PROBE_URL")"
    del=$(curl -s -o /dev/null -w '%{http_code}' -m 20 -X DELETE ${INFRA_HOSTHDR:+-H "Host: $INFRA_HOSTHDR"} -H "Authorization: Bearer ${OPENSANDBOX_API_KEY:-}" "$S3_PROBE_URL")
    if [ "$landed" = "$S3_NONCE" ] && [ "$got" = "$S3_NONCE" ] && [ "$del" = 204 ]; then
      ok "skills object API /s3/teable-agent write -> volume -> read -> delete"
    elif [ "$landed" != "$S3_NONCE" ]; then
      bad "skills object API wrote, but the object is not at /mnt/juicefs/teable on the shared volume" "FILE_BROWSER_ROOT / volume mounts on infra-service (compose.yaml)"
    else
      bad "skills object API: write ok, read/delete broken (read: '$(printf '%s' "$got" | head -c 40)', delete: $del)" "docker compose logs infra-service"
    fi
    ;;
  401) bad "skills object API PUT /s3/teable-agent -> 401" "OPENSANDBOX_API_KEY differs between .env and the running infra-service (docker compose up -d infra-service)" ;;
  404) bad "skills object API PUT /s3/teable-agent -> 404" "S3_COMPAT_ENABLED/FILE_BROWSER_ENABLED were turned off on the running container (compose sets both; recreate infra-service)" ;;
  *)   bad "skills object API PUT /s3/teable-agent -> $code" "entry routing of /s3 to infra-service, or infra-service down (docker compose logs infra-service caddy)" ;;
esac

# ---------- Sandbox chain ----------
sec "Sandbox chain"
if [ "$NO_SANDBOX" = 1 ]; then
  skip "sandbox create/destroy" "--no-sandbox"
elif [ -z "${OPENSANDBOX_SERVER_IMAGE:-}" ]; then
  bad "OPENSANDBOX_SERVER_IMAGE is empty" ".env image section"
else
  # The test sandbox runs the engine's own server image: it is already present (the
  # engine runs from it), so this exercises the create/destroy loop without any image
  # download. The real agent image is preheated by the Teable app itself on startup.
  body="{\"image\":{\"uri\":\"${OPENSANDBOX_SERVER_IMAGE}\"},\"entrypoint\":[\"tail\",\"-f\",\"/dev/null\"],\"resourceLimits\":{\"cpu\":\"1\",\"memory\":\"1Gi\",\"ephemeral-storage\":\"2Gi\"}}"
  resp="$(curl -s -m 300 -X POST ${INFRA_HOSTHDR:+-H "Host: $INFRA_HOSTHDR"} -H "OPEN-SANDBOX-API-KEY: ${OPENSANDBOX_API_KEY:-}" -H "Content-Type: application/json" -d "$body" "${INFRA_URL}/v1/sandboxes")"
  sid="$(printf '%s' "$resp" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)"
  state="$(printf '%s' "$resp" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)"
  if [ -n "$sid" ] && [ "$state" = "Running" ]; then
    ok "sandbox create -> Running ($sid)"
    code=$(curl -s -o /dev/null -w '%{http_code}' -m 60 -X DELETE ${INFRA_HOSTHDR:+-H "Host: $INFRA_HOSTHDR"} -H "OPEN-SANDBOX-API-KEY: ${OPENSANDBOX_API_KEY:-}" "${INFRA_URL}/v1/sandboxes/$sid")
    [ "$code" = 204 ] && ok "sandbox destroy -> 204" || bad "sandbox destroy -> $code" "opensandbox-server logs"
  else
    bad "sandbox create failed: $(printf '%s' "$resp" | head -c 160)" "engine / agent image pull / docker runtime (docker compose logs opensandbox-server)"
  fi
fi

# ---------- Platform release compatibility ----------
# versions.yaml pins the component set of a platform release (generated by the
# release pipeline). Compare what is actually running against it: three states --
# compatible / upgrade the Teable app / unknown combination.
sec "Platform release"
VERSIONS_FILE=""
for cand in ../../versions.yaml ../delivery/public/versions.yaml; do
  [ -f "$cand" ] && VERSIONS_FILE="$cand" && break
done
UNKNOWN_COMBO=0
if [ -z "$VERSIONS_FILE" ]; then
  skip "platform release check" "versions.yaml not found relative to this directory"
else
  # name|tag|digest per component (name = last path segment; prefix-agnostic so
  # registry mirrors compare equal), plus the release metadata.
  EXPECTED="$(awk '
    /^components:/ { inc=1; next }
    inc && /^[a-zA-Z]/ { inc=0 }
    inc && /^  [a-zA-Z0-9-]+:$/ { comp=$1; sub(":", "", comp); img=""; next }
    inc && comp != "" && /^    image: / {
      img=$2; n=split(img, seg, "/"); name_tag=seg[n]
      if (split(name_tag, nt, ":") == 2) { cname=nt[1]; ctag=nt[2] } else { cname=name_tag; ctag="" }
      next
    }
    inc && comp != "" && ctag != "" && /^    digest: / { print cname "|" ctag "|" $2 "|" img; comp="" }
    /^platformRelease: / { print "platformRelease||" $2 }
    /^  minRelease: / { print "minRelease||" $2 }
  ' cname="" ctag="" "$VERSIONS_FILE")"
  PLATFORM="$(printf '%s\n' "$EXPECTED" | awk -F'|' '$1=="platformRelease"{print $3}')"
  MIN_RELEASE="$(printf '%s\n' "$EXPECTED" | awk -F'|' '$1=="minRelease"{print $3}')"
  expected_for() { printf '%s\n' "$EXPECTED" | awk -F'|' -v n="$1" '$1==n{print $2"|"$3"|"$4; exit}'; }

  # Live set: every compose container (-a: exited one-shots like minio-init
  # count too), the engine-injected execd/egress from the rendered config, and
  # the app-runtime base the platform deploys apps from (a config value: apps
  # may not be running right now, a stale pin must still be caught).
  LIVE_FILE="$(mktemp)"
  $DOCKER compose ps -aq 2>/dev/null | while read -r cid; do
    img="$($DOCKER inspect "$cid" --format '{{.Config.Image}}' 2>/dev/null)"
    [ -n "$img" ] && printf '%s|%s\n' "$cid" "$img"
  done > "$LIVE_FILE"
  if [ -f opensandbox.generated.toml ]; then
    sed -n 's/^execd_image = "\([^"]*\)".*/|\1/p; s/^image = "\([^"]*\)".*/|\1/p' opensandbox.generated.toml >> "$LIVE_FILE"
  fi
  # app-runtime default: the operative value is the LIVE infra-service env (the
  # .env file may have been edited without recreating the container).
  live_ar="$($DOCKER inspect infra-service --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | sed -n 's/^APP_RUNTIME_DEFAULT_IMAGE=//p' | head -1)"
  if [ -n "$live_ar" ] && [ -n "${APP_RUNTIME_DEFAULT_IMAGE:-}" ] && [ "$live_ar" != "$APP_RUNTIME_DEFAULT_IMAGE" ]; then
    printf '  [!]    APP_RUNTIME_DEFAULT_IMAGE drift: .env says %s, running infra-service uses %s\n         (docker compose up -d infra-service to apply the .env value)\n' "$APP_RUNTIME_DEFAULT_IMAGE" "$live_ar"
  fi
  ar_img="${live_ar:-${APP_RUNTIME_DEFAULT_IMAGE:-}}"
  [ -n "$ar_img" ] && printf '|%s\n' "$ar_img" >> "$LIVE_FILE"

  CHECKED=0
  while IFS='|' read -r cid img; do
    [ -n "$img" ] || continue
    ref="$img"; digest_pin=""
    case "$ref" in *@sha256:*) digest_pin="sha256:${ref#*@sha256:}"; ref="${ref%%@*}" ;; esac
    name_tag="${ref##*/}"
    name="${name_tag%%:*}"
    tag=""; case "$name_tag" in *:*) tag="${name_tag#*:}" ;; esac
    exp="$(expected_for "$name")"
    [ -n "$exp" ] || continue          # not a platform component (e.g. the local caddy build)
    exp_tag="${exp%%|*}"; exp_rest="${exp#*|}"; exp_digest="${exp_rest%%|*}"; exp_img="${exp_rest#*|}"
    CHECKED=$((CHECKED+1))
    hint="pin the tag to compare exactly"; [ "$name" = "teable" ] && hint="pin with ./pin-image.sh to compare exactly"
    if [ -n "$digest_pin" ]; then
      # Digest pins are conclusive against the canonical registry only
      # (mirrors serve the same content under different digests).
      ref_prefix=""; case "$ref" in */*) ref_prefix="${ref%/*}" ;; esac
      exp_prefix=""; case "$exp_img" in */*) exp_prefix="${exp_img%/*}" ;; esac
      if [ "$digest_pin" = "$exp_digest" ]; then
        ok "$name pinned by digest, matches ${PLATFORM:-versions.yaml}"
      elif [ "$ref_prefix" = "$exp_prefix" ]; then
        UNKNOWN_COMBO=1
        printf '  [!]    %s: digest-pinned to a different build than %s pins (%s)\n' "$name" "${PLATFORM:-the release}" "$exp_tag"
      else
        skip "$name digest-pinned from a mirror; digests differ per registry" "re-resolve the pin against the canonical registry to compare"
      fi
    elif [ "$tag" = "$exp_tag" ]; then
      ok "$name:$tag matches ${PLATFORM:-versions.yaml}"
    elif [ "$tag" = "latest" ]; then
      # :latest is a channel, not a version -- conclusive only if the digest of
      # what actually runs equals the canonical one. Resolve through the
      # container's image ID: the local tag may already point somewhere newer
      # than the running container.
      digs=""
      if [ -n "$cid" ]; then
        iid="$($DOCKER inspect "$cid" --format '{{.Image}}' 2>/dev/null)"
        [ -n "$iid" ] && digs="$($DOCKER image inspect "$iid" --format '{{range .RepoDigests}}{{println .}}{{end}}' 2>/dev/null)"
      else
        digs="$($DOCKER image inspect "$ref" --format '{{range .RepoDigests}}{{println .}}{{end}}' 2>/dev/null)"
      fi
      if printf '%s\n' "$digs" | grep -q "$exp_digest"; then
        ok "$name:latest currently IS $exp_tag (digest match)"
      else
        # Indeterminate, not a combination problem: latest is the stable channel.
        skip "cannot map $name:latest to a release pin (mirror pull, newer build, or image not pulled yet)" "$hint"
      fi
    elif [ "$name" = "teable" ] && [ "${tag#release.}" != "$tag" ]; then
      # The app has its own release line; the manifest declares a window, not one pin.
      if [ -n "$MIN_RELEASE" ] && [[ "$tag" < "$MIN_RELEASE" ]]; then
        bad "Teable app $tag is older than this platform release supports (min: $MIN_RELEASE)" "upgrade the Teable app image first; see migration/ if you are coming from a standalone install"
      else
        ok "Teable app $tag is within the compatibility window (verified: $exp_tag)"
      fi
    else
      UNKNOWN_COMBO=1
      printf '  [!]    %s: running %s, release pins %s\n' "$name" "$tag" "$exp_tag"
    fi
  done < <(awk -F'|' '!seen[$2]++' "$LIVE_FILE")
  rm -f "$LIVE_FILE"
  if [ "$CHECKED" = 0 ]; then
    skip "platform release check" "no running component matched versions.yaml"
  elif [ "$UNKNOWN_COMBO" = 1 ]; then
    printf '  [!]    unknown combination -- this exact set was never verified together.\n'
    printf '         Align every component with one platform release (see VERSIONS.md).\n'
  fi
  # Deployed apps ride the app-runtime base on redeploy: older bases keep
  # running by design, so report them without flagging the combination.
  exp_ar="$(expected_for "teable-app-runtime")"
  if [ -n "$exp_ar" ]; then
    exp_ar_tag="${exp_ar%%|*}"
    ar_stale=0; ar_total=0
    while IFS= read -r img; do
      [ -n "$img" ] || continue
      case "$img" in */teable-app-runtime:*|teable-app-runtime:*) ;; *) continue ;; esac
      ar_total=$((ar_total+1))
      case "$img" in *:"$exp_ar_tag") ;; *) ar_stale=$((ar_stale+1)) ;; esac
    done < <($DOCKER ps --filter label=teable.app-runtime.managed=true --format '{{.Image}}' 2>/dev/null | sort -u)
    if [ "$ar_stale" -gt 0 ]; then
      printf '  [..]   %s of %s deployed app base image(s) predate this release; apps pick the new base on redeploy (by design)\n' "$ar_stale" "$ar_total"
    elif [ "$ar_total" -gt 0 ]; then
      ok "all deployed apps run the release app-runtime base ($ar_total image variant(s))"
    fi
  fi
fi

# ---------- Summary ----------
sec "Summary"
printf '  passed %d / failed %d / skipped %d\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
  echo "  ✗ Some checks failed; triage using the 'First place to look' hints and re-run."
  exit 1
fi
if [ "$UNKNOWN_COMBO" = 1 ]; then
  echo "  ✓ Checks passed, but the component combination is unverified (see Platform release)."
else
  echo "  ✓ All checks passed."
fi
