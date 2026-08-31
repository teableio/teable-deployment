# Changelog

User-visible changes, grouped by platform release (component pins for each
release live in [`VERSIONS.md`](VERSIONS.md)). Each entry says what changed
and what you must do — most entries need no action.

"Teable `release.*`" sections record the app releases picked up by the stable
channel, with their release notes synced in. Docker installs follow `latest`
directly; Kubernetes installs receive the refreshed pin via that platform
release's `versions.yaml`. Hot-swappable; no action needed.

## Unreleased

### Teable release.2026-08-31T02-56-18Z.2853

#### Feature Updates

- Added full Hebrew UI support in the Community and Enterprise editions, covering language selection, locale detection, preferences, calendars, announcements, static pages, and the SDK.
- Added search optimization analysis for administrators, providing one actionable recommendation for broad substring searches while identifying existing search paths and avoiding duplicate recommendations.

#### Bug Fixes & Improvements

- Improved right-to-left rendering in Arabic and Hebrew interfaces, including direction icons, editable fields, panels, forms, menus, selectors, gradients, and keyboard navigation.
- Added missing Arabic translations that previously appeared in English on relevant pages and controls.
- Updated text input in Arabic and Hebrew interfaces to follow the interface direction while preserving automatic direction detection for displayed content, improving the mixed-language editing experience.
- Improved the mobile layout of the self-hosted license page, making credentials easier to view and manage on smaller screens.
- Improved relationship graph accuracy by displaying only relevant relationships and preventing unrelated parent trees from appearing in the admin view.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-31T02-56-18Z.2853)

## v2026.8.51 - 2026-08-28

### Teable release.2026-08-28T05-16-40Z.2847

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-28T05-16-40Z.2847`.

## v2026.8.50 - 2026-08-28

- **Added `infraService.appRuntime.scaleToZero` (teable-infra 0.9.0).** Tune or
  disable app idle scale-to-zero: `enabled`, `idleSeconds`, `intervalSeconds`.
  Blank values inherit the built-in defaults (enabled, 7 days idle, 600s scan),
  so existing installs behave exactly as before. No action needed.

## v2026.8.49 - 2026-08-28

### Teable release.2026-08-27T15-42-00Z.2838

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-27T15-42-00Z.2838`.

## v2026.8.48 - 2026-08-27

### Teable release.2026-08-27T15-17-30Z.2836

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-27T15-17-30Z.2836`.

## v2026.8.47 - 2026-08-27

### Teable release.2026-08-27T08-17-18Z.2826

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-27T08-17-18Z.2826`.

## v2026.8.46 - 2026-08-27

### Teable release.2026-08-27T05-10-16Z.2819

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-27T05-10-16Z.2819`.

## v2026.8.45 - 2026-08-27

### Teable release.2026-08-26T10-21-34Z.2809

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-26T10-21-34Z.2809`.

## v2026.8.44 - 2026-08-25

### Teable release.2026-08-25T14-19-49Z.2796

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-25T14-19-49Z.2796`.

## v2026.8.43 - 2026-08-25

### Teable release.2026-08-25T08-19-19Z.2785

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-25T08-19-19Z.2785`.

## v2026.8.42 - 2026-08-25

### Teable release.2026-08-25T05-24-44Z.2776

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-25T05-24-44Z.2776`.

## v2026.8.41 - 2026-08-21

- **Documented what AI Agent skills require.** Skills are stored as files
  through the Infra object API, so they need `infraService.s3Compat.enabled`
  plus one shared filesystem mounted by both Infra Service and the sandboxes --
  see [`helm/README.md`](helm/README.md), "AI Agent skills". No action needed.
- **Fixed `infraService.s3Compat.allowOverwrite: false` being ignored.** An
  explicit `false` still rendered as `true`, so the object endpoint kept
  overwriting existing objects. No action needed unless you set it.

### Teable release.2026-08-22T03-40-44Z.2744

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-22T03-40-44Z.2744`.

## v2026.8.40 - 2026-08-21

### Teable release.2026-08-20T14-44-47Z.2730

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-20T14-44-47Z.2730`.

## v2026.8.39 - 2026-08-20

### Teable release.2026-08-20T05-18-33Z.2723

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-20T05-18-33Z.2723`.

## v2026.8.38 - 2026-08-20

- **Added `server.sandboxNetworkPolicy.additionalAllowedPeers` (opensandbox-server 0.5.0).**
  Selector-based egress allow rules for the sandbox fence, targeting in-cluster
  platform endpoints by namespace/pod selector. Use these instead of
  `additionalAllowedCidrs` on CNIs that match egress policies against the
  post-DNAT pod IP (e.g. Alibaba Cloud Terway), where an ipBlock allow for a
  Service ClusterIP never matches. No action needed; existing values render
  the same rules. Note: repackaging the subchart also brings the
  `opensandbox-server` default-resource reduction announced in v2026.8.28 into
  the umbrella chart — the vendored subchart had drifted from its source since
  then, so installs relying on chart-default resources receive that change
  starting with this release.

## v2026.8.37 - 2026-08-19

### Teable release.2026-08-19T09-39-21Z.2715

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-19T09-39-21Z.2715`.

## v2026.8.36 - 2026-08-19

- **Git registry repositories now use far less disk.** Pushes are stored packed,
  and nightly maintenance repacks oversized repositories (thresholds tunable via
  `gitRegistry.gcLooseObjectsThreshold` / `gcLooseSizeBytes` / `gcPacksThreshold`).
  No action needed.

## v2026.8.35 - 2026-08-19

- **infra-service now logs its effective configuration at start-up.** Lines are
  prefixed `[config]` and cover sandbox lifetime, backpressure, app
  scale-to-zero, app cleanup, and metrics. This is what the process is actually
  running with, which is not always what `kubectl get configmap` shows — a
  ConfigMap edit does not reach a running pod until it restarts, and `subPath`
  mounts never update at all. Check with
  `kubectl logs deploy/<infra-service> | grep '\[config\]'`. No action needed.

## v2026.8.34 - 2026-08-19

### Teable release.2026-08-19T09-57-17Z.2716

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-19T09-57-17Z.2716`.

## v2026.8.33 - 2026-08-19

- **Fixed RRSA STS exchange failing with `MissingTimestamp`.** The
  `AssumeRoleWithOIDC` call introduced in v2026.8.31 omitted the mandatory
  `Timestamp` common parameter, so enabling `artifactOss.rrsa` always failed.
  No action needed beyond upgrading.

## v2026.8.32 - 2026-08-18

### Teable release.2026-08-18T10-54-07Z.2696

#### Feature Updates

- Improved the Space page layout on mobile so navigation remains easy to use when the top section contains more information.
- Made the desktop entry point for opening a base more prominent for quicker access.

