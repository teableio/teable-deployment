# Render the engine config + pre-create the shared agent volume.
reload_env   # pick up the values just filled in by 20/30

# Render opensandbox.generated.toml (the sandbox network name comes from SANDBOX_DOCKER_NETWORK, same as compose -- single source)
REG="${OPENSANDBOX_REGISTRY:-sandbox-registry.cn-zhangjiakou.cr.aliyuncs.com/opensandbox}"
SANDBOX_NET="${SANDBOX_DOCKER_NETWORK:-teable-sandbox-net}"
render_toml "${REG}" "${SANDBOX_NET}"

# Pre-create the shared agent workspace volume (declared external in compose; idempotent)
if command -v docker >/dev/null 2>&1; then
  docker volume create teable-agent-juicefs >/dev/null 2>&1 || true
else
  echo "[!] docker not detected; before up, run docker volume create teable-agent-juicefs by hand."
fi
