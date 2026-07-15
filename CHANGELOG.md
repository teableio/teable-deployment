# Changelog

User-visible changes to this deployment, grouped by platform release
(see [`VERSIONS.md`](VERSIONS.md) for what each release pins). Entries say
what changed and what, if anything, you must do.

## Unreleased

### Added

- **Extra workload metadata for generated app Deployments**: new Helm values
  `infraService.appRuntime.workloadLabels` / `workloadAnnotations` (env
  `APP_RUNTIME_WORKLOAD_LABELS` / `APP_RUNTIME_WORKLOAD_ANNOTATIONS`) stamp
  additional labels/annotations on every app Deployment the Infra Service
  creates, on both the Deployment and its Pod template metadata. Use this when
  a cluster admission policy requires specific workload metadata (for example
  policies mandating `app`/`app-component`/`application` labels). Internal
  `teable.ai/*` and `app.kubernetes.io/name` keys are reserved; invalid JSON,
  invalid key names, or invalid label values fail configuration loading
  immediately (deploys fail loudly) instead of being silently ignored. The
  immutable `spec.selector` is never touched; existing app Deployments pick
  the metadata up on their next deploy, and keys you later remove from the
  values are also removed from the workload on its next deploy. No action
  needed if you leave the new values empty.

## v2026.7.2 - 2026-07-15

### Changed

- **Kubernetes verification refreshed (2026-07-15)**: real-domain bare install
  (only `global.baseDomain` set) on a clean cluster from the `v2026.7.0` tag --
  DNS-01 certificates, `/git` path routing, presigned upload/download over the
  bucket-path ingress, sandbox chain with `*.sandbox` wildcard previews, and
  the doctor release check live against the shipped `versions.yaml`.
  No action needed; hot-swappable.
- **Quick start no longer uses `helm install --wait`**: Helm runs post-install
  hooks only after `--wait` returns, while Teable cannot become ready without
  the buckets that hook creates -- on a first install `--wait` deadlocks until
  the timeout. Install plainly and let the doctor confirm readiness; a
  troubleshooting entry covers recovering an already-failed `--wait` install
  (replay the hooks, then clean them up).

## v2026.7.1 - 2026-07-15

### Changed

- **Docker verification refreshed (2026-07-15)**: full real-domain,
  server-mode verification on a clean VM deployed from the `v2026.7.0` tag --
  DNS-01 wildcard certificates, `/git` path routing, presigned upload/download
  over the entry bucket paths, `*.sandbox` wildcard previews, and the engine
  `v0.2.0-fix6` + execd `v1.0.19-fix2` sandbox chain. `versions.yaml` carries
  the new verification date. No action needed; hot-swappable.
- **Troubleshooting additions**: doctor entry checks returning `000` when run
  on a cloud VM itself (no hairpin NAT to the machine's own public IP, with
  the `/etc/hosts` workaround), and why S3 management clients cannot connect
  through the entry (object paths only -- by design).

## v2026.7.0 - 2026-07-15

The first platform release: everything below ships together as one verified
combination.

### Added

- **Platform release manifest**: `versions.yaml` (machine-readable, schema in
  `schemas/`) and a generated `VERSIONS.md` pin every component of a release;
  `images/README.md` carries the mirror and air-gapped workflows.
- **Doctor release check**: both doctors compare what is actually running
  against `versions.yaml` and report one of three states -- compatible,
  upgrade the Teable app, or an unknown (unverified) combination.
- **Private CA support for sandboxes**: `helm/private-ca.md` documents the
  Kubernetes template override; on Docker, `SANDBOX_CA_CERT_FILE` /
  `SANDBOX_TLS_NO_VERIFY` in `.env` wire the sandbox engine's new
  `sandbox_env` / `sandbox_binds` settings (engine `v0.2.0-fix6`).
- **Automatic releases**: platform releases are tagged automatically as
  user-visible changes land, and every tag gets a GitHub Release whose notes
  are the matching section of this changelog.

### Changed

- **Docker mode renamed: `cloud` is now `server`** -- the mode means "a server
  with a real domain" (intranet servers included), not public cloud. File
  names follow (`compose.server.yaml`, `.env.server.example`, ...). If you
  deployed before the rename: re-run `./apply.sh server` once to regenerate
  `COMPOSE_FILE`; data volumes are untouched.
- **Sandbox engine `v0.2.0-fix6`** (from fix5): adds the docker-runtime
  `sandbox_env` / `sandbox_binds` settings above. Hot-swappable.
- **execd `v1.0.19-fix2` on the Docker path** (was upstream `v1.0.18`): picks
  up the upstream fix for owner/group on auto-created parent directories and
  matches the engine version pairing. `.env` now pins full references
  (`EXECD_IMAGE` / `EGRESS_IMAGE`, written back by `apply.sh`); the old
  `OPENSANDBOX_REGISTRY` prefix variable is retired -- `apply.sh` warns and
  ignores it, the pinned defaults take over.
- **Docker defaults pin MinIO** to the platform release (was `:latest`), same
  pins as the Kubernetes values example -- air-gapped mirrors of the image
  list now cover a default install exactly.
- **Engine images default to `ghcr.io/teableio/*`** everywhere (China: swap
  the prefix for the Shenzhen mirror, identical tags).
- **Kubernetes bare installs can deploy apps out of the box**:
  `infraService.appRuntime.defaultImage` now ships pinned instead of blank.