#### Bug Fixes & Improvements

- Fixed failures when updating or converting number lookup fields with stale metadata, preventing invalid values from causing backfill errors.
- Improved lookup field schema updates and rebuilds to reduce failed operations during display-only changes.
- Improved conditional lookup and rollup processing on large tables, reducing timeouts and failed updates by using more efficient filtering and indexes.
- Fixed a crash when viewing numeric lookup columns with missing formatting settings; these fields now use the default number format.
- Updates now handle trashed referenced tables correctly by skipping affected steps while continuing with active tables.
- Fixed billing period and timezone handling so usage dialogs, charts, and history consistently show the correct cycle for paid and free plans.
- Fixed the branding link in public form footers so it opens the Teable website directly.
- Fixed add-on credit resets so allowances refresh according to their own grant cycle without duplicate grants, with the reset time shown more clearly.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-18T10-54-07Z.2696)

## v2026.8.31 - 2026-08-18

- **Keyless OSS artifact store via RRSA (Alibaba Cloud ACK).** Optional
  `infraService.appRuntime.artifactOss.rrsa` lets infra-service use temporary
  STS credentials instead of a static AccessKey Secret; requires RRSA enabled
  on the ACK cluster. Off by default; existing setups are unaffected.

## v2026.8.30 - 2026-08-18

### Teable release.2026-08-18T06-53-59Z.2682

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-18T06-53-59Z.2682`.

## v2026.8.29 - 2026-08-18

### Teable release.2026-08-18T02-59-03Z.2673

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-18T02-59-03Z.2673`.

## v2026.8.28 - 2026-08-17

- **Lower default resources for `opensandbox-server` and its ingress gateway.**
  Chart defaults were sized far above observed production usage. Server:
  requests `1 CPU / 4Gi` → `100m / 512Mi`, limits `2 CPU / 8Gi` → `1 CPU / 2Gi`.
  Gateway: requests `1 CPU / 4Gi` → `50m / 128Mi`, limits `2 CPU / 8Gi` →
  `500m / 512Mi`. Installs that set `server.resources` /
  `server.gateway.resources` explicitly are unaffected; if you relied on the
  old defaults for heavy workloads, set them explicitly in your values.

## v2026.8.27 - 2026-08-14

### Teable release.2026-08-14T12-12-01Z.2647

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-14T12-12-01Z.2647`.

## v2026.8.26 - 2026-08-14

- **npm registry mirror switch for sandboxes and app deployments.** Set
  `global.sandboxNpmRegistry` (e.g. `https://registry.npmmirror.com`) to route
  npm/pnpm installs through a mirror. Blank (the default) changes nothing.

## v2026.8.25 - 2026-08-14

### Teable release.2026-08-14T06-35-14Z.2641

#### Feature Updates

#### Bug Fixes & Improvements
- Improved update reliability for large lookup conditional groups and wide computed-field cascades, preventing server errors during high-volume record changes.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-14T06-35-14Z.2641)

## v2026.8.24 - 2026-08-14

- **Fixed the sandbox benchmark failing when `OPENSANDBOX_RUNTIME_URL` uses
  `http://`.** The runtime client always spoke HTTPS on port 443, so an
  in-cluster URL such as `http://opensandbox-server.<ns>.svc.cluster.local`
  (which serves plain HTTP on port 80) was refused. It now picks the transport
  and default port from the URL scheme. No action needed.

## v2026.8.23 - 2026-08-13

- **Sandbox memory backpressure now defaults to on.** Helm installs are
  unaffected (the chart has always set `SANDBOX_BACKPRESSURE_ENABLED`
  explicitly). Hand-managed Kubernetes deployments that never set it will start
  tainting sandbox-pool nodes under memory pressure after upgrading; set
  `SANDBOX_BACKPRESSURE_ENABLED: "false"` to keep the old behavior.
- **Backpressure warns when its node selector matches no nodes.** A mislabeled
  sandbox node pool used to make the feature a silent no-op; it now logs a
  warning and logs again on recovery. No action needed.
- **Fixed three chart numbers rendering in scientific notation**
  (`infraService.appRuntime.artifactMaxBytes`, `gitRegistry.repoSizeLimitBytes`,
  `gitRegistry.maxInputSizeBytes` — e.g. `268435456` rendered as
  `"2.68435456e+08"`). No action needed.
- **In-code defaults now match chart defaults** for
  `APP_RUNTIME_ARTIFACT_STORE_PROVIDER` (`gcs` → `s3`),
  `IMAGE_PREHEAT_NODE_SELECTOR_VALUE` (`sandbox-pool` → `linux`),
  `IMAGE_PREHEAT_HOLD_IMAGE` (now the public `ghcr.io` image), and
  `HISTORY_WINDOW_SECONDS` (`14400` → `600`). Helm installs are unaffected;
  hand-managed deployments that relied on an old in-code default should set the
  env var explicitly.

## v2026.8.22 - 2026-08-13

### Static image-preheater DaemonSet retired

The chart no longer ships the nerdctl-based `imagePreheater` DaemonSet (the
`imagePreheater.*` values are gone). The sandbox agent image is already
preheated per node by the app-triggered `opensandbox-current-image-preheat`
DaemonSet, which pulls through the kubelet and therefore also works on
non-default containerd snapshotters (e.g. ACK image acceleration/overlaybd,
where the retired DaemonSet pre-pulled into the wrong snapshotter and warmed
nothing). The small engine sidecars are pulled on first use.

Action: none — `helm upgrade` deletes the DaemonSet; leftover
`imagePreheater.*` values are ignored. To confirm agent preheat:
`kubectl -n opensandbox-system get ds opensandbox-current-image-preheat`.

## v2026.8.21 - 2026-08-12

