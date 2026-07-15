#!/usr/bin/env bash
# Pre-warm the execution-plane images to avoid a cold-start pull when the first sandbox launches. Image references come from .env (same source as compose / the rendered engine config).
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then set -a; . ./.env; set +a; fi
SERVER="${OPENSANDBOX_SERVER_IMAGE:?set in .env}"
# Same defaults as apply.d/40-runtime.sh (the rendered opensandbox.generated.toml is the actual source of truth).
EXECD="${EXECD_IMAGE:-ghcr.io/teableio/opensandbox-execd:v1.0.19-fix2}"
EGRESS="${EGRESS_IMAGE:-ghcr.io/teableio/opensandbox-egress:v1.0.12}"
# The sandbox agent image is NOT pre-pulled here: SANDBOX_OPENSANDBOX_IMAGE is a
# tagless prefix, and the Teable app preheats <prefix>:<its own release tag> through
# the Infra API by itself.

for img in \
  "${SERVER}" \
  "${EXECD}" \
  "${EGRESS}"; do
  echo "==> docker pull ${img}"
  docker pull "${img}"
done
echo "[ok] OpenSandbox execution-plane images pre-warmed."
