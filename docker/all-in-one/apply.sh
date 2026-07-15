#!/usr/bin/env bash
# Unified configuration entry point:
#   ./apply.sh local               Fully automatic: fill secrets / derive addresses / render toml / write COMPOSE_FILE.
#   ./apply.sh server               Validate required fields (BASE_DOMAIN/email/CF Token) + same as above.
#   ./apply.sh local|server --with-app   Add Teable app + PG + Redis (all-in-one) on top of the Infra stack.
# .env is the single source of truth; only blank secrets/derived values get filled (existing values are never touched), so it is safe to re-run.
# Behavior is split in order under apply.d/ (one concern per file, sourced sequentially, sharing this shell's variables):
#   10-env      .env initialization and loading
#   20-domains  domain/address derivation (split from single root domain; local probes LAN IP)
#   30-secrets  fill in secret and image defaults
#   40-runtime  render opensandbox toml + pre-create agent volume
#   50-git-keys git Ed25519 keys -> override (never rotates already-generated keys; to rotate, delete the override first)
#   60-compose  assemble COMPOSE_FILE
set -euo pipefail
cd "$(dirname "$0")"
. ./lib.sh

MODE="${1:-}"
WITH_APP=0
DEV=0
shift || true
for arg in "$@"; do
  case "$arg" in
    --with-app) WITH_APP=1 ;;
    --dev) DEV=1 ;;   # --dev appends a compose.dev.yaml overlay if you create one (not shipped)
    *) echo "Usage: ./apply.sh local|server [--with-app]"; exit 1 ;;
  esac
done
case "$MODE" in
  local|server) ;;
  *) echo "Usage: ./apply.sh local|server [--with-app]"; exit 1 ;;
esac

for step in apply.d/[0-9]*.sh; do
  . "$step"
done

echo "[done] Next step: docker compose up -d"
