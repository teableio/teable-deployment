# Changelog

User-visible changes, grouped by platform release (component pins for each
release live in [`VERSIONS.md`](VERSIONS.md)). Each entry says what changed
and what you must do — most entries need no action.

"Teable `release.*`" sections record the app releases picked up by the stable
channel, with their release notes synced in. Docker installs follow `latest`
directly; Kubernetes installs receive the refreshed pin via that platform
release's `versions.yaml`. Hot-swappable; no action needed.

## v2026.7.11 - 2026-07-21

### Teable release.2026-07-20T06-51-40Z.2282

- Improved table search performance for large, high-traffic datasets, with stronger validation and safeguards for more reliable search behavior.
- Added admin controls, status visibility, and field-level usage analysis to help evaluate, enable, and manage table search optimization.
- Added bring-your-own-database (BYODB) health triage to help teams assess database-related issues more quickly and consistently.
- Added a dedicated BYODB admin page for viewing connection summaries, creating new BYODB spaces, and binding existing spaces.
- Improved BYODB migration accuracy and reliability by eliminating misleading catch-up progress and reducing write-freeze time during busy migrations.
- Improved automation email polling reliability by recovering from idle mailbox connection failures and safely discarding outdated polling results.
- Improved admin failure monitoring by grouping repeated anomalies by root cause, surfacing recent failed jobs, and providing clearer, privacy-conscious error diagnostics.
- Improved analytics attribution for signed-out, newly registered, logged-out, and returning users to prevent activity from being associated with the wrong user.
- Expanded analytics coverage for App Builder chat starts and space activity, including app and base creation, views, workflows, shares, invitations, and invitation acceptance.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-20T06-51-40Z.2282)

### Teable release.2026-07-21T00-26-02Z.2300

- Airtable imports from chat now provide clearer visible feedback by navigating to the imported table in the current base and returning links for imports into other bases.
- Improved Airtable migration reliability so stalled attachment transfers, expired downloads, interrupted API responses, and slow-but-active record reads fail or retry safely instead of leaving imports hanging.
- Personal access tokens can now use Airtable import endpoints when the target permissions and required integration scopes are valid.

- Fixed an issue where users could see “Failed to create user record” on their first OAuth sign-in to generated apps with domain or open login enabled.
- Improved the app login flow so new users are created through the app API path consistently, while existing app-token write behavior remains unaffected.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-21T00-26-02Z.2300)

## v2026.7.10 - 2026-07-20

### Changed

- **DB Pool instances can now carry a human-readable space name**: set it in
  the create dialog or via the new "set name" action on the instance detail
  page. The name shows in the instance list/detail and is propagated as a
  sanitized `teable.io/space-name` pod label, so monitoring dashboards can
  label series by space instead of the derived `dbt-*` id. Tenant Postgres
  pods also expose the CNPG metrics exporter (port 9187) via
  `prometheus.io/scrape` annotations, adding direct-connection backend counts
  to the metrics stack. Existing instances pick up the label and annotations
  in place, without a restart. No action needed.

## v2026.7.9 - 2026-07-19

### Teable release.2026-07-18T09-45-26Z.2275

- Added a visible calculation activity status for computed fields, including formulas, lookups, and rollups, so users can more clearly see when table values are still being calculated.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-18T09-45-26Z.2275)

## v2026.7.8 - 2026-07-18

### Teable release.2026-07-17T14-54-52Z.2273

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-07-17T14-54-52Z.2273`.

## v2026.7.7 - 2026-07-17

### Teable release.2026-07-17T08-32-22Z.2269

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-07-17T08-32-22Z.2269`.

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

### Teable release.2026-07-17T03-42-04Z.2260

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-07-17T03-42-04Z.2260`.

### Teable release.2026-07-17T05-20-38Z.2264

#### Fixes & Improvements

* **Fixed select option editing**: Clicking existing **Single select** or **Multiple select** options now opens the dropdown reliably.

* **Improved formula field stability**: Fixed failures in nested **Lookup** and **IF** formulas with certain numeric results.

* **Improved many-to-many link stability**: Fixed reverse link fields not updating promptly after large-scale background update failures.

* **Improved high-volume link field handling**: High-cardinality Link fields now calculate and display more reliably.

* **Improved formula and lookup update speed**: Multi-stage linked record updates now refresh calculations and cascades faster.

* **Improved calculation task stability**: Paused calculation tasks are no longer repeatedly awakened, reducing invalid scheduling.

* **Fixed table recycle bin menu issues**: Recycled tables now only show relevant actions like restore and delete.

* **Fixed deleted table restoration issues**: Restoring a table now only restores fields and views from that deletion.

* **Improved AI response performance**: AI Proxy SSE and streaming responses now reduce unnecessary caching and parsing.

* **Improved high-frequency background paths**: Settings reads, tracking, data cleanup, and session lookups are now lighter.

* **Enhanced session file matching checks**: Session file lookups now use stricter ID validation to reduce mismatches.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-17T05-20-38Z.2264)

## v2026.7.5 - 2026-07-16

### Changed

- **App Runtime default image** pinned to `20260716T154009Z`. No action needed.
- **App Runtime removes legacy Knative migration behavior**: generated apps continue
  to use native Kubernetes resources. Before upgrading from Knative, delete its
  remaining app resources and conflicting `ExternalName` Services; fresh installs need no action.

### Teable release.2026-07-16T10-16-45Z.2254

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-07-16T10-16-45Z.2254`.

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
