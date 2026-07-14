#!/usr/bin/env bash
# Pin TEABLE_IMAGE from latest to a definite version (recommended for production; for Kubernetes, paste the resolved reference into the image fields of your values).
#   ./pin-image.sh          Resolve and write TEABLE_IMAGE back into .env
#   ./pin-image.sh --show   Print the result only, without writing (for Kubernetes, paste it into the image fields of your values)
# Resolution strategy: prefer the newest semver tag in the repo; if there is none (the current release shape),
# take the digest that latest points to right now (`<repo>@sha256:...`). Pure curl, no docker needed.
# WARNING: digests are computed per registry: once you pin a ghcr digest, do not switch to a registry mirror prefix
# (e.g. a China registry mirror) afterwards (if you do switch prefixes, re-run this script after switching).
set -euo pipefail
cd "$(dirname "$0")"
# Assets (compose files, .env) live alongside this script; the cd-guard below also supports running it from a parent directory.
[ -f lib.sh ] || { [ -d ../docker/all-in-one ] && cd ../docker/all-in-one; }
. ./lib.sh

SHOW=0
[ "${1:-}" = "--show" ] && SHOW=1

IMAGE="$(grep -E '^TEABLE_IMAGE=' .env 2>/dev/null | head -1 | cut -d= -f2-)"
IMAGE="${IMAGE:-ghcr.io/teableio/teable:latest}"

REG="${IMAGE%%/*}"                       # ghcr.io
REPO="${IMAGE#*/}"; REPO="${REPO%%[@:]*}" # teableio/teable
TAG="${IMAGE##*:}"; case "$IMAGE" in *@*) TAG="latest";; *:*) ;; *) TAG="latest";; esac

if [ "$REG" != "ghcr.io" ]; then
  echo "[!] Only ghcr.io resolution is supported (current: $REG). For other registries, confirm the version manually and fill TEABLE_IMAGE."
  exit 1
fi

TOKEN="$(curl -fsS "https://ghcr.io/token?scope=repository:${REPO}:pull" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[ -n "$TOKEN" ] || { echo "[x] Failed to obtain registry token (network?)"; exit 1; }

# 1) Prefer semver tags
SEMVER="$(curl -fsS -H "Authorization: Bearer ${TOKEN}" \
  "https://ghcr.io/v2/${REPO}/tags/list?n=2000" \
  | tr ',' '\n' | sed -n 's/.*"\(v\{0,1\}[0-9][0-9.]*\)".*/\1/p' \
  | grep -E '^v?[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | tail -1 || true)"

if [ -n "$SEMVER" ]; then
  PINNED="ghcr.io/${REPO}:${SEMVER}"
  echo "[ok] Latest version tag: ${SEMVER}"
else
  # 2) Fallback: the digest latest currently points to (Docker-Content-Digest header from a HEAD manifest request)
  DIGEST="$(curl -fsSI -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/${REPO}/manifests/${TAG}" \
    | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}')"
  [ -n "$DIGEST" ] || { echo "[x] Failed to resolve the digest of ${TAG}"; exit 1; }
  PINNED="ghcr.io/${REPO}@${DIGEST}"
  echo "[ok] No version tag; pinning the current digest of ${TAG}"
fi

echo "     ${PINNED}"
if [ "$SHOW" = 1 ]; then
  echo "(--show mode, not written to .env; for Kubernetes, paste this reference into the image fields of your values)"
else
  [ -f .env ] || { echo "[x] .env missing (run ./apply.sh first)"; exit 1; }
  set_kv TEABLE_IMAGE "$PINNED" .env
  echo "[done] TEABLE_IMAGE written to .env; restart with: docker compose up -d teable"
fi