### Teable release.2026-08-12T12-26-10Z.2619

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-12T12-26-10Z.2619`.

## v2026.8.20 - 2026-08-11

### Teable release.2026-08-11T13-42-32Z.2596

#### Feature Updates
- Published App Builder apps can now use custom favicons, page titles, and descriptions for browser tabs, page metadata, and sharing previews. Apps without a custom favicon use the new default Teable Build favicon.
- Automation Script nodes can now run for up to 180 seconds, allowing longer-running tasks to complete.
- Added an instance-wide admin setting to control whether platform-managed AI API keys are automatically provided to Apps. The setting remains enabled by default; when disabled, Apps must use their own approved AI credentials.

#### Bug Fixes & Improvements
- Grid view grouping and sorting changes now apply immediately after saving and remain consistent across view settings, the current display, and collaborator updates. Rapid consecutive changes more reliably use the latest saved configuration.
- Fixed failed AI-created tables appearing as inaccessible entries in the sidebar. Existing invalid entries are removed automatically when the sidebar next refreshes.
- Fixed self-hosted license checkout being blocked when an expired, incomplete subscription was incorrectly treated as active.
- Fixed truncated linked-record pills overflowing into adjacent Grid cells and standardized ellipses to display consistently.
- Fixed user-grouped views showing duplicate “add record” rows, restarting row numbers, or misplacing records. Collaborators are now grouped consistently across legacy and multi-user values.
- Fixed Last Modified By and Editor fields exposing internal user IDs instead of readable names. User names and fallback states are now consistent across record views, APIs, and collaborator fields.
- Improved computed-field reliability when a workspace or base is paused. Deferred updates now resume correctly when the pause expires or is ended early, reducing backlogs and performance degradation.
- Improved AI Chat recovery from temporary connection interruptions, reducing failed responses caused by unexpectedly dropped streams.
- Fixed concurrent relational updates leaving chained lookup fields stale. Multi-level lookup results now converge more reliably on the latest values.
- Restored user-field resolution and typecasting for scoped collaborators, phone numbers, and Enterprise department members. Unrelated or deleted users are now rejected, and user display data resolves more reliably.
- Improved computed-field reliability for BYODB configurations with read-only targets.
- Improved computed activity processing during high database contention, reducing the risk of cascading write slowdowns or freezes.
- Fixed Chat showing duplicate assistant rows when a response was stopped and another message was sent immediately. Live, stopped, resent, and resumed responses now maintain a consistent message state.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-11T13-42-32Z.2596)

## v2026.8.19 - 2026-08-10

### Teable release.2026-08-10T07-45-10Z.2574

#### Feature Updates
- Space collaborators are now grouped and paginated by person, with Base-level permissions, permission levels, removal actions, and Base counts shown together.
- Admins can now discard obsolete computed-task anomaly groups that can no longer be recovered.
- Base imports now support webhook-only Bases without tables.

#### Bug Fixes & Improvements
- Improved record creation stability and latency during high-concurrency workloads by optimizing space row-count calculations and refreshes. Unlinked physical tables are no longer included in space row quotas.
- Fixed stale computed-task errors and inaccurate Admin attention counts after Bases or tables are permanently deleted or moved between data stores.
- Prevented record writes from freezing during heavy database contention by limiting waits and allowing nonessential activity updates to be reconciled later.
- Improved lookup and cascading update performance, especially for multi-level lookup and foreign-link chains.
- Improved BYODB connection security. Configurations using private or internal network database addresses may now fail validation.
- Improved Base import and export reliability by preserving field descriptions and AI configuration after re-import.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-10T07-45-10Z.2574)

## v2026.8.18 - 2026-08-09

### Teable release.2026-08-09T14-50-08Z.2564

#### Feature Updates
- Added clearer BYODB health statuses, in-app notifications, admin indicators, and remediation guidance for read-only, unreachable, degraded, and recovered databases.

#### Bug Fixes & Improvements
- BYODB-backed writes now return a 409 conflict when the database is read-only, while computed tasks pause to prevent repeated failures and resume after recovery.
- Improved BYODB health consistency and recovery detection across connection checks and write failures.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-09T14-50-08Z.2564)

## v2026.8.17 - 2026-08-09

### Teable release.2026-08-09T13-07-40Z.2563

#### Feature Updates
- Improved the Admin Outbox anomaly page by consolidating repeated database errors with changing details, making bulk recovery from incidents such as full disks more practical while preserving compatibility with existing recovery requests.

#### Bug Fixes & Improvements
- Improved handling of read-only databases to prevent repeated retry cycles and report failed operations more clearly.
- Fixed computed field updates for imported or migrated bases containing legacy record IDs, without changing ID generation or link resolution for new records.
- Improved performance for record operations that use ID-based mapping.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-09T13-07-40Z.2563)

## v2026.8.16 - 2026-08-09

### Teable release.2026-08-09T10-14-07Z.2559

#### Feature Updates

#### Bug Fixes & Improvements
- Fixed inaccurate failed-task counts in the admin Outbox when underlying tasks no longer exist, while preserving actual failure history.
- Improved field creation, duplication, and deletion safety to prevent rare naming conflicts from disrupting computed updates or affecting active fields.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-09T10-14-07Z.2559)

## v2026.8.15 - 2026-08-09

### Teable release.2026-08-09T08-35-12Z.2557

#### Feature Updates
- BYODB database settings now show connection details, status, and capabilities as read-only information, preventing space users from making unintended configuration changes.

#### Bug Fixes & Improvements
- Improved computed-field reliability after permanent table deletion by removing obsolete pending work and avoiding repeated failures. Soft-deleted tables retain pending updates for replay after restoration.
- Improved computed lookup backfills for large tables with resumable batch processing, reducing timeouts and allowing interrupted updates to continue without restarting.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-09T08-35-12Z.2557)

## v2026.8.14 - 2026-08-09

### Teable release.2026-08-09T04-03-28Z.2554

#### Feature Updates

#### Bug Fixes & Improvements
- Improved computed field reliability for self-linked tables and deleted source fields. Rollups and lookups now update correctly or return empty values instead of failing.
- AI field model or prompt changes now save directly when they do not trigger reruns.
- Field change confirmations now appear only when conversions rewrite data or affect links, with more accurate checks for rating limits and computed field errors.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-09T04-03-28Z.2554)

## v2026.8.13 - 2026-08-09

### Teable release.2026-08-08T14-46-52Z.2550

#### Feature Updates

#### Bug Fixes & Improvements

- Improved computed and lookup field update performance across both small and high-fanout changes while preserving protective batching for large workloads.
- Improved computed field processing reliability during database contention and prevented unnecessary retries for unrecoverable failures.
- Improved responsiveness for record reads, creation, and deletion, especially for large tables and bulk operations.
- Fixed deleted record snapshots not being saved correctly during bulk deletions with BYODB schemas.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-08T14-46-52Z.2550)

## v2026.8.12 - 2026-08-08

### Teable release.2026-08-08T09-33-10Z.2547

#### Feature Updates

#### Bug Fixes & Improvements
- Fixed table filter errors that could prevent filters from being saved or applied, particularly in new or previously unfiltered views.
- Improved the admin outbox queue browser to return more complete and reliable results when reviewing failed items or using server-side search.
- Improved handling of unrecoverable computed field refresh failures, reducing unnecessary retries and making failures available for diagnosis sooner.
- Fixed long text field edits, including Markdown display changes, incorrectly triggering a batch confirmation dialog when no AI run was started.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-08T09-33-10Z.2547)

## v2026.8.11 - 2026-08-08

### Teable release.2026-08-08T06-34-24Z.2542

#### Feature Updates

- The queue browser now defaults to a task-level view, while retaining access to raw delivery history.
- Recovered delivery failures are hidden by default, with a count and toggle for viewing troubleshooting details.
- Queue status filters and outcome badges now provide clearer labels, behavior, and explanations.

#### Bug Fixes & Improvements

- Fixed Conditional Rollup editor crashes when using minimum or maximum calculations on date fields after a hard refresh.
- Improved Conditional Rollup loading and formatting handling to keep the editor stable when linked fields are still loading or saved settings do not match.
- Improved cleanup reliability for orphaned linked fields and missing database objects, preventing failed deletions and inconsistent metadata.
- User-configured SMTP failures now return clearer upstream delivery errors and preserve provider rejection details instead of appearing as generic server errors.
- Prevented generation runs from becoming stuck when their associated base is missing or deleted.
- Fixed shared form cover, logo, and plugin logo images failing to load when their URLs were already absolute.
- Improved the mobile login layout to respect device safe areas and keep the login/register switch visible and accessible.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-08T06-34-24Z.2542)

## v2026.8.10 - 2026-08-07

### Teable release.2026-08-07T08-07-22Z.2536

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-07T08-07-22Z.2536`.

