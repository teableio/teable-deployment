# Versions

> Transitional matrix, maintained by hand until the first formal Platform
> Release (which will ship generated locks, digests and migration metadata).
> Everything below is the combination actually verified together.

## Current verified combination (2026-07-14)

| Component | Image | Notes |
|---|---|---|
| Teable app | `ghcr.io/teableio/teable:latest` | Docker deployments track `latest`; pin with `pin-image.sh` for production |
| Infra Service / Git Registry | `ghcr.io/teableio/teable-infra-service:latest` | one image serves both |
| Sandbox engine (server) | `ghcr.io/teableio/opensandbox-server:v0.2.0-fix5` | includes the `/v1` proxy-endpoint fix (path-proxy mode needs >= fix5) |
| Sandbox execd | `opensandbox/execd:v1.0.18` (engine-injected) | pulled from the public distribution registry |
| Sandbox egress | `opensandbox/egress:v1.0.12` (engine-injected) | pulled from the public distribution registry |
| Sandbox agent | paired by the Teable app | prefix only: the app appends its own release tag and preheats it |
| App runtime base | `ghcr.io/teableio/teable-app-runtime:latest` | |
| PostgreSQL / Redis / MinIO | `postgres:15.4` / `redis:7.2.4` / see values example | MinIO: pin the release noted in `helm/examples/values.example.yaml` |
| Helm charts | `teable-infra` 0.1.0 (+ bundled sub-charts) | |

China deployments: replace `ghcr.io/teableio/` with
`registry.cn-shenzhen.aliyuncs.com/teable/` — every image above is mirrored
there with identical tags.

## What "verified" means here

- **Docker all-in-one**: clean-machine install, full journey (app + sandbox
  build + app deployment + preview + the three storage planes) on 2026-07-13.
- **Kubernetes (Helm)**: bare `helm install` with only `global.baseDomain` set,
  full stack up, sandbox create/preview/delete loop, backup/restore drill on
  2026-07-14.

Upgrades between transitional versions carry no migration guarantees yet;
back up before upgrading (`docker/all-in-one/README.md` and
`helm/examples/values.example.yaml` list what to back up).
