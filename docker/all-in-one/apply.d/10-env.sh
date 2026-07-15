# .env initialization and loading (sourced by apply.sh, shares MODE/WITH_APP).
ENV_FILE=".env"
OVERRIDE_FILE="docker-compose.override.yml"
EXAMPLE=".env.${MODE}.example"

command -v openssl >/dev/null 2>&1 || { echo "[x] openssl is required"; exit 1; }

# If .env does not exist, copy it from the matching template (server requires the user to hand-fill BASE_DOMAIN etc. first, then re-run).
if [ ! -f "$ENV_FILE" ]; then
  [ -f "$EXAMPLE" ] || { echo "[x] $EXAMPLE missing"; exit 1; }
  cp "$EXAMPLE" "$ENV_FILE"
  echo "[init] $ENV_FILE generated from $EXAMPLE"
  if [ "$MODE" = "server" ]; then
    echo "[x] server mode: hand-fill BASE_DOMAIN / ACME_EMAIL / CLOUDFLARE_API_TOKEN in .env first, then re-run ./apply.sh server."
    exit 1
  fi
fi

reload_env
