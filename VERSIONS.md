# Versions

> Generated for platform release **v2026.7.11** (2026-07-21T03:40:05Z) -- do not edit
> by hand. Machine-readable copy: [`versions.yaml`](versions.yaml)
> (schema: [`schemas/versions.schema.json`](schemas/versions.schema.json)).

Everything below was verified together as one combination. Upgrade the
platform as a unit: pick a platform release, never mix component versions
across releases. What changed between releases: [`CHANGELOG.md`](CHANGELOG.md).

## Component matrix

| Component | Image | Architectures | Notes |
|---|---|---|---|
| `teable` | `ghcr.io/teableio/teable:release.2026-07-21T00-26-02Z.2300` | amd64, arm64 | Stable channel (:latest) resolved to its release tag at generation time |
| `teable-sandbox-agent` | `ghcr.io/teableio/teable-sandbox-agent` | - | Prefix only, no tag: at runtime the app pulls `<prefix>:<its own release tag>`, so sandbox hosts need registry access |
| `teable-app-runtime` | `ghcr.io/teableio/teable-app-runtime:20260717T042653Z` | amd64, arm64 |  |
| `teable-infra-service` | `ghcr.io/teableio/teable-infra-service:20260717T042653Z` | amd64, arm64 |  |
| `opensandbox-server` | `ghcr.io/teableio/opensandbox-server:v0.2.0-fix6` | amd64, arm64 | Patched build: adds the /v1 mount-prefix fix for proxied sandbox endpoints (path-proxy mode needs >= fix5) and docker-runtime sandbox_env/sandbox_binds for private-CA trust (>= fix6) |
| `opensandbox-ingress` | `ghcr.io/teableio/opensandbox-ingress:v1.0.7` | amd64, arm64 |  |
| `opensandbox-controller` | `ghcr.io/teableio/opensandbox-controller:v0.2.0` | amd64, arm64 |  |
| `opensandbox-image-committer` | `ghcr.io/teableio/opensandbox-image-committer:v0.1.0` | amd64, arm64 | Also runs the node image-preheater DaemonSet. |
| `opensandbox-execd` | `ghcr.io/teableio/opensandbox-execd:v1.0.19-fix2` | amd64, arm64 | Patched build: upstream v1.0.19 (the execd release matching server v0.2.0) plus the issue #1064 fix (owner/group on auto-created parent directories) |
| `opensandbox-egress` | `ghcr.io/teableio/opensandbox-egress:v1.0.12` | amd64, arm64 | Per-sandbox egress sidecar, started by the server on demand. |
| `postgres` | `postgres:15.4` | amd64, arm64 |  |
| `redis` | `redis:7.2.4` | amd64, arm64 |  |
| `minio` | `minio/minio:RELEASE.2025-04-22T22-12-26Z` | amd64, arm64 | Pinned by the Docker defaults and the Kubernetes values example |
| `minio-mc` | `minio/mc:RELEASE.2025-04-16T18-13-26Z` | amd64, arm64 | Bucket-provisioning sidecar for MinIO |

Digests for every reference are in [`versions.yaml`](versions.yaml).

## Channels and pinning

- **Teable app**: `:latest` is the stable channel and resolved to the release
  tag above at release time; `:beta` is the rolling channel. Docker
  deployments default to `:latest` and just work; for production, pin with
  `docker/all-in-one/pin-image.sh` (Kubernetes: paste the resolved tag into
  your values).
- **Sandbox engine components** (server, ingress, controller,
  image-committer, execd, egress) ship pinned everywhere at exactly the
  versions above.
- **Infra Service and the app runtime base** are pinned by the Helm chart;
  the Docker path follows `:latest` (their stable channel), which resolved
  to the versions above at release time.
- **PostgreSQL / Redis / MinIO** ship pinned in the Docker defaults and the
  Kubernetes values example (the bare chart default for MinIO floats -- pin
  it in your values, see `helm/examples/values.example.yaml`).

## China mirror

Replace `ghcr.io/teableio/` with `registry.cn-shenzhen.aliyuncs.com/teable/` -- every
first-party image is mirrored there with identical tags. Details and offline
/ private-registry workflows: [`images/README.md`](images/README.md).

## Teable app compatibility

| | Release tag |
|---|---|
| Minimum supported | `release.2026-07-14T12-24-39Z.2228` |
| Verified against | `release.2026-07-21T00-26-02Z.2300` |

Older app releases cannot use this runtime's path-proxy sandbox mode; upgrade
the app first (its data is untouched by app image upgrades).

## Upgrading to this release

This release is **hot-swappable** from the previous platform release -- no
data migration required. Upgrade from this repository **checked out at the
release tag** (sidecar pins are embedded in the compose/chart sources, not
only in image references):

- **Docker**: re-run `./apply.sh <mode> [--with-app]` (it re-renders the
  engine config, whose sandbox sidecar pins change between releases), then
  `docker compose pull && docker compose up -d`.
- **Kubernetes**: `helm upgrade` with the chart from this checkout, applying
  `helm/examples/images.values.yaml` (see its header).

## What "verified" means

- **Docker all-in-one** (2026-07-15): clean-machine install, full
  journey -- app, sandbox build, app deployment, preview, and the three
  storage planes.
- **Kubernetes (Helm)** (2026-07-15): bare `helm install` with
  only `global.baseDomain` set, full stack up, sandbox create/preview/delete
  loop, plus a backup/restore drill (2026-07-14).