## v2026.8.9 - 2026-08-07

### Teable release.2026-08-07T05-00-09Z.2531

#### Feature Updates
- Generated Teable Build and App Builder apps can now customize the favicon, browser title, and page description used across tabs, page metadata, and link previews. Favicon uploads are limited to 5 MB, and apps without a custom favicon use the new Teable default.

#### Bug Fixes & Improvements
- Improved read performance for large tables with ordered, grouped, searched, or paginated views while preserving correct pagination.
- Improved compatibility with legacy column metadata so affected views open reliably without manual cleanup.
- Fixed failures when creating number fields and ensured newly created fields appear correctly in grid views with incomplete metadata.
- Admin tabs and settings now consistently reflect edition-based availability. Some commercial-only areas previously accessible without a valid license may now be restricted.
- Fixed admin pages remaining stuck in a loading state when instance usage information could not be loaded.
- Fixed an erroneous notification when opening filtered views on tables containing lookup-of-link fields.
- Improved automation reliability when explicit record updates cause dependent lookup, rollup, or linked-record values to change. Watch-all automations continue to exclude updates affecting only computed host fields.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-07T05-00-09Z.2531)

## v2026.8.8 - 2026-08-06

### Teable release.2026-08-06T02-02-38Z.2503

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-06T02-02-38Z.2503`.

## v2026.8.7 - 2026-08-05

### Teable release.2026-08-05T11-23-43Z.2499

#### Feature Updates

- Added targeted in-app announcements that admins can schedule, localize, withdraw, and display as banners, toasts, modals, or sidebar cards.
- Added read-only record snapshots to the recycle bin, with filters for resource type, operator, deletion time, creator, and creation time.
- Added Business-tier record archiving with browsing, restore, permanent deletion, CSV export, and longer-term retention.
- Published apps now have a more visible quick-open link, clearer unpublished-change indicators, and improved version history and rollback behavior.
- Added an admin maintenance check for finding and repairing users without avatars, with bulk repair and progress feedback.
- Enabled WebSocket compression for realtime grid loads and record updates, reducing bandwidth usage and improving responsiveness on slower networks.
- Removed outdated in-app pricing and FAQ content in favor of the current official pricing page.

#### Bug Fixes & Improvements

- Fixed table view filter errors, including failures when deleting the last filter, clearing filters, or opening views with incomplete date filter settings.
- Filter additions and changes now appear immediately in toolbar summaries and synchronize more reliably across connected clients.
- Stopping an AI generation is now handled as a graceful interruption across chat, app builder, and agent flows without showing server errors in other open windows.
- Improved generation checkpoint reliability under heavy database load.
- Improved computed-field processing for large and highly connected tables by splitting recalculation work into smaller stages, reducing stalled writes, memory pressure, and 503 errors.
- Fixed computed-field dependency and propagation issues affecting conditional comparisons, linked records, lookups, rollups, circular dependencies, and partial recalculation batches.
- Improved lookup propagation latency for bounded single-record updates.
- Fixed conditional rollup analysis that could trigger excessive recomputation on complex dependency graphs.
- Fixed schema updates that could become stuck when changing field types on tables with computed fields.
- Standardized database time handling around UTC to prevent timestamp drift in scheduled tasks, metadata updates, and other database-driven workflows on non-UTC deployments.
- Fixed AI creation workflows that could place generated nodes at the top level instead of alongside the source node, and exposed the folder option for create commands.
- Share controls and operations now consistently respect user and access-token permissions, with unavailable options disabled and explained in share dialogs.
- Improved audit log reliability during bulk operations and shutdowns, preserved original event times, and ensured user identity is recorded consistently.
- Field creation audit entries now include the created field’s name, type, and options.
- Fixed orphaned linked-record fields so they can be deleted after their referenced table has been removed.
- Improved V2 compatibility across formulas, lookups, rollups, filters, sorting, grouping, search, aggregation, link validation, field lifecycle operations, and base duplication.
- V2 writes now normalize cleared text, checkbox, attachment, user, link, and multi-value fields to `null`, while reliably enforcing required-field constraints.
- V2 link updates now accept compatible single-link and multi-link input shapes, improving compatibility with integrations, imports, and field cardinality changes.
- Improved V2 date validation so strict writes reject invalid calendar dates and typecast writes store invalid dates as empty values instead of silently changing them.
- Text-to-date and formula-to-date conversions now skip invalid calendar values without blocking the entire field conversion.
- Fixed rating field conversions to avoid invalid zero-star values and round decimal values consistently.
- V2 record reads, updates, and deletions now apply table, row, and field permissions more consistently, including masked fields and disabled access grants.
- Fixed V2 record updates involving users without custom avatars; initial-based avatar fallbacks continue to work normally.
- Fixed grouped views that could fail to load when field projection omitted required grouping metadata.
- Improved view reliability across creation, updates, sharing, imports, duplication, realtime updates, plugin views, and concurrent edits.
- Fixed self-hosted signup so new users reliably join all eligible auto-join spaces as Viewers, including when SSO joining is also configured.
- Improved the unsubscribe page so it remains usable after a successful preference change even if a subsequent refresh fails.
- Fixed automations that could execute the same action chain twice, preventing duplicate messages, webhooks, and emails.
- Automations watching formula fields now run when source-field changes update the formula, while avoiding duplicate runs and loops.
- Improved large-delete undo and redo reliability so records are restored correctly without unexpected timeouts.
- Reduced database pressure during large imports and table duplication by skipping unnecessary initial per-cell history entries; normal edit history remains unchanged.
- Improved the mobile attachment preview layout, including wider spreadsheet viewing, better horizontal scrolling, non-overlapping navigation, and correct rotated-image fitting.
- Improved base loading and navigation by reducing duplicate requests and opening previously visited, pinned, or eligible first-time bases directly when a safe destination is available.
- Stale direct base links now fall back to the normal entry flow instead of causing redirect loops or unnecessary errors.
- Improved localized validation messages for required and unique fields, including field-specific duplicate-value errors in bulk and selection-based operations.
- Improved secret handling and added support for safer credential rotation.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-05T11-23-43Z.2499)

## v2026.8.6 - 2026-08-05

### Teable release.2026-08-05T08-59-48Z.2496

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-05T08-59-48Z.2496`.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-08-05T08-59-48Z.2496)

