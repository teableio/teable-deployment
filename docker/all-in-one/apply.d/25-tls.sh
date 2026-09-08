# TLS mode (server only) + private-CA input validation (both modes).
#   cloudflare: ACME_EMAIL + CLOUDFLARE_API_TOKEN -> caddy built with the DNS plugin issues the wildcard certificate (DNS-01).
#   static:     TLS_CERT_FILE + TLS_KEY_FILE      -> the official caddy image serves your own certificate (private networks,
#               corporate CAs, no DNS API). The certificate must cover the four names the entry serves.
# The mode is derived from which inputs are filled (never invented) and persisted to .env as TLS_MODE / CADDY_IMAGE for
# compose; the Caddyfile templates are rendered to *.generated so the TLS directives match the mode.
reload_env   # pick up INFRA_HOST / TEABLE_HOST derived by 20-domains

if [ -n "${PRIVATE_CA_FILE:-}" ]; then
  case "${PRIVATE_CA_FILE}" in /*) ;; *) echo "[x] PRIVATE_CA_FILE must be an absolute host path: ${PRIVATE_CA_FILE}"; exit 1 ;; esac
  [ -f "${PRIVATE_CA_FILE}" ] || { echo "[x] PRIVATE_CA_FILE points at a missing file: ${PRIVATE_CA_FILE}"; exit 1; }
  grep -q "BEGIN CERTIFICATE" "${PRIVATE_CA_FILE}" || { echo "[x] PRIVATE_CA_FILE is not a PEM certificate: ${PRIVATE_CA_FILE}"; exit 1; }
fi
# Fingerprint of the CA file: the private-CA overlays expose it as an environment variable, so replacing the
# file's content (rotation) changes the service definitions and `docker compose up -d` recreates the
# containers that load it at start (Node reads NODE_EXTRA_CA_CERTS once).
set_kv PRIVATE_CA_SHA256 "$( [ -n "${PRIVATE_CA_FILE:-}" ] && file_sha256 "${PRIVATE_CA_FILE}" )" "$ENV_FILE"

if [ "$MODE" = "server" ]; then
  if [ -n "${TLS_CERT_FILE:-}" ] || [ -n "${TLS_KEY_FILE:-}" ]; then
    TLS_MODE_EFF=static
    for v in TLS_CERT_FILE TLS_KEY_FILE; do
      eval "val=\${$v:-}"
      [ -n "$val" ] || { echo "[x] $v is empty: your own certificate needs both TLS_CERT_FILE and TLS_KEY_FILE"; exit 1; }
      case "$val" in /*) ;; *) echo "[x] $v must be an absolute host path: $val"; exit 1 ;; esac
      [ -f "$val" ] || { echo "[x] $v points at a missing file: $val"; exit 1; }
    done
    # Warn (not fail) when the certificate does not cover one of the served names: the stack still starts,
    # but browsers and the app reject that host with ERR_TLS_CERT_ALTNAME_INVALID. Same rule as doctor.sh:
    # a name is covered by an exact SAN or by the single-label wildcard of its parent (`*.example.com`
    # covers `infra.example.com`); a wildcard name itself needs that exact wildcard SAN.
    # -text works on OpenSSL and LibreSSL alike (the -ext flag does not); the SAN list follows its header line.
    san="$(openssl x509 -in "${TLS_CERT_FILE}" -noout -text 2>/dev/null | awk '/Subject Alternative Name/{getline; print; exit}' | tr -d ' ' | tr ',' '\n')"
    if [ -n "$san" ]; then
      for n in ${TEABLE_HOST:-} "${INFRA_HOST}" "*.app.${BASE_DOMAIN}" "*.sandbox.${BASE_DOMAIN}"; do
        if printf '%s\n' "$san" | grep -qxF "DNS:${n}"; then continue; fi
        case "$n" in \*.*) ;; *) if printf '%s\n' "$san" | grep -qxF "DNS:*.${n#*.}"; then continue; fi ;; esac
        echo "[!] TLS_CERT_FILE does not cover ${n} (subjectAltName lists: $(printf '%s' "$san" | tr '\n' ' ')) -- browsers and the app will reject that host"
      done
    else
      echo "[!] could not read subjectAltName from TLS_CERT_FILE (is it PEM with the full chain?)"
    fi
    CADDY_IMAGE_EFF="${CADDY_STATIC_IMAGE:-caddy:2.9.1}"   # official image; mirrored via CADDY_STATIC_IMAGE on air-gapped hosts
    TLS_CERT_SHA256_EFF="$(file_sha256 "${TLS_CERT_FILE}")"    # same trick as the CA: a replaced certificate recreates caddy on `up -d`
    TLS_GLOBAL=""
    TLS_SITE="tls /certs/fullchain.pem /certs/privkey.pem"
  else
    TLS_MODE_EFF=cloudflare
    miss=0
    for v in ACME_EMAIL CLOUDFLARE_API_TOKEN; do
      eval "val=\${$v:-}"
      [ -n "$val" ] || { echo "[x] .env is missing $v"; miss=1; }
    done
    if [ "$miss" != 0 ]; then
      echo "    Pick one TLS option in .env: ACME_EMAIL + CLOUDFLARE_API_TOKEN (automatic certificates via Cloudflare DNS-01),"
      echo "    or TLS_CERT_FILE + TLS_KEY_FILE (your own certificate). Then re-run ./apply.sh server."
      exit 1
    fi
    CADDY_IMAGE_EFF="teable-infra/caddy-cloudflare:server"
    TLS_CERT_SHA256_EFF=""
    TLS_GLOBAL=$'{\n\temail {$ACME_EMAIL}\n\tacme_dns cloudflare {env.CLOUDFLARE_API_TOKEN} # token needs Zone:Read + DNS:Edit\n}\n'
    TLS_SITE=""
  fi
  set_kv TLS_MODE "${TLS_MODE_EFF}" "$ENV_FILE"
  set_kv CADDY_IMAGE "${CADDY_IMAGE_EFF}" "$ENV_FILE"
  set_kv TLS_CERT_SHA256 "${TLS_CERT_SHA256_EFF}" "$ENV_FILE"
  echo "     TLS mode = ${TLS_MODE_EFF} (caddy image ${CADDY_IMAGE_EFF})"
  render_caddyfile Caddyfile.server Caddyfile.server.generated "$TLS_GLOBAL" "$TLS_SITE"
  render_caddyfile Caddyfile.app.server Caddyfile.app.server.generated "$TLS_GLOBAL" "$TLS_SITE"
  reload_env
fi
