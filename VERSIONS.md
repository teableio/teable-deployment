# Versions

> Generated for platform release **v2026.9.3** (2026-09-04T09:28:45Z) -- do not edit
> by hand. Machine-readable copy: [`versions.yaml`](versions.yaml)
> (schema: [`schemas/versions.schema.json`](schemas/versions.schema.json)).

Everything below was verified together as one combination. Upgrade the
platform as a unit: pick a platform release, never mix component versions
across releases. What changed between releases: [`CHANGELOG.md`](CHANGELOG.md).

## Component matrix

| Component | Image | Architectures | Notes |
|---|---|---|---|
| `teable` | `ghcr.io/teableio/teable:release.2026-09-04T09-00-16Z.2928` | amd64, arm64 | Stable channel (:latest) resolved to its release tag at generation time |
| `teable-sandbox-agent` | `ghcr.io/teableio/teable-sandbox-agent` | - | Prefix only, no tag: at runtime the app pulls `<prefix>:<its own release tag>`, so sandbox hosts need registry access |
| `teable-app-runtime` | `ghcr.io/teableio/teable-app-runtime:20260717T042653Z` | amd64, arm64 |  |
| `teable-infra-service` | `ghcr.io/teableio/teable-infra-service:20260824T111338Z` | amd64, arm64 |  |
| `opensandbox-server` | `ghcr.io/teableio/opensandbox-server:v0.2.0-fix9` | amd64, arm64 | Patched build: adds the /v1 mount-prefix fix for proxied sandbox endpoints (path-proxy mode needs >= fix5), docker-runtime sandbox_env/sandbox_binds for private-CA trust (>= fix6), the container-level securityContext backfill plus shared-volume subPath pre-creation that unprivileged sandboxes need (>= fix7), docker-runtime workspace-directory ownership pre-creation (>= fix8), and setgid/sticky bits accepted in the subPath pre-creation dir_mode (>= fix9) |
| `opensandbox-ingress` | `ghcr.io/teableio/opensandbox-ingress:v1.0.7` | amd64, arm64 |  |
| `opensandbox-controller` | `ghcr.io/teableio/opensandbox-controller:v0.2.0` | amd64, arm64 |  |
| `opensandbox-image-committer` | `ghcr.io/teableio/opensandbox-image-committer:v0.1.0` | amd64, arm64 | Also used as the hold container of the app-triggered agent-image preheat DaemonSet (created by infra-service at runtime). |
| `opensandbox-execd` | `ghcr.io/teableio/opensandbox-execd:v1.0.19-fix3` | amd64, arm64 | Patched build: upstream v1.0.19 (the execd release matching server v0.2.0), the issue #1064 fix (owner/group on auto-created parent directories) and, from fix3, the credential handling an unprivileged sandbox needs (an older execd fails every command with `operation not permitted`) |
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
| Verified against | `release.2026-09-04T09-00-16Z.2928` |

Older app releases cannot use this runtime's path-proxy sandbox mode; upgrade
the app first (its data is untouched by app image upgrades).

## Upgrading to this release

This release is **hot-swappable from the platform release immediately
before it**: coming from that release, updated images are the whole
upgrade -- no data migration required. Coming from an older release, first
check [Upgrading across releases](#upgrading-across-releases) below.
Upgrade from this repository **checked out at the release tag** (sidecar
pins are embedded in the compose/chart sources, not only in image
references):

- **Docker**: re-run `./apply.sh <mode> [--with-app]` (it re-renders the
  engine config, whose sandbox sidecar pins change between releases), then
  `docker compose pull && docker compose up -d`.
- **Kubernetes**: `helm upgrade` with the chart from this checkout, applying
  `helm/examples/images.values.yaml` (see its header).

### Upgrading across releases

No migration has ever been required on this release line: upgrading from
**any** older platform release follows the same image-swap steps as above.

## What "verified" means

- **Docker all-in-one** (2026-07-15): clean-machine install, full
  journey -- app, sandbox build, app deployment, preview, and the three
  storage planes.
- **Kubernetes (Helm)** (2026-07-15): bare `helm install` with
  only `global.baseDomain` set, full stack up, sandbox create/preview/delete
  loop, plus a backup/restore drill (2026-07-14).