## v2026.8.5 - 2026-08-05

### Teable release.2026-08-05T06-42-00Z.2495

`ghcr.io/teableio/teable:latest` now resolves to `release.2026-08-05T06-42-00Z.2495`.

## v2026.8.4 - 2026-08-05

- **Sandbox engine `v0.2.0-fix9` accepts setgid `dir_mode`.** Values above
  `0o777` (e.g. `0o2775`) in `[kubernetes.volume_subpath_precreate]` no longer
  fail server startup validation; pairs with the new Helm README recipe for
  sandbox volumes owned by a different identity than the sandbox user.

## v2026.8.3 - 2026-08-03

- **Infra Service now always watches the sandbox and app-deploy namespaces.**
  The `K8S_NAMESPACES` list automatically includes `sandboxNamespace.name` and
  (when app deployment is enabled) `appRuntime.namespace`, fixing default
  installs where active sandboxes in `teable-sandbox` were invisible to the
  Infra Service ([teable-deployment#1](https://github.com/teableio/teable-deployment/issues/1)).
  If you had manually added these to `infraService.namespaces`, you can remove
  them; otherwise no action needed.

## v2026.8.2 - 2026-08-02

- **App switcher targets are now configurable.** The v2026.8.1 boolean
  `infraService.internalAppSwitcher` is replaced by
  `infraService.internalAppSwitcherApps` — a list of `{name, desc, url,
  current}` entries pointing at your own companion control planes. Empty
  (default) hides the switcher. If you had enabled the boolean, move your
  targets into the list; otherwise no action needed.

## v2026.8.1 - 2026-08-02

- **Optional operator app switcher in the Infra Service sidebar.** New value
  `infraService.internalAppSwitcher` (default `false`) shows a grid button
  linking to companion control planes, for operators running several of them.
  When left off the UI is unchanged. No action needed.

## v2026.8.0 - 2026-08-01

- **The sandbox engine can run under a chosen identity.** New
  `opensandbox-server.server.podSecurityContext` / `securityContext` /
  `containerPort` values. Useful when a shared sandbox volume is owned by a
  uid other than the default: run the engine as that uid and its subPath
  pre-creation writes directories directly, with no chown. Non-root also needs
  `containerPort` (and `[server] port` in `configToml`) moved off port 80.

## v2026.7.28 - 2026-07-30

- **Docker server mode: storage API calls no longer fail with an empty `S3Error`.**
  The entry routed `/<bucket>/...` to MinIO but not the bare `/<bucket>` path that
  S3 clients send as `GET /<bucket>?location`, so those requests got console HTML
  and some app endpoints returned 500; `doctor.sh` now probes the bare path too.
  Existing installs: pull the updated Caddyfiles, then run
  `docker compose up -d --force-recreate caddy`.
- **Docker mode: a new user's first sandbox no longer crashes with a
  permission error.** When a sandbox workspace directory did not exist yet,
  Docker created it owned by root, and the sandbox (running as uid 1000)
  failed on first write. The sandbox engine (`v0.2.0-fix8`) now pre-creates
  these directories with the sandbox user's ownership. Existing Docker
  installs: set `OPENSANDBOX_SERVER_IMAGE` to `ghcr.io/teableio/opensandbox-server:v0.2.0-fix8`
  in your `.env`, then re-run `apply.sh`. Kubernetes installs are not
  affected.

### Teable release.2026-07-30T06-45-38Z.2429

#### Feature Updates
- Added mobile-friendly controls to shared pages, making key options such as sign-in easier to access on small screens.
- Custom emoji icons can now be removed from tables and Bases to restore the default icons.
- Added a CLI-based permission matrix configuration workflow for exporting, editing, previewing, comparing, and applying declarative permission settings, with validation and safeguards against accidental lockouts.

#### Bug Fixes & Improvements
- Improved initial table loading performance and prevented blank rows by ensuring consistent initial record data across different loading paths.
- Rerunning an automation workflow now keeps you in the current tab and task context.
- Improved stability and responsiveness when clearing large numbers of cells.
- Added consistent loading states when opening, refreshing, or switching between tables, automations, apps, dashboards, and other Base content.
- Fixed an issue where Grid views with many visible fields remained stuck on loading placeholders after scrolling beyond the first 100 records.
- Selecting content while Chat is expanded on desktop now restores the side panel layout without losing the conversation, draft, attachments, or scroll position. The expanded layout remains unchanged when interacting with folders.
- Reduced initial loading delays when opening a Base from a space, while accommodating data-saving mode and extremely slow network connections.
- Question cards and confirmation cards now appear faster with more streamlined options, handle unanswered prompts more effectively, and avoid unnecessary spacing or layout shifts.
- Newly created AI Chat and App Builder sandboxes now always use the latest CPU, memory, and temporary disk limits configured in System Administration.
- Fixed an issue where select values temporarily disappeared after converting a field between single select and multiple select.
- Improved grouped Grid views so that expanding or collapsing groups updates only the affected area, preserves scroll context, and maintains accurate layouts after view changes.
- Improved stability for Bases with many calculated fields and conditional summaries, reducing redundant calculations and resource pressure during frequent updates.
- Fixed incorrect variable selection in automation condition nodes following scheduled triggers.
- Improved AI Chat completion response speed and failure recovery.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-30T06-45-38Z.2429)

## v2026.7.27 - 2026-07-30

- **The Teable app now trusts your private CA.** With `infraService.privateCa`
  enabled, the CA bundle now also mounts into the Teable app pod -- sandbox
  creation and app deploys no longer fail TLS verification on a private PKI.
  Already using the switch? `helm upgrade` is enough (Teable deployed outside
  this chart: see `helm/private-ca.md`).

## v2026.7.26 - 2026-07-30

- **Upgrades that skip releases can now compute their pending migrations.**
  `versions.yaml` gains `migrationCatalog` -- every migration this release
  line has ever required, with the release that introduced it -- rendered as
  "Upgrading across releases" in `VERSIONS.md`; `doctor.sh --from
  <your-release>` (Docker and Helm) prints what your install still has to
  run. No action needed.

## v2026.7.25 - 2026-07-29

- **`VERSIONS.md`: the sandbox-chain verification reads as its own line.** It
  rendered nested under the Kubernetes entry, which made it look like part of
  that run rather than a separate check. No action needed.

## v2026.7.24 - 2026-07-28

- **Reserve kubelet memory on dedicated sandbox nodes — action needed.**
  Bin-packing (`sandboxScheduling.packing`, default since v2026.7.15) fills
  sandbox nodes to their allocatable limit, so a node left on its provisioner's
  default reservation can lose its kubelet under load and drop every sandbox on
  it. Set `system-reserved`/`kube-reserved`/`eviction-hard` in your node
  provisioner, then replace existing sandbox nodes — the reservation applies at
  node bootstrap only.
- **`VERSIONS.md` now dates the sandbox-chain verification separately.** The
  Docker/Kubernetes dates cover the full journey; a release that only moves the
  sandbox engine or execd now carries its own, current date for that chain
  instead of implying the whole journey was redone. No action needed.

## v2026.7.23 - 2026-07-28

- **Sandboxes can run unprivileged.** `global.sandboxSecurity.nonRoot.enabled=true`
  runs new sandboxes as uid 1000 with all capabilities dropped, and
  `seccompProfile: RuntimeDefault` hardens the profile. Both off by default;
  read "Hardening sandboxes" in `helm/README.md` before enabling.
- **Sandbox engine `v0.2.0-fix7`, execd `v1.0.19-fix3`** (required by the
  switch above). Helm installs get them from `versions.yaml`; Docker installs
  on the next `apply.sh`.

## v2026.7.22 - 2026-07-28

- **New guide for sizing sandbox capacity.** `global.sandboxScheduling.memoryRequest`
  decides how many sandboxes fit on a node, and both a too-low and a too-high
  value fail in confusing ways. Start at `1300Mi` for a mixed AI-session and
  app-build workload (roughly 21 sandboxes on a 32 GiB node), then re-derive it
  from your own usage. The guide also covers the kubelet memory reservation
  bin-packing needs -- without it a full node can starve its own kubelet while
  the cloud console still reports the instance healthy. See
  `helm/sandbox-capacity.md`; if bin-packing is already on, check your node
  reservation against it.

## v2026.7.21 - 2026-07-28

- **Private CA trust for sandboxes is now a values switch.** Set
  `global.sandboxPrivateCa.enabled=true` and point `configMapName` at a
  ConfigMap holding a full CA bundle (public roots plus your corporate root);
  new sandboxes then trust it system-wide instead of in Node only. If you
  hand-edited `batchSandboxTemplate` for a private CA, move to the switch and
  drop those lines -- see `helm/private-ca.md`.

## v2026.7.20 - 2026-07-27

- **A failed app update no longer takes down the running version, and sleeping
  apps are no longer removed.** App Runtime keeps the previous version serving
  while a new version fails to become ready, and apps scaled to zero are never
  treated as unhealthy leftovers. Re-publish a failed update to retry; no other
  action needed.

## v2026.7.19 - 2026-07-27

### Teable release.2026-07-27T10-51-13Z.2393

#### Feature Updates

- Reorganized navigation on the system administration page into clearer groups.
- Expanded audit logs: delete operations now include specific record IDs, each log includes the API endpoint that generated it, and space and base creation, deletion, and modification are also recorded.
- Unified collaborator invitation notifications across email and in-product channels, with toast notifications for unread invitations.
- Strengthened sandbox permission controls. Agents can still install user-space dependencies, while required system packages must be preinstalled.

#### Bug Fixes & Improvements

- Improved enterprise SSO reliability for generated applications. Authorization failures now display clear errors instead of loading indefinitely.
- Improved automation reliability for external databases.
- Improved audit log reliability without interrupting completed user requests.
- Updated the favicon in light mode to improve its visibility and recognizability in browser tabs.
- Improved AI proxy error responses when a base is missing or a token is invalid.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-27T10-51-13Z.2393)

