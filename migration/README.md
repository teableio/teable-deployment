# Migration guides

One guide per migration, named by the version that introduces it
(`<version>-<what-it-does>.md`), newest first:

| Version | Guide | What it covers |
|---|---|---|
| 2026-07 (Teable `release.2026-07-14T12-24-39Z.2228`) | [2026-07-basic-to-full-featured.md](2026-07-basic-to-full-featured.md) | Attach the self-hosted AI runtime (sandboxes + app deployments) to an existing Teable; migrate off the Vercel providers |

Each platform release that requires migrations lists them in `versions.yaml`
(`requiredMigrations[].guide` points at a file here). A release with no
required migrations is hot-swappable: updating image versions is the whole
upgrade.

## How these guides are written

- **Checkpoint-driven**: every step ends with what to expect and how to get
  back to a working state if it does not hold. Upgrades here do not rewrite
  your data; the real risk is a stack that will not come up, so the guides
  optimize for "always one step from a working state".
- **Backups are demanded only when they matter**: a guide asks for a
  pre-upgrade backup only when its migration is marked *irreversible* in the
  release's `versions.yaml` -- and says so at the top. No ritual backup steps.
