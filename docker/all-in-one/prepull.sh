#!/usr/bin/env bash
# Pre-warm the execution-plane images to avoid a cold-start pull when the first sandbox launches. The registry defaults to the public distribution registry; the images must already be set in .env (same source as compose).
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then set -a; . ./.env; set +a; fi
REG="${OPENSANDBOX_REGISTRY:-sandbox-registry.cn-zhangjiakou.cr.aliyuncs.com/opensandbox}"   # registry prefix (execd/egress live under it)
# The server image is resolved separately via OPENSANDBOX_SERVER_IMAGE, not from this registry prefix.
SERVER="${OPENSANDBOX_SERVER_IMAGE:?set in .env}"
# The sandbox agent image is NOT pre-pulled here: SANDBOX_OPENSANDBOX_IMAGE is a
# tagless prefix, and the Teable app preheats <prefix>:<its own release tag> through
# the Infra API by itself.

for img in \
  "${SERVER}" \
  "${REG}/execd:v1.0.18" \
  "${REG}/egress:v1.0.12"; do
  echo "==> docker pull ${img}"
  docker pull "${img}"
done
echo "[ok] OpenSandbox execution-plane images pre-warmed."
