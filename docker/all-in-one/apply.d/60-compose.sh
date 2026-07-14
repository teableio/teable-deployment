# COMPOSE_FILE: base + overlay [+ app overlay] + git override.
# Once COMPOSE_FILE is set docker no longer auto-merges the override, so include it explicitly; this must be written after the override is generated for it to enter the chain.
CF="compose.yaml:compose.${MODE}.yaml"
[ "$WITH_APP" = 1 ] && CF="${CF}:compose.app.yaml:compose.app.${MODE}.yaml"
# --dev appends a compose.dev.yaml overlay if you create one (not shipped); appended last, so its settings win.
[ "${DEV:-0}" = 1 ] && [ -f compose.dev.yaml ] && CF="${CF}:compose.dev.yaml"
[ -f "$OVERRIDE_FILE" ] && CF="${CF}:${OVERRIDE_FILE}"
set_kv COMPOSE_FILE "$CF" "$ENV_FILE"
