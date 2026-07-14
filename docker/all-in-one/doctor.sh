#!/usr/bin/env bash
# Teable all-in-one self-check (doctor): post-deploy acceptance + first-layer fault triage.
#   ./doctor.sh                Full check (includes sandbox create/destroy; first image pull may be slow)
#   ./doctor.sh --no-sandbox   Skip sandbox creation (fast mode)
# Each check maps to a real failure mode; every FAIL hint names the first layer to inspect.
# Containers being healthy alone does NOT count as passing -- routing, contract env, the three storage planes, and the sandbox chain must all be genuinely verified.
set -uo pipefail
cd "$(dirname "$0")"
# Assets (compose files, .env) live alongside this script; the cd-guard below also supports running it from a parent directory.
[ -f .env ] || [ -f compose.yaml ] || { [ -d ../docker/all-in-one ] && cd ../docker/all-in-one; }

NO_SANDBOX=0
[ "${1:-}" = "--no-sandbox" ] && NO_SANDBOX=1

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
  printf '  [FAIL] .env missing\n         ↳ First place to look: run ./apply.sh local|cloud [--with-app] first\n'; exit 1; fi
set -a; . ./.env; set +a

APP_MODE=0; case "${COMPOSE_FILE:-}" in *compose.app.yaml*) APP_MODE=1 ;; esac
MODE=local;  case "${COMPOSE_FILE:-}" in *compose.cloud.yaml*) MODE=cloud ;; esac
echo "  Mode: ${MODE}$( [ "$APP_MODE" = 1 ] && echo ' + app(all-in-one)' )"

# Entry addresses: local goes through localhost + Host header; cloud uses the real domains
if [ "$MODE" = "cloud" ]; then
  TEABLE_URL="https://${TEABLE_HOST:-}"
  INFRA_URL="https://${INFRA_HOST:-}"
  S3_HEALTH_URL="https://s3.${BASE_DOMAIN:-}/minio/health/live"
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
INFRA_HOSTHDR="$( [ "$MODE" = cloud ] && echo "" || echo "infra.localhost" )"

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
    need SANDBOX_PREVIEW_HOST "run ./apply.sh local --with-app (cloud injects sandbox.<BASE_DOMAIN> via compose, no .env entry needed)"
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
if [ "$APP_MODE" = 1 ]; then
  code=$(req "${TEABLE_URL}/health")
  [ "$code" = 200 ] && ok "Teable /health (fallback route) -> 200" || bad "Teable /health -> $code" "teable container or caddy fallback (is the app Caddyfile mounted?)"
  # The public bucket path must land on MinIO: an anonymous list being denied is 403 (a 404 means it landed on Teable, i.e. bucket path forwarding is missing)
  code=$(req "${TEABLE_URL}/${TEABLE_PUBLIC_BUCKET:-teable-public}/" )
  case "$code" in
    200|403) ok "Public bucket path /${TEABLE_PUBLIC_BUCKET:-teable-public}/ -> $code (handled by MinIO)" ;;
    *) bad "Public bucket path -> $code" "caddy public-bucket forwarding missing (attachments/avatars will 404)" ;;
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
    *)  bad "TEABLE_INFRA_API_URL is empty" "compose.app.{local,cloud}.yaml" ;;
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

# ---------- Summary ----------
sec "Summary"
printf '  passed %d / failed %d / skipped %d\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
  echo "  ✗ Some checks failed; triage using the 'First place to look' hints and re-run."
  exit 1
fi
echo "  ✓ All checks passed."
