# Changelog

User-visible changes to this deployment, grouped by platform release
(see [`VERSIONS.md`](VERSIONS.md) for what each release pins). Entries say
what changed and what, if anything, you must do.

## v2026.7.0 - Unreleased

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
