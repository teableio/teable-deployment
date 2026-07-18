# Changelog

User-visible changes, grouped by platform release (component pins for each
release live in [`VERSIONS.md`](VERSIONS.md)). Each entry says what changed
and what you must do — most entries need no action.

## v2026.7.8 - 2026-07-18

### Changed

- **Teable stable channel promoted**: `ghcr.io/teableio/teable:latest` now resolves to `release.2026-07-17T14-54-52Z.2273`. Docker installs already follow `latest`; Kubernetes installs pick the refreshed pin up via this release's `versions.yaml`. No action needed; hot-swappable.

## v2026.7.7 - 2026-07-17

### Changed

- **Teable stable channel promoted**: `ghcr.io/teableio/teable:latest` now resolves to `release.2026-07-17T08-32-22Z.2269`. Docker installs already follow `latest`; Kubernetes installs pick the refreshed pin up via this release's `versions.yaml`. No action needed; hot-swappable.

## v2026.7.6 - 2026-07-17

### Changed

- **App Deployments now run non-root with a restricted-compliant security
  context**: generated pods set `runAsNonRoot` / `runAsUser: 1001` / seccomp
  `RuntimeDefault`, containers drop all capabilities and forbid privilege
  escalation, the app-runtime image itself runs as UID 1001, and apps unpack
  into `/tmp/app` so redeploys pinned to older runtime images keep working on
  clusters that enforce PodSecurity/Kyverno `restricted`. Override or disable
  via `infraService.appRuntime.podSecurityContext` / `containerSecurityContext`
  / `appDir` (Helm) or the matching `APP_RUNTIME_*` envs (`{}` disables).
  No action needed.
- **Teable stable channel promoted**: `ghcr.io/teableio/teable:latest` now resolves to `release.2026-07-17T03-42-04Z.2260`. Docker installs already follow `latest`; Kubernetes installs pick the refreshed pin up via this release's `versions.yaml`. No action needed; hot-swappable.

## v2026.7.5 - 2026-07-16

### Changed

- **Teable stable** is now `release.2026-07-16T10-16-45Z.2254`. No action needed.
- **App Runtime default image** pinned to `20260716T154009Z`. No action needed.

- **App Runtime removes legacy Knative migration behavior**: generated apps continue
  to use native Kubernetes resources. Before upgrading from Knative, delete its
  remaining app resources and conflicting `ExternalName` Services; fresh installs need no action.

## v2026.7.4 - 2026-07-16

### Added

- **Infra Service capability handshake (`GET /api/meta`)**: the Infra Service
  now reports its build version, the OpenSandbox engine version, and
  append-only capability tokens (for example `opensandbox.v1`,
  `image-preheat.v1`, `app-runtime.gateway.v1`). Newer Teable app releases
  call this once at boot to surface infra/app compatibility in the admin
  sandbox settings and to gate the admin live test; older apps never call it,
  and an older Infra Service answering 404 is reported by the app as "infra
  too old to report capabilities", not as an outage. Compose deployments gain
  an optional `OPENSANDBOX_SERVER_IMAGE` pass-through on the Infra Service so
  `/api/meta` can report the engine version from the same tag the server
  container runs. No action needed; hot-swappable.

### Changed

- **Migration guide: the Vercel sandbox provider is hard-removed, and the
  upgrade order matters**: as of Teable `release.2026-07-01T11-07-52Z.2082`
  the Vercel sandbox provider code is gone from the app, and a leftover
  `SANDBOX_PROVIDER=vercel` makes the app container fail at boot with
  `Unknown sandbox provider type: vercel`. The migration guide now leads with
  this warning (change the environment first, then upgrade the image), notes
  that sandbox snapshots were removed in the same release (historical AI
  session workspaces migrate automatically), and adds the boot failure to the
  troubleshooting table. Action needed only if you still have
  `SANDBOX_PROVIDER=vercel` set: switch it to `opensandbox` (or remove it)
  before upgrading past that release.

## v2026.7.3 - 2026-07-15

### Added

- **Custom labels/annotations on generated app Deployments**: set
  `infraService.appRuntime.workloadLabels` / `workloadAnnotations` when your
  cluster's admission policies require specific workload metadata. Empty by
  default; no action needed.

## v2026.7.2 - 2026-07-15

### Changed

- **Kubernetes install re-verified end to end** on a clean cluster with a
  real domain. No action needed.
- **Quick start installs without `--wait`**: `helm install --wait` deadlocks
  on a first install. Install plainly and let the doctor confirm readiness;
  TROUBLESHOOTING covers recovering an already-stuck `--wait` install.

## v2026.7.1 - 2026-07-15

### Changed

- **Docker install re-verified end to end** on a clean VM with a real domain.
  No action needed.
- **Troubleshooting additions**: doctor showing `000` on the deployment VM
  itself (hosts-file workaround), and why S3 admin clients cannot connect
  through the entry (object paths only, by design).

## v2026.7.0 - 2026-07-15

First platform release — everything below ships as one verified combination.

### Added

- **Release manifest**: `versions.yaml` / `VERSIONS.md` pin every component;
  `images/README.md` covers mirrors and air-gapped installs.
- **Doctor release check**: compares what is running against `versions.yaml`
  and tells you whether the combination is verified.
- **Private CA for sandboxes**: Kubernetes via `helm/private-ca.md`; Docker
  via `SANDBOX_CA_CERT_FILE` / `SANDBOX_TLS_NO_VERIFY` in `.env`.
- **Automatic releases**: every release is tagged automatically and gets a
  GitHub Release with the matching changelog section.

### Changed

- **Docker mode `cloud` renamed to `server`** (it means "a server with a real
  domain", intranet included). If you deployed under the old name, re-run
  `./apply.sh server` once; data is untouched.
- **Sandbox engine `v0.2.0-fix6` and execd `v1.0.19-fix2`**: private-CA
  support plus an upstream permissions fix. `.env` now pins full image
  references (`EXECD_IMAGE` / `EGRESS_IMAGE`); the old `OPENSANDBOX_REGISTRY`
  variable is retired and ignored.
- **All defaults pinned**: engine images default to `ghcr.io/teableio/*`
  (China: swap the prefix for the Shenzhen mirror, same tags), MinIO is
  pinned instead of `:latest`, and bare Kubernetes installs ship a pinned
  `appRuntime.defaultImage` so app deploys work out of the box.