## v2026.7.18 - 2026-07-27

- **Sandbox egress fence: allow-list private platform endpoints.**
  `opensandbox-server.server.sandboxNetworkPolicy.additionalAllowedCidrs`
  (`server.…` standalone) keeps private platform VIPs reachable while private
  ranges stay blocked. No action needed unless you enable the fence.
- **Enabling the sandbox egress fence removes the built-in allow-all policy.**
  On existing clusters also delete it once: `kubectl -n <sandbox namespace>
  delete networkpolicy teable-sandbox-allow-all-egress` (apply does not prune).
- **`runtimeNetworkPolicy.*.enabled: false` now actually disables the policy.**
  An explicit `false` used to be treated as unset, so the allow-all kept
  rendering. No action needed.

### Teable release.2026-07-27T06-04-51Z.2385

#### Feature Updates
- Added an organization setting that lets admins enable department keyword search across the entire organization while keeping department tree browsing limited to related departments. The option is off by default and treats wildcard characters literally.
- Renamed the chat entry to “Chat in IM” and updated related terminology to use “IM bot.”

#### Bug Fixes & Improvements
- Cleaned up read-only template previews by removing irrelevant computing status and preventing unnecessary activity checks that could cause 403 errors.
- Restored reliable sorting, filtering, and search for records with missing created or modified metadata.
- Limited field change warnings for button fields to updates that may affect calculations or rewrite data, avoiding warnings for display-only changes such as button text.
- Fixed grouped table views with footer aggregations failing to load for permission-restricted users when the grouping field was hidden.
- Improved sandbox generation reliability by preventing abandoned runs and secondary notification failures from causing repeated retries, cross-run interference, or loss of final results.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-27T06-04-51Z.2385)

## v2026.7.17 - 2026-07-27

- **Private CA trust for published apps.** New `infraService.privateCa` values
  mount your corporate CA bundle into the Infra Service and published apps.
  Private-PKI installs: follow `helm/private-ca.md`, then republish apps.
- **Console: the Git Repos page no longer blocks on repository-size scans.**
  The repo listing recomputes per-repo sizes with a full directory scan that can
  take tens of seconds on networked storage; once its 5-minute cache expired the
  next page load paid the whole scan. The listing now serves the previous stats
  immediately and rescans in the background, and the git-registry pre-warms the
  cache on startup, so page loads stay fast right after a deploy too. Sizes may
  be up to one scan-cycle stale. No action needed.
