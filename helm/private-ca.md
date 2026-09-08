# Private CA / self-signed certificates

Sandboxes call back into the Teable app and the Infra entry over HTTPS: AI
sessions talk to the app API, builds push to the git registry, artifacts
upload to object storage. When those hosts serve certificates issued by a
private/corporate CA -- or plain self-signed certificates -- the tools inside
the sandbox reject the connection:

- Node: `SELF_SIGNED_CERT_IN_CHAIN`, `UNABLE_TO_VERIFY_LEAF_SIGNATURE`,
  `self-signed certificate in certificate chain`
- Python: `SSLCertVerificationError`
- curl / git: `SSL certificate problem: unable to get local issuer certificate`

Typical symptoms: the stack is healthy and the UI works, but AI sessions fail
right after starting, or app builds fail on `git push`.

Publicly trusted certificates (the default `letsencrypt-dns` issuer) never
need any of this. On a private PKI, use Option A below -- and if you publish
apps, additionally enable the App Runtime block described in
[Published apps (App Runtime) and the Infra Service](#published-apps-app-runtime-and-the-infra-service).

## Option A (recommended): trust your CA inside every sandbox

Sandboxes run arbitrary user and agent code, so trust has to sit in the
**operating system** store rather than in a handful of per-tool environment
variables: Node, Python, curl, git, Go and package managers each resolve
certificates differently, and an environment variable only covers the runtime
that reads it. This option mounts your bundle over the sandbox OS trust store,
which covers every tool that reads the system CA path, and adds pointers for
the two runtimes that ship their own store (Node and Python's `certifi`).

1. Build a **full CA bundle** -- the public root certificates with your
   corporate root appended, not the corporate root alone. The mount replaces
   the OS trust store, so a single root would leave sandboxes unable to reach
   the public internet. On a Debian-based machine:

   ```bash
   cat /etc/ssl/certs/ca-certificates.crt root-ca.crt > ca-bundle.crt
   ```

2. Create a ConfigMap in the **sandbox namespace** (`teable-sandbox` by
   default; use your `sandboxNamespace` override if you changed it), under the
   `root-ca.crt` key:

   ```bash
   kubectl -n teable-sandbox create configmap sandbox-root-ca \
     --from-file=root-ca.crt=./ca-bundle.crt
   ```

3. Enable the values block:

   ```yaml
   global:
     sandboxPrivateCa:
       enabled: true
       configMapName: sandbox-root-ca
   ```

4. `helm upgrade` with your values. Only **new** sandboxes pick the change up;
   sandboxes are ephemeral, so the fleet converges on its own (or delete the
   running ones to force it).

What this renders into each sandbox pod:

- the bundle mounted read-only at `/etc/ssl/certs/ca-certificates.crt`, the
  default OpenSSL trust store -- curl, git, Python's `ssl`, Go and most system
  tools trust your CA with no further configuration;
- the same file at `/etc/ssl/private-ca/root-ca.crt` as a stable path;
- `NODE_EXTRA_CA_CERTS` (Node keeps its own built-in roots and *extends* them
  with your CA), `SSL_CERT_FILE` (OpenSSL clients that resolve the store
  lazily, including Python's `ssl` module and Go) and `REQUESTS_CA_BUNDLE` (so
  `requests` and `pip` use the bundle instead of the `certifi` copy they ship).
  All three point at the full bundle, so nothing loses the public roots.

Two knobs exist for non-standard images: `key` (ConfigMap key, default
`root-ca.crt`) and `caCertificatesPath` (OS trust store path, default
`/etc/ssl/certs/ca-certificates.crt`; Red Hat based images use
`/etc/pki/tls/certs/ca-bundle.crt`). If your own `batchSandboxTemplate`
already sets one of the environment variables above, your value wins.

Both mount paths and the volume name `sandbox-private-ca` belong to the
switch: if your own `batchSandboxTemplate` already uses one of them, `helm`
fails with an explicit message rather than silently trusting the wrong file.

Not covered:

- **Java**, which reads its own `cacerts` keystore -- import the CA with
  `keytool` from within the session;
- tools that were pointed at a different CA file explicitly, or that carry a
  statically linked trust store -- notably Python clients that default to
  `certifi` without honouring the environment, such as `httpx` (pass
  `verify="/etc/ssl/certs/ca-certificates.crt"`);
- **rewriting the trust store from inside the sandbox**. The system CA file is
  a read-only mount, so `update-ca-certificates` -- and therefore installing or
  upgrading the `ca-certificates` package -- fails inside a sandbox while this
  option is enabled. Add certificates to the ConfigMap bundle instead.

When rotating the CA, updating the ConfigMap is not enough for sandboxes that
are already running -- the certificate is mounted via `subPath`, which never
picks up ConfigMap changes. New sandboxes get the new bundle; recycle the
running ones.

## Option B (trial only): disable TLS verification

Instead of mounting a bundle, override the sandbox pod template
(`opensandbox-server.server.batchSandboxTemplate`) in your values file -- copy
the default block from `helm/teable-infra/values.yaml` and add an environment
variable to the `sandbox` container:

```yaml
                   env:
                     - name: NODE_TLS_REJECT_UNAUTHORIZED
                       value: "0"
```

This disables certificate verification for **all** Node TLS inside the
sandbox, agent included, and it is Node-only (Python and curl need their own
switches). Acceptable for a short trial on an isolated network; do not run
production this way -- prefer Option A.

## The Teable app, published apps (App Runtime) and the Infra Service

Everything outside a sandbox needs its own trust, so the sandbox options above
do not cover it. Three call paths break on a private PKI:

- **The Teable app calls the Infra API.** `TEABLE_INFRA_API_URL` is always
  `https://<your infra host>` -- there is no in-cluster plaintext variant --
  so the app cannot create sandboxes or deploy apps until it trusts your root.
- **App Runtime pods download their build artifact** from the Infra entry over
  HTTPS on every start, and app code may call the Teable API at runtime. Apps
  CrashLoop on the artifact download.
- **The Infra Service probes each app's public URL** after a deploy, so
  deployments can stick at `PublicEndpointNotReady` even though the pod is
  healthy.

1. Create a ConfigMap holding your CA bundle under the `root-ca.crt` key, in
   **both** the Infra Service namespace (`infraService.namespaceOverride`,
   default `opensandbox-system`) and the App Runtime namespace
   (`infraService.appRuntime.namespace`, default `app-deploy`):

   ```bash
   kubectl -n opensandbox-system create configmap teable-root-ca \
     --from-file=root-ca.crt=./ca-bundle.crt
   kubectl -n app-deploy create configmap teable-root-ca \
     --from-file=root-ca.crt=./ca-bundle.crt
   ```

2. Enable the values block:

   ```yaml
   infraService:
     privateCa:
       enabled: true
       configMapName: teable-root-ca
   ```

3. `helm upgrade`. The infra-service and the Teable app both restart with the
   bundle trusted for their outbound HTTPS (the Teable app runs in the same
   namespace as the infra-service, so it uses the same ConfigMap -- no third
   copy needed).
   Already-published apps keep their old pod template: **republish each running
   app** (or trigger a redeploy) to pick up the mount -- new publishes get it
   automatically.

   Running the Teable app outside this chart (`teable.enabled: false`)? Then it
   is yours to wire: mount the same bundle and set
   `NODE_EXTRA_CA_CERTS=/etc/ssl/private-ca/root-ca.crt` on that deployment, or
   its calls to the Infra API keep failing certificate verification.

Make the file a **full bundle** (public roots with your corporate root
appended), not the single root certificate: Node's `NODE_EXTRA_CA_CERTS`
extends the default store, but the `CURL_CA_BUNDLE` used for the artifact
download replaces it, so app code fetching public URLs with curl would
otherwise lose the public roots. The same bundle file also works as the
content of the Option A sandbox ConfigMap.

When rotating the CA, updating the ConfigMap is not enough: the certificate
is mounted via `subPath`, which never picks up ConfigMap changes. Restart the
infra-service pod and the Teable app Deployment, and republish (or redeploy)
running apps after the update.

The Docker backend of the app-deployment plane has no CA injection yet; on a
private PKI use the Kubernetes backend for published apps.

## The Docker path

Usually not needed: `local` mode serves plain HTTP, and `server` mode with
automatic certificates issues **publicly trusted** ones via ACME DNS-01 --
which works on intranet servers too, because the certificate is proven through
a DNS record and the machine never needs to be reachable from the internet.

When the entry serves a certificate from a private CA (you brought your own
certificate via `TLS_CERT_FILE`, or a corporate TLS terminator sits in front of
the stack), one `.env` line covers the whole stack (needs `opensandbox-server`
>= `v0.2.0-fix6`):

```bash
# Mounts the CA root into infra-service, the Teable app (--with-app) and every sandbox,
# and points NODE_EXTRA_CA_CERTS at it. The corporate root alone is enough here:
# the Docker path only appends to Node's built-in roots, nothing replaces the OS store.
PRIVATE_CA_FILE=/opt/teable/root-ca.crt        # absolute host path, PEM

# Or, for short trials only: disable Node TLS verification inside sandboxes
SANDBOX_TLS_NO_VERIFY=1
```

Then re-run `./apply.sh server [--with-app]` and `docker compose up -d`: the
app-side containers and the sandbox engine are recreated with the mount (new
sandboxes pick it up). Rotating the CA is the same two commands -- `apply.sh`
records the file's fingerprint so compose recreates what loads it.
(`SANDBOX_CA_CERT_FILE`, the older sandbox-only switch, keeps working.)
Not covered, as on Kubernetes: `curl`/`git`/Python inside sandboxes, Java, and
published app containers on the Docker backend. The full walkthrough for
private networks is
[`docker/all-in-one/private-network.md`](../docker/all-in-one/private-network.md).
