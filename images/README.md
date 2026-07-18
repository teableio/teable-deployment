# Images

> Generated for platform release **v2026.7.8** -- do not edit by hand.
> The authoritative pin list (with digests) is [`../versions.yaml`](../versions.yaml).

All first-party images are published multi-arch (amd64 + arm64) and
anonymously pullable. No registry login is needed for a default install.

## China mirror

Every first-party image is mirrored with **identical tags**:

| Canonical (ghcr.io) | Mirror (Aliyun Shenzhen) |
|---|---|
| `ghcr.io/teableio/teable:release.2026-07-17T14-54-52Z.2273` | `registry.cn-shenzhen.aliyuncs.com/teable/teable:release.2026-07-17T14-54-52Z.2273` |
| `ghcr.io/teableio/teable-app-runtime:20260717T042653Z` | `registry.cn-shenzhen.aliyuncs.com/teable/teable-app-runtime:20260717T042653Z` |
| `ghcr.io/teableio/teable-infra-service:20260717T042653Z` | `registry.cn-shenzhen.aliyuncs.com/teable/teable-infra-service:20260717T042653Z` |
| `ghcr.io/teableio/opensandbox-server:v0.2.0-fix6` | `registry.cn-shenzhen.aliyuncs.com/teable/opensandbox-server:v0.2.0-fix6` |
| `ghcr.io/teableio/opensandbox-ingress:v1.0.7` | `registry.cn-shenzhen.aliyuncs.com/teable/opensandbox-ingress:v1.0.7` |
| `ghcr.io/teableio/opensandbox-controller:v0.2.0` | `registry.cn-shenzhen.aliyuncs.com/teable/opensandbox-controller:v0.2.0` |
| `ghcr.io/teableio/opensandbox-image-committer:v0.1.0` | `registry.cn-shenzhen.aliyuncs.com/teable/opensandbox-image-committer:v0.1.0` |
| `ghcr.io/teableio/opensandbox-execd:v1.0.19-fix2` | `registry.cn-shenzhen.aliyuncs.com/teable/opensandbox-execd:v1.0.19-fix2` |
| `ghcr.io/teableio/opensandbox-egress:v1.0.12` | `registry.cn-shenzhen.aliyuncs.com/teable/opensandbox-egress:v1.0.12` |

Swap the prefix wherever an image is configured (`.env` for Docker, your
values file for Kubernetes). Digests are computed per registry: if you pin by
digest, re-resolve after switching prefixes.

Third-party images come from their upstream registries and are not mirrored
by us:

- `postgres:15.4` (postgres)
- `redis:7.2.4` (redis)
- `minio/minio:RELEASE.2025-04-22T22-12-26Z` (minio)
- `minio/mc:RELEASE.2025-04-16T18-13-26Z` (minio-mc)

## Air-gapped / private registry

Mirror the full set into your own registry, keeping the tags:

```bash
REGISTRY=registry.example.com/teable   # your prefix
for img in \
    ghcr.io/teableio/teable:release.2026-07-17T14-54-52Z.2273 \
    ghcr.io/teableio/teable-app-runtime:20260717T042653Z \
    ghcr.io/teableio/teable-infra-service:20260717T042653Z \
    ghcr.io/teableio/opensandbox-server:v0.2.0-fix6 \
    ghcr.io/teableio/opensandbox-ingress:v1.0.7 \
    ghcr.io/teableio/opensandbox-controller:v0.2.0 \
    ghcr.io/teableio/opensandbox-image-committer:v0.1.0 \
    ghcr.io/teableio/opensandbox-execd:v1.0.19-fix2 \
    ghcr.io/teableio/opensandbox-egress:v1.0.12 \
    postgres:15.4 \
    redis:7.2.4 \
    minio/minio:RELEASE.2025-04-22T22-12-26Z \
    minio/mc:RELEASE.2025-04-16T18-13-26Z \
    ghcr.io/teableio/teable-sandbox-agent:release.2026-07-17T14-54-52Z.2273; do
  docker pull "$img"
  docker tag "$img" "$REGISTRY/${img##*/}"
  docker push "$REGISTRY/${img##*/}"
done
```

The last entry is the sandbox agent paired with this release's verified
Teable tag -- the app pulls `<prefix>:<its own release tag>` at runtime, so
if you run a different app release, mirror the agent tag that matches it.

Then substitute your prefix in `.env` / your values, and add it to
`APP_RUNTIME_ALLOWED_IMAGE_PREFIXES` (Docker) or
`infraService.appRuntime.allowedImagePrefixes` (Helm).

## Engine-injected images

`opensandbox-execd` is injected into **every sandbox container** by the
sandbox engine, and `opensandbox-egress` is started as a per-sandbox sidecar
on demand -- sandbox nodes must be able to pull both. On Kubernetes the
bundled image-preheater DaemonSet pre-pulls them on every node; on Docker,
`prepull.sh` warms them. Upgrade them only together with `opensandbox-server`
(one platform release moves them as a set).

## Sandbox agent

`ghcr.io/teableio/teable-sandbox-agent` is a **prefix without a tag**: the Teable app launches AI
sessions with `<prefix>:<its own release tag>`, so the agent always matches
the app version. The image is **pulled at runtime** (the app preheats it
through the Infra API on startup) -- it is not installed with the platform,
so sandbox hosts need registry access. Without it (air-gapped / private
registry), mirror `teable-sandbox-agent:<the release tag of the Teable app
you run>` into your own registry first and point the prefix at it
(`SANDBOX_OPENSANDBOX_IMAGE` in `.env`, `teable.sandboxAgentImagePrefix` in
Helm) -- and mirror the matching agent tag before every app upgrade. For
this release's verified app tag the pairing resolves to
`ghcr.io/teableio/teable-sandbox-agent:release.2026-07-17T14-54-52Z.2273` (asserted available on both registries at release time).

## Verify availability without credentials

```bash
tmp="$(mktemp -d)"; printf '{}' > "$tmp/config.json"
DOCKER_CONFIG="$tmp" docker manifest inspect ghcr.io/teableio/teable:latest
```
