# Teable Self-Host Deployment

Run the full Teable platform on your own infrastructure.

Just want to try Teable (AI Spreadsheet, APP Builder, AI Workflows)? Use
[teable.ai](https://teable.ai) — nothing to deploy.

## What you deploy

Two planes working together:

- **The Teable app** — the product itself, with its PostgreSQL and Redis.
- **The AI runtime plane** — what powers AI chat, the App Builder and app
  deployments: a sandbox engine (AI sessions run inside sandboxes), the Infra
  Service (console + API that the app talks to), a git registry (source of the
  apps you build), object storage (attachments and build artifacts), and a
  preview gateway.

Everything hangs off **one base domain** — typically a subdomain of yours,
e.g. `teable.example.com`. Four DNS records cover the whole platform:

```
<domain>              the Teable app
infra.<domain>        Infra console + API (git and object storage ride it as paths)
*.app.<domain>        apps you built and deployed
*.sandbox.<domain>    sandbox previews in the browser
```

(Each name is only a default — every hostname can be overridden individually.)

Both deployment paths below install the same platform; they differ only in
where it runs.

## Pick your path

| | Docker all-in-one | Kubernetes (Helm) |
|---|---|---|
| Best for | first full deployment; everything on one machine | an existing cluster; production isolation and scaling |
| Machine / cluster | 1 Docker machine (see `VERSIONS.md` for sizing) | a production K8s cluster (see `VERSIONS.md` for sizing) |
| Sandbox node pool | not needed | recommended, isolates sandbox load |
| Domain & DNS | local: none (`*.localhost`) · server: one managed domain | one managed domain with DNS control |
| **Start here** | [`docker/all-in-one/`](docker/all-in-one/README.md) | [`helm/`](helm/README.md) |

The paths are independent: Docker users never need Kubernetes concepts, and
Kubernetes users never need to read the compose files.

## When something fails

Run the doctor for your path first, then see
[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md):

```bash
cd docker/all-in-one && ./doctor.sh    # Docker
./helm/doctor.sh                       # Kubernetes
```

## Upgrading an existing basic Teable

Already running the basic (standalone) Teable and want the AI features? Your
data stays where it is — you add the runtime plane next to it:
[`migration/`](migration/README.md) — start with [2026-07-basic-to-full-featured.md](migration/2026-07-basic-to-full-featured.md).

## Versions

Each release of this repository pins a compatible set of images — see
[`VERSIONS.md`](VERSIONS.md). Docker deployments default to `latest` and just
work; production Kubernetes deployments should pin versions and upgrade
deliberately.
