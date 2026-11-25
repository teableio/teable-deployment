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
.env / teable-app.env / docker-compose.override.yml / opensandbox.generated.toml /
Caddyfile.*.generated
```

## Security notes

- Secrets live only in `.env`, `teable-app.env` and
  `docker-compose.override.yml`, all gitignored — **do not commit them**.
- The whole stack shares one `OPENSANDBOX_API_KEY` (it is also the console
  login).
- The runtime plane mounts `docker.sock` (roughly host-root equivalent);
  deploy on trusted machines only.
- Sandboxes share the host kernel — this is not hard multi-tenant isolation.
  For externally-facing multi-tenant use, enable gVisor/Kata for sandboxes.
- In server mode only caddy's 80/443 are exposed; the MinIO console is not
  public — use an SSH tunnel when needed.

## App secrets

The app needs two secrets of its own: `SECRET_KEY` in `teable-app.env` and
`SANDBOX_JWT_SECRET` in `.env`. On a fresh install, `./apply.sh ... --with-app`
generates both, together with the storage key pair in `.env`. The app derives
its sign-in secrets and the keys for most stored data from `SECRET_KEY`, so
never change or remove any of them by hand, and back up `teable-app.env`
together with `.env`.

Leave the app's other secret variables (`BACKEND_JWT_SECRET`,
`BACKEND_SESSION_SECRET` and the like) unset: they follow `SECRET_KEY`, and a
later version may stop reading them.

Installs created before `SECRET_KEY` was generated have none in
`teable-app.env`. They run on the app's built-in values, which are public.
`./apply.sh` and `./doctor.sh` warn about it, and the app's admin panel may
report `SECRET_KEY` as not set. A later app version refuses to start that way,
so move such an install to its own key before upgrading to it:

1. Update the app to the latest version, and back up the database, `.env` and
   `teable-app.env`. On a Business plan or above, check that **System Admin**
   shows **Key rotation** before going on: that page does the bulk work of
   step 4. If it is not there, the app version predates it; wait for one that
   has it.
2. Run `./adopt-secret-key.sh`. It appends a generated `SECRET_KEY` to
   `teable-app.env`, together with `_OLD` variables that hold the values the
   app has been running on and keep stored data readable. Do not add
   `SECRET_KEY` by hand: on its own it makes that data unreadable.
3. Run `docker compose up -d`. Everyone signs in again.
4. Published apps cannot reach Teable until their credentials are renewed, so
   do that next:
   - With **System Admin → Key rotation**: refresh app credentials under
     **JWT credentials**, then re-encrypt stored data under **Stored
     ciphertexts** (dry run first).
   - Without that page (plans below Business): rotate each app's credentials
     in App Builder (**Credentials & config → Platform credentials →
     Rotate**). Nothing is re-encrypted, so the `_OLD` lines for stored data
     stay.
5. Remove the `_OLD` lines when they are no longer needed, and run
   `docker compose up -d` again:
   - `BACKEND_ENV_VARIABLE_SECRET_OLD`,
     `BACKEND_AI_CONFIG_ENCRYPTION_SECRET_OLD`,
     `BACKEND_THIRD_PARTY_CREDENTIAL_ENCRYPTION_SECRET_OLD` and the two
     `BACKEND_DATA_DB_URL_ENCRYPTION_*_OLD` lines (always both together): after
     the re-encryption of step 4, once a dry run shows nothing left to
     re-encrypt and nothing undecryptable.
   - `BACKEND_INVITATION_SECRET_OLD`: a month after the switch, when the email
     invitations sent before it have expired. Invitation links created before
     the switch stop working once it is removed; create new ones.

## App custom domains

Published apps live at `<name>.app.<BASE_DOMAIN>`. To also serve an app on a
separate domain, point the domain at this server (a `CNAME` to the app's
access link, or an `A` record), list it in `.env`, and apply:

```bash
APP_CUSTOM_DOMAINS=portal.example.org=portal.app.teable.example.com   # comma-separated, no spaces
./apply.sh server --with-app && docker compose up -d
```

The domain uses your `TLS_CERT_FILE` when that certificate covers it, and a
Let's Encrypt certificate otherwise (HTTP-01: ports 80 and 443 must be
reachable from the internet). Server mode only.

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
