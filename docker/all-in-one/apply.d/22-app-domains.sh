# App custom domains (server only): APP_CUSTOM_DOMAINS="<domain>=<app access link>[,...]" serves published apps on
# domains outside *.app.<BASE_DOMAIN>, e.g. portal.example.org=portal.app.teable.example.com (the right side may also be
# just the access-link name, "portal"). Validated here; 25-tls.sh renders one Caddy site per domain and infra-service
# (APP_RUNTIME_CUSTOM_DOMAINS) maps each domain to its app. Guide: README.md, "App custom domains".
APP_DOMAIN_LIST=""   # validated domains, one per line, consumed by 25-tls.sh

if [ -n "${APP_CUSTOM_DOMAINS:-}" ] && [ "$MODE" = "local" ]; then
  echo "[!] APP_CUSTOM_DOMAINS is ignored in local mode: custom domains need server mode (real domains + HTTPS)"
fi

if [ -n "${APP_CUSTOM_DOMAINS:-}" ] && [ "$MODE" = "server" ]; then
  reload_env   # INFRA_HOST / TEABLE_HOST as derived by 20-domains
  dns_name='^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
  dns_label='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
  app_suffix="app.${BASE_DOMAIN}"
  # Split on commas and whitespace without letting the shell glob-expand an entry such as *.example.org.
  entries="$(printf '%s\n' "${APP_CUSTOM_DOMAINS}" | tr ',[:space:]' '\n\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d')"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    domain="${entry%%=*}"; domain="${domain%.}"
    target="${entry#*=}"; target="${target%.}"
    if [ "$domain" = "$entry" ] || [ -z "$target" ] || [ "${#domain}" -gt 253 ] || ! printf '%s' "$domain" | grep -Eq "$dns_name"; then
      echo "[x] APP_CUSTOM_DOMAINS entry must look like <domain>=<app access link>: ${entry}"; exit 1
    fi
    case "$target" in *.*) ;; *) target="${target}.${app_suffix}" ;; esac
    if [ "${target%."${app_suffix}"}" = "$target" ] || ! printf '%s' "${target%."${app_suffix}"}" | grep -Eq "$dns_label"; then
      echo "[x] APP_CUSTOM_DOMAINS: ${target} is not an app access link (expected <name>.${app_suffix})"; exit 1
    fi
    case "$domain" in
      *."${app_suffix}"|*.sandbox."${BASE_DOMAIN}"|"${INFRA_HOST:-}"|"${TEABLE_HOST:-}")
        echo "[x] APP_CUSTOM_DOMAINS: ${domain} is already served by this deployment; pick a domain outside it"; exit 1 ;;
    esac
    if printf '%s\n' "$APP_DOMAIN_LIST" | grep -qxF "$domain"; then
      echo "[x] APP_CUSTOM_DOMAINS lists ${domain} more than once"; exit 1
    fi
    APP_DOMAIN_LIST="${APP_DOMAIN_LIST:+${APP_DOMAIN_LIST}
}${domain}"
    echo "     app domain ${domain} -> ${target}"
  done <<EOF
${entries}
EOF
fi
