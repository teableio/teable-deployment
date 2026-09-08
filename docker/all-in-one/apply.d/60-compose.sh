# COMPOSE_FILE: base + overlay [+ app overlay] + git override.
# Once COMPOSE_FILE is set docker no longer auto-merges the override, so include it explicitly; this must be written after the override is generated for it to enter the chain.
CF="compose.yaml:compose.${MODE}.yaml"
# server: the TLS mode picked by 25-tls.sh selects the caddy overlay (plugin build vs. your own certificate files).
if [ "$MODE" = "server" ]; then
  case "${TLS_MODE:-}" in
    cloudflare) CF="${CF}:compose.server.caddy-build.yaml" ;;
    static)     CF="${CF}:compose.server.static-tls.yaml" ;;
    *) echo "[x] TLS_MODE is not set (25-tls.sh should have derived it)"; exit 1 ;;
  esac
fi
# Private CA: the app-side containers (infra-service, and the Teable app with --with-app) must trust it too.
[ -n "${PRIVATE_CA_FILE:-}" ] && CF="${CF}:compose.private-ca.yaml"
if [ "$WITH_APP" = 1 ]; then
  CF="${CF}:compose.app.yaml:compose.app.${MODE}.yaml"
  [ -n "${PRIVATE_CA_FILE:-}" ] && CF="${CF}:compose.app.private-ca.yaml"
fi
# --dev appends a compose.dev.yaml overlay if you create one (not shipped); appended last, so its settings win.
[ "${DEV:-0}" = 1 ] && [ -f compose.dev.yaml ] && CF="${CF}:compose.dev.yaml"
[ -f "$OVERRIDE_FILE" ] && CF="${CF}:${OVERRIDE_FILE}"
set_kv COMPOSE_FILE "$CF" "$ENV_FILE"