- **Console: one unhealthy node no longer stalls the Sandboxes/Cluster pages.**
  Cluster status collected per-node PVC usage through the kubelet
  `stats/summary` proxy with no dedicated timeout; when a node's kubelet
  stopped serving (e.g. under memory pressure) every page load waited ~11s for
  the apiserver-side TLS handshake to fail. That call now times out after 3s
  and degrades to "no PVC usage data" for the affected node. No action needed.
- **Console: node names now display correctly on EKS/Karpenter clusters.** The
  Sandboxes and Cluster pages rendered nodes as `- · 2.compute.internal` because
  the node pool and display name were still derived from GKE conventions. The
  node pool is now resolved from `teable.io/node-pool`, then
  `karpenter.sh/nodepool`, then `eks.amazonaws.com/nodegroup` (the GKE label is
  still recognized), and `ip-…compute.internal` hostnames keep their host
  segment, e.g. `sandbox · ip-172-31-40-231`. No action needed.
- **Console: the Git Repos page has been reworked.** It now opens with summary
  cards (repo count, total size, repos pushed in the last 7 days, empty repos)
  above a sortable, paginated repository table. Clicking a row slides out a
  panel with the commit history, per-commit diffs and the file browser, and
  every repo has a **Download zip** button that fetches the latest code archive
  (HEAD) using your console session. Search, sort, page and the selected repo
  persist in the URL. No action needed.
- **Console: sandbox table sorting sticks, and Usage is split into CPU / Mem
  columns.** Sorting on the Sandboxes page is now kept in the URL, so a refresh
  (or a shared link) preserves it, and CPU and memory usage sort independently.
  No action needed.
- **Console: the Packages page has been removed.** The package-registry browser
  (internal registry / GCP Artifact Registry / local Docker images) saw no real
  usage and has been dropped, along with its `infraService.packages.*` Helm
  values and `PACKAGE_*` environment variables. Any leftover `packages:` block
  in your values file is now ignored and can be deleted. No action needed.

## v2026.7.16 - 2026-07-26

- **Helm: ingresses accept additional hostnames (`ingress.additionalHosts`).**
  infra-service, git-registry, the sandbox lifecycle API (`/v1`) and the sandbox
  preview gateway can now serve extra hostnames alongside the primary one, using
  the same TLS secret (issue a multi-SAN certificate listing every name in
  `certificate.dnsNames`). Useful for serving a permanent cluster-scoped domain
  next to the public domain during migrations. Empty by default. No action needed.

## v2026.7.15 - 2026-07-26

- **Helm: sandbox egress NetworkPolicy now follows `sandboxNamespace.name`.**
  Previously `runtimeNetworkPolicy.sandbox` had an independent namespace default,
  so renaming the sandbox namespace left the policy pointing at the old (deleted)
  namespace and the upgrade failed. Explicit `runtimeNetworkPolicy.sandbox.namespace`
  values still win. No action needed.

- **Helm: sandbox bin-packing scheduling (`global.sandboxScheduling.packing`).**
  New sandboxes now prefer the fullest node instead of spreading across nodes,
  so clusters run fewer, fuller nodes. Placement-only change for newly created
  sandboxes; set `packing.enabled: false` to keep the old spread. No action needed.
- **Helm: central sandbox scheduling requests (`global.sandboxScheduling.memoryRequest` / `cpuRequest`).**
  Sets the per-sandbox scheduling requests in one place; per-node sandbox
  capacity then derives from allocatable memory. Unset by default (existing
  behavior preserved). No action needed.
- **Helm: warm-capacity balloon pods (`global.sandboxScheduling.headroom.replicas`).**
  Low-priority placeholder pods pre-hold sandbox slots so a new sandbox starts
  instantly while node provisioning happens in the background. Balloons are
  sized from `sandboxScheduling.memoryRequest`/`cpuRequest` (one balloon = one
  sandbox slot) and deploy into the sandbox namespace (`sandboxNamespace.name`).
  Default 0; enable only together with a cluster autoscaler. Air-gapped
  installs must mirror the pause image (`headroom.image`) first. No action needed.
- **Helm: node memory backpressure (`global.sandboxScheduling.backpressure`).**
  infra-service now cordons dedicated sandbox nodes (NoSchedule taint) at 90%
  node memory and uncordons at 80%. It acts only on nodes labeled
  `teable.io/node-pool=sandbox`, so clusters without that label are unaffected;
  requires metrics-server and the node patch grant included when
  `infraService.rbac.clusterScope.create` is true. An optional
  `global.sandboxScheduling.memoryLimit` adds a default per-sandbox memory cap
  (unset by default). Set `backpressure.enabled: false` to opt out — leftover
  backpressure taints are swept automatically on the next service start. Make
  sure sandbox pod tolerations do not use a blanket `operator: Exists`, which
  would defeat the backpressure taint. No action needed.
- **Measured effect of the scheduling changes (our fleet, 4-core/32 GiB dedicated sandbox nodes).**
  Per-node sandbox capacity is now derived from allocatable memory — 42 sandboxes
  per node at the 700 Mi `memoryRequest` we run — instead of being silently capped
  by CPU requests. Nodes fill up before a new one is added, and a drained node is
  reclaimed within minutes (6.5 min measured round-trip), where previously every
  load peak left one extra node running permanently. Net for us: the steady-state
  sandbox pool went from two always-on nodes to one — roughly half the sandbox
  compute cost — with unchanged sandbox performance. Your numbers depend on node
  size and `memoryRequest`; treat these as a reference point. No action needed.

## v2026.7.14 - 2026-07-26

### Teable release.2026-07-26T01-04-56Z.2377

#### Feature Updates

- Added admin-configurable AI concurrency limits for each space, with a default of five concurrent tasks. Additional AI requests are queued and processed fairly across field generation, automations, and other AI workflows.
- Admins with the required permissions can now initiate a password reset for a specific user. Reset links are single-use, expire at the stated time, and are emailed automatically when SMTP is configured. This action is unavailable when password login is disabled.
- Column reordering in grid views now updates immediately without reloading records. Failed saves safely restore the previous order and display an error.

#### Bug Fixes & Improvements

