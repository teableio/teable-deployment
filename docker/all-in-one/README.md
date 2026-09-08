# Teable Full-Stack Docker Deployment

One machine with Docker, running the complete Teable — the app plus its AI
runtime plane. No Kubernetes required.

Two choices before you start:

| Choice | Options |
|---|---|
| **Where it runs** | `local`: your machine / LAN, no domain needed · `server`: a server with a real domain (public or intranet) + HTTPS (automatic, or your own certificate) |
| **What runs** | **all-in-one** (recommended): Teable app + the full runtime plane · runtime-only: Teable already runs elsewhere |

## Quick start (all-in-one)

### local

```bash
cd docker/all-in-one
./apply.sh local --with-app     # zero manual input: secrets, addresses, entry points all generated
docker compose up -d
./doctor.sh                     # waits for first-start healthchecks, then checks; all green = deployed
```

Open `http://<machine-ip>` and register the first account (it becomes the
admin). The console is at `http://infra.localhost` from the machine's own
browser.

> AI chat in local mode requires a Teable image released after 2026-07-14
> (sandbox traffic rides the path-based proxy, preconfigured here); run
> `docker compose pull teable` to update if yours is older.

### server

Any machine with a real domain works -- public cloud or intranet. First add
four DNS records for your domain, all pointing at this machine's IP:
`<domain>`, `infra.`, `*.app.`, `*.sandbox.` -- where `<domain>` is typically
a subdomain of yours, e.g. `teable.example.com`. Two of them are wildcards, so
they must live on a real DNS server (a hosts file cannot express them). Ports
80/443 must be free for the entry proxy; open 22/80/443 to your users.

Then pick one TLS option in `.env`:

- **Automatic certificates** (domain on Cloudflare): fill `ACME_EMAIL` and
  `CLOUDFLARE_API_TOKEN`; the DNS records must be DNS-only (no proxy). The
  DNS-01 challenge is a DNS record, so the machine never needs to be reachable
  from the internet.
- **Your own certificate** (corporate PKI, no DNS API): fill `TLS_CERT_FILE`
  and `TLS_KEY_FILE` with one certificate covering the four names. If a
  private CA signed it, also set `PRIVATE_CA_FILE`.

```bash
cd docker/all-in-one
cp .env.server.example .env      # fill BASE_DOMAIN plus one TLS option
$EDITOR .env
./apply.sh server --with-app     # derives the TLS mode from what you filled
docker compose up -d            # with automatic certificates the first start issues them, about 1 minute
./doctor.sh
```

Deploying on an intranet, with a corporate CA, or without registry access?
Read [`private-network.md`](private-network.md) first -- it covers the DNS,
certificate, port and image questions that must be settled before the first
apply.

Entry points: Teable at `https://<BASE_DOMAIN>`, console at
`https://infra.<BASE_DOMAIN>` (git and object storage ride that host as
paths). The wildcards (`*.app.` / `*.sandbox.`) are used automatically —
nothing to configure. None of the names are sacred: Teable and the console
can live on any domains via the "advanced" section at the end of `.env`;
anything left blank is derived.

### Pin versions (optional)

Images default to `latest` and work out of the box. For production, pin them
with one command:

```bash
./pin-image.sh          # resolves current versions into .env; then: docker compose up -d teable
```

## Runtime-only (Teable runs elsewhere)

Drop `--with-app` to start only the runtime plane (sandbox engine, Infra
Service, git registry, object storage, entry proxy):

```bash
./apply.sh local        # or ./apply.sh server
docker compose up -d && ./doctor.sh
```

Then give your existing Teable two environment variables:

| Variable | local | server |
|---|---|---|
| `TEABLE_INFRA_API_URL` | `http://<machine-ip>:8088` | `https://<BASE_DOMAIN>` (in this mode the console owns the root domain) |
| `TEABLE_INFRA_API_KEY` | the `OPENSANDBOX_API_KEY` from `.env` | same |

## What is in this directory

```
compose.yaml                     base: the 5 runtime-plane services
compose.local.yaml / .server.yaml mode differences (ports / domains / TLS)
compose.server.caddy-build.yaml  server + automatic certificates: builds Caddy with the Cloudflare DNS plugin
compose.server.static-tls.yaml   server + your own certificate: mounts TLS_CERT_FILE / TLS_KEY_FILE
compose.private-ca.yaml / .app.private-ca.yaml  PRIVATE_CA_FILE trust for infra-service / the Teable app
compose.app.yaml / .app.*.yaml   all-in-one: Teable app + PG + Redis (enabled by --with-app)
Caddyfile.* / caddy.snippets     entry routing (all entry files share one routing logic; the server
                                 ones are templates rendered by apply.sh for the TLS mode)
Dockerfile.caddy                 server + automatic certificates only: Caddy with the Cloudflare DNS plugin
private-network.md               intranet / corporate CA / offline deployments: read before the first apply
opensandbox.toml                 sandbox engine config template (rendered by apply.sh, no secrets)
apply.sh + apply.d/              configuration entry point (behaviors split by file, in order)
lib.sh                           shared functions
doctor.sh                        post-deploy self-check (incl. platform release compatibility;
                                 --from vYYYY.M.N lists the migrations pending since that release)
pin-image.sh                     pin image versions
prepull.sh                       pre-pull sandbox execution-plane images (optional)
.env.local.example / .server.example

generated by apply.sh (gitignored, do not commit):
.env / docker-compose.override.yml / opensandbox.generated.toml / Caddyfile.*.generated
```

## Security notes

- Secrets live only in `.env` and `docker-compose.override.yml`, both
  gitignored — **do not commit them**.
- The whole stack shares one `OPENSANDBOX_API_KEY` (it is also the console
  login).
- The runtime plane mounts `docker.sock` (roughly host-root equivalent);
  deploy on trusted machines only.
- Sandboxes share the host kernel — this is not hard multi-tenant isolation.
  For externally-facing multi-tenant use, enable gVisor/Kata for sandboxes.
- In server mode only caddy's 80/443 are exposed; the MinIO console is not
  public — use an SSH tunnel when needed.

## Day-2 operations

```bash
docker compose ps                    # status
docker compose logs -f <service>     # logs
docker compose restart <service>     # restart one service
docker compose down                  # stop; data lives in named volumes and survives
```

All data lives in Docker named volumes and survives restarts and upgrades.
For backups, these volumes matter most: `teable-db-data` (business database),
`teable-assets` (attachments), `minio-data` (build artifacts),
`git-registry-data` (app source repositories), `teable-agent-juicefs`
(AI workspace), `caddy-data` (certificates, server).
