# Domain/address derivation -- single-root-domain principle:
#   cloud: the only domain concept is BASE_DOMAIN; every service is split from it (main site = root domain,
#          infra. subdomain carrying /v1+git+storage paths, *.app/*.sandbox wildcards). To use separate domains, fill the matching
#          *_HOST override in the .env "advanced" section (blank = derived).
#   local: no domain concept at all; everything is *.localhost + LAN IP (attachment/artifact presigned URLs
#          require the browser and the containers to reach the same address).

if [ "$MODE" = "cloud" ]; then
  # --- Required (non-secret) validation: only you can fill these; the script will not invent them ---
  miss=0
  for v in BASE_DOMAIN ACME_EMAIL CLOUDFLARE_API_TOKEN; do
    eval "val=\${$v:-}"
    [ -n "$val" ] || { echo "[x] .env is missing $v (fill it by hand)"; miss=1; }
  done
  [ "$miss" = 0 ] || { echo "    Fill them in, then re-run ./apply.sh cloud."; exit 1; }

  if [ "$WITH_APP" = 1 ]; then
    # all-in-one: the Teable main site takes the root domain, the console yields to the infra subdomain (the two must never collide)
    TEABLE_HOST_EFF="${TEABLE_HOST:-${BASE_DOMAIN}}"
    set_if_blank TEABLE_HOST "${TEABLE_HOST_EFF}" "$ENV_FILE"
    set_if_blank INFRA_HOST "infra.${BASE_DOMAIN}" "$ENV_FILE"
    INFRA_HOST_EFF="$(grep -E '^INFRA_HOST=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
    # Upgrading an existing infra-only cloud deploy: its auto-derived INFRA_HOST was the root domain,
    # which now belongs to the Teable site -- migrate it to the infra. subdomain instead of erroring out.
    if [ "$INFRA_HOST_EFF" = "$BASE_DOMAIN" ] && [ "$TEABLE_HOST_EFF" = "$BASE_DOMAIN" ]; then
      set_kv INFRA_HOST "infra.${BASE_DOMAIN}" "$ENV_FILE"
      INFRA_HOST_EFF="infra.${BASE_DOMAIN}"
      echo "[update] INFRA_HOST: ${BASE_DOMAIN} -> infra.${BASE_DOMAIN} (root domain is now the Teable site)"
    fi
    if [ "$TEABLE_HOST_EFF" = "$INFRA_HOST_EFF" ]; then
      echo "[x] TEABLE_HOST equals INFRA_HOST (${TEABLE_HOST_EFF}): the Teable main site and the Infra console must be on two separate Hosts."
      exit 1
    fi
    set_if_blank PUBLIC_ORIGIN "https://${TEABLE_HOST_EFF}" "$ENV_FILE"
    set_if_blank TEABLE_MINIO_ENDPOINT_HOST "${INFRA_HOST_EFF}" "$ENV_FILE"
    set_if_blank TEABLE_MINIO_ENDPOINT_PORT "443" "$ENV_FILE"
    set_if_blank TEABLE_MINIO_USE_SSL "true" "$ENV_FILE"
  else
    set_if_blank INFRA_HOST "${BASE_DOMAIN}" "$ENV_FILE"    # infra-only: the console uses the root domain directly
  fi
fi

if [ "$MODE" = "local" ]; then
  LAN_IP="$(detect_lan_ip)"
  # The presigned host must be identical on both sides (uploader + infra-service); filled with a default the first time, then follows LAN IP changes.
  set_if_blank S3_ENDPOINT "http://${LAN_IP}:9000" "$ENV_FILE"
  set_if_blank GIT_REGISTRY_PUBLIC_URL "http://${LAN_IP}:8081" "$ENV_FILE"
  refresh_lan_ip S3_ENDPOINT "$LAN_IP" "$ENV_FILE"
  refresh_lan_ip GIT_REGISTRY_PUBLIC_URL "$LAN_IP" "$ENV_FILE"
  echo "     LAN IP = ${LAN_IP} (if the IP changes, re-running ./apply.sh local rewrites it automatically; if the uploader is on a different network segment than this machine, change it by hand to an address reachable by both)"

  if [ "$WITH_APP" = 1 ]; then
    set_if_blank PUBLIC_ORIGIN "http://${LAN_IP}:80" "$ENV_FILE"
    refresh_lan_ip PUBLIC_ORIGIN "$LAN_IP" "$ENV_FILE"
    set_if_blank TEABLE_MINIO_ENDPOINT_HOST "${LAN_IP}" "$ENV_FILE"
    # refresh_lan_ip does not recognize the bare-host form, so track it separately (rewrite only when the current value is an IPv4 that differs from the LAN IP)
    cur_minio_host="$(grep -E '^TEABLE_MINIO_ENDPOINT_HOST=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
    if printf '%s' "$cur_minio_host" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
       && [ "$cur_minio_host" != "$LAN_IP" ] && [ "$LAN_IP" != "127.0.0.1" ]; then
      set_kv TEABLE_MINIO_ENDPOINT_HOST "$LAN_IP" "$ENV_FILE"
      echo "[update] TEABLE_MINIO_ENDPOINT_HOST: ${cur_minio_host} -> ${LAN_IP} (LAN IP changed)"
    fi
    set_if_blank TEABLE_MINIO_ENDPOINT_PORT "9000" "$ENV_FILE"
    set_if_blank TEABLE_MINIO_USE_SSL "false" "$ENV_FILE"
    # Sandbox endpoint/preview domain: local always uses local domain names (zero external dependencies). Known limitation: AI chat's agent
    # connection cannot resolve local domains from inside containers yet (a sandbox-SDK improvement is planned); deploy/build flows are
    # unaffected -- use cloud mode with a real domain for AI chat.
    set_if_blank SANDBOX_PREVIEW_HOST "sandbox.localhost" "$ENV_FILE"
  fi
fi