- Fixed lookup values remaining empty or stale after linked source data changed, including filtered records and conditional lookups. Related values now recalculate and synchronize more reliably, with improved performance for large updates.
- Fixed Claw bot chats becoming stuck or losing replies after the bot was removed from the conversation’s Base. Existing chats are moved to another accessible Base where possible, and completed replies are delivered more reliably.
- Improved AI task scheduling, cancellation, recovery, and progress accuracy, including when Bases are deleted or generation tasks stall.
- Improved navigation from Spaces with faster Base entry and continuous loading feedback for pinned Bases, tables, views, dashboards, workflows, and apps. Repeated clicks no longer restart navigation, entry can be canceled, and native new-tab actions remain supported.
- Fixed expired SSO callbacks showing a raw error after browser navigation. Users are now redirected to the app when already signed in or to the login page when authentication is required.
- Improved view switching so rows, sorting, filters, grouping, controls, and permissions from the previous view no longer appear briefly. Recently used views also restore their initial layout more smoothly while fresh data loads.
- Improved credit billing performance and resilience under high-volume activity. Fixed incorrect overlimit blocks after refunds or delayed charges, and improved charge and refund attribution across billing periods and add-on validity windows.
- Fixed BYODB table switching failures caused by schema handling, reducing unclear errors when changing tables.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-26T01-04-56Z.2377)

## v2026.7.13 - 2026-07-23

### Teable release.2026-07-23T12-32-52Z.2361

#### Feature Updates
- Added in-app notifications for Space and Base invitations, with direct links to the relevant destination and improved notification accuracy.
- Updated the welcome video on the new base page with the latest onboarding guidance.

#### Bug Fixes & Improvements
- Improved table navigation reliability by automatically opening the last-used or default view and preventing loading screens from becoming stuck when switching tables.
- Improved computed-field responsiveness and reliability, particularly for lookups, linked records, repointing, and large fanout updates under concurrent load.
- Updated CN in-app subscription pricing to match the CN website: ¥70 per seat/month for Professional and ¥140 per seat/month for Business.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-23T12-32-52Z.2361)

## v2026.7.12 - 2026-07-23

- **Helm: external gateway entry mode.** Set `global.entry.mode: external-nginx` when an external SLB/nginx terminates TLS and forwards HTTP to Services: the chart then renders no Ingress or Certificate objects anywhere (umbrella and sub-charts) and instead renders a `<release>-nginx-routes` ConfigMap declaring every host/path → Service route for your gateway team, derived from the same values as the rest of the deployment. Requires `appRuntime.ingress.mode: gateway` (the render fails otherwise, because dynamic per-app Ingresses would have nothing serving them). Default unchanged (in-cluster Ingress, per-component flags); no action needed.
- **Helm: bring-your-own PVC and static PV binding for git-registry and VictoriaMetrics.** `gitRegistry.persistence` and `infraService.victoriaMetrics.persistentVolumeClaim` now accept `existingClaim` (reuse a pre-created PVC, chart creates none), `volumeName` (bind to a specific pre-provisioned PV; an explicit empty `storageClassName` is now emitted to disable dynamic provisioning), and `accessModes`. Edge case: an explicitly empty VictoriaMetrics `storageClassName` used to fall back to `standard-rwo` and now means the cluster default StorageClass — set `standard-rwo` explicitly if you relied on that. No action needed otherwise.
- **Helm: data PVCs survive `helm uninstall`.** The git-registry and VictoriaMetrics PVCs now carry `helm.sh/resource-policy: keep`; delete the PVC explicitly if you want the data gone. No action needed.
- **Helm: cluster-scoped RBAC can be skipped for restricted deploy accounts.** New `rbac.clusterScope.create` toggles (infra-service, opensandbox-server, its preview gateway, opensandbox-controller, registry-gc) render only the ServiceAccount/Role/RoleBinding half when false, so a namespace-scoped deploy account can install while a cluster admin pre-provisions the ClusterRole/ClusterRoleBinding half. The mirror toggle `rbac.namespaceScope.create: false` renders only the cluster half (for producing an admin bundle with `helm template`), and the release also ships that half pre-rendered as `helm/teable-infra/manifests/cluster-rbac.yaml` (next to `crds.yaml`). `infraService.rbac.knativeCompat: false` additionally drops the temporary Knative cleanup grant. Defaults unchanged; no action needed.

### Teable release.2026-07-21T04-38-35Z.2304

- Updated the README with a cover image and an improved community layout, making the project overview clearer and easier to navigate.
- Reordering columns no longer triggers a full record refresh, reducing unnecessary loading states, flickering, and duplicate requests.
- When only column metadata changes, record data now remains available from the cache, improving table responsiveness during layout adjustments.
- This also resolves related skeleton screen issues when moving columns.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-21T04-38-35Z.2304)

### Teable release.2026-07-22T11-07-01Z.2343

#### Feature Updates
- Improved the field calculation status experience with clearer progress and status changes, a simplified activity panel, and additional translations.
- Improved loading responsiveness for tables with many columns.
- Added support for path-style presigned URLs for S3-compatible storage via `BACKEND_STORAGE_S3_FORCE_PATH_STYLE`, with separate internal addressing configuration available through `BACKEND_STORAGE_S3_INTERNAL_FORCE_PATH_STYLE`.
- Teable Chat can now use authorized and @mentioned Apps as context, enabling AI assistance based on the App's code, structure, and configuration while excluding sensitive runtime configuration.

#### Bug Fixes & Improvements
- Fixed manual sorting to ensure row order remains consistent after real-time updates and page reloads.
- Fixed the self-link record selector to display only fields visible in the current connection and return complete record content.
- Reduced the maximum width of table descriptions to keep view tabs easily accessible and improve header layout.
- When updating `visibleFieldIds` via the API, link fields and link sharing configurations now always keep the linked table's primary field visible, consistent with UI behavior.
- Improved the reliability of attachment and import requests from trusted origins in runtime configuration environments.
- Fixed an issue where saving a shared Base as a copy failed when it contained plugin panels outside the sharing scope. Copies now include only shared tables and panels, and safely skip invalid panel mappings in legacy archives.
- Fixed views getting stuck in the "Calculating" state and improved recovery for formula- and Lookup-related calculations.
- Fixed formula-based Lookup fields to ensure they remain editable and convertible, and improved the reliability of loading, saving, display settings, and error handling.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-22T11-07-01Z.2343)

### Teable release.2026-07-23T08-40-34Z.2355

#### Feature Updates
- Added multiple ways to close the Kanban “Stack by” dialog: press Esc, click outside the dialog, or select “Done”.
- Added a refresh action to Audit Log and improved the display of long operator, space, and Base names.

#### Bug Fixes & Improvements
- Improved publishing consistency, ensuring that when editing, generation, and publishing operations overlap, the published app remains consistent with the latest preview without missing or overwriting newer changes.
- Optimized invitation limit handling to prevent subscribed organizations from being deactivated during legitimate bulk invitations. The hourly automatic deactivation policy no longer applies to Community Edition.
- Fixed a crash when opening “Record History” from the sidebar tree menu and clarified the meanings of the “Record History” and “Recycle Bin” labels.

[Full release notes](https://github.com/teableio/teable/releases/tag/release.2026-07-23T08-40-34Z.2355)

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
