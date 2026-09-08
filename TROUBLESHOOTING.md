# Troubleshooting

Symptoms and fixes, by deployment type. Start with the doctor script — it
diagnoses most of what is listed here:

```bash
# Docker all-in-one
cd docker/all-in-one && ./doctor.sh

# Kubernetes
./helm/doctor.sh <release> <namespace>     # defaults: teable opensandbox-system
```

## Kubernetes

### Pods stuck in `Pending`

Almost always storage: the PersistentVolumeClaims need a default StorageClass.

```bash
kubectl get pvc -n opensandbox-system    # look for Pending claims
kubectl get storageclass                 # is any class marked (default)?
```

Either mark a class as default or set the `storageClassName` fields in your
values file (one per component, see `helm/examples/values.example.yaml`).

### Certificates never become `Ready`

The chart requests certificates from a ClusterIssuer named `letsencrypt-dns`
by default. If you have not created it (or named yours differently), every
Certificate stays not-ready and ingress TLS serves a placeholder cert.

```bash
kubectl get clusterissuer                          # does letsencrypt-dns exist?
kubectl describe certificate -n opensandbox-system # issuer errors show here
```

Create the issuer (section 2 of `helm/examples/values.example.yaml`) or point
`certificate.issuerName` at yours. Two hosts are wildcards (`*.app`,
`*.sandbox`), so the issuer must use a DNS-01 solver.

### Teable crashloops with `NoSuchBucket` after `helm install --wait` timed out

The storage buckets are created by a post-install hook, and Helm runs hooks
only *after* `--wait` returns -- while Teable cannot become ready *without*
the buckets. On a first install `--wait` therefore deadlocks until the
timeout, the release is marked failed, the hook never runs, and Teable
restarts with `NoSuchBucket: teable-public`. Install without `--wait` (see
the quick start note).

To recover an already-failed install, run the hooks once and clean them up
(they are replayed outside of Helm, so Helm's hook cleanup does not apply --
the delete removes the finished hook Jobs and their temporary RBAC, keeping
what they produced):

```bash
helm get hooks <release> -n opensandbox-system | kubectl apply -f -
kubectl wait --for=condition=complete job/<release>-minio-init -n opensandbox-system --timeout=5m
helm get hooks <release> -n opensandbox-system | kubectl delete -f - --ignore-not-found
```

### `opensandbox-server` in `CrashLoopBackOff`: `BatchSandbox template file not found`

Your values override `configToml` (which references
`/etc/opensandbox/batchsandbox-template.yaml`) but leave
`opensandbox-server.server.batchSandboxTemplate` empty, so the file is never
mounted. Set the template back (the chart ships a working default), or remove
the reference from your custom `configToml`.

### `CreateContainerConfigError`: `secret "git-registry-jwt" not found`

The chart generates this signing keypair in a pre-install hook. If you set
`gitRegistry.jwtSecret.create: false`, you must create the Secret yourself:

```bash
openssl genpkey -algorithm ed25519 -out jwt.key
openssl pkey -in jwt.key -pubout -out jwt.pub
kubectl -n opensandbox-system create secret generic git-registry-jwt \
  --from-file=private=jwt.key --from-file=public=jwt.pub
```

### `helm upgrade` fails with `Apply failed with 1 conflict ... "kubectl-set"`

You swapped an image with `kubectl set image`, and Helm 4 (server-side apply)
refuses to take the field back. Add `--force-conflicts` to the upgrade —
combined with `-f helm/examples/images.values.yaml` this re-pins the images
and puts Helm back in charge:

```bash
helm upgrade <release> helm/teable-infra -n opensandbox-system \
  --reuse-values --server-side=true --force-conflicts \
  -f helm/examples/images.values.yaml
```

Seeing `forceConflicts enabled when serverSideApply disabled` instead? Your
release history was installed with client-side apply; `--server-side=true`
(included above) switches it over.

### Sandbox previews return 502

A 502 from `https://<id>-<port>.sandbox.<baseDomain>` means routing works but
nothing inside the sandbox listens on that port — check the app running in the
sandbox. If the *host does not resolve*, the `*.sandbox.<baseDomain>` DNS
record is missing.

### AI features in Teable return errors

Teable reaches the runtime plane at `https://infra.<baseDomain>`. Check the
chain in order:

```bash
kubectl exec deploy/<release>-teable -n opensandbox-system -- \
  sh -c 'wget -q -O- https://infra.<baseDomain>/api/health'   # DNS + ingress + TLS
kubectl logs deploy/<release>-teable -n opensandbox-system | tail -50
```

A TLS verification error here means the infra certificate is not trusted by
the Teable pod — see the certificates section above.

### Creating or importing a skill fails

Skills are stored as files through the Infra object API, which is enabled by
the `s3Compat.enabled` switch (off by default) served on top of
`fileBrowser.enabled` (on by default), both under `infraService` -- see
[`helm/README.md`](helm/README.md), "AI Agent skills". Ask the app pod what
the API answers:

```bash
kubectl exec deploy/<release>-teable -n opensandbox-system -- node -e '
fetch(process.env.TEABLE_INFRA_API_URL + "/s3/teable-agent?list-type=2&delimiter=/&max-keys=10", {
  headers: { Authorization: "Bearer " + process.env.TEABLE_INFRA_API_KEY },
}).then(async r => console.log(r.status, (await r.text()).slice(0, 200)))
  .catch(e => console.log("request failed:", e.message))'
```

- `200` with an XML listing -- the API is healthy.
- `404` saying `S3 endpoint is disabled` -- `s3Compat.enabled` is off.
- `404` saying `JuiceFS mount is disabled` -- `fileBrowser.enabled` is off. The
  message names JuiceFS no matter which storage you actually mounted.
- `404` with `NoSuchBucket` -- `s3Compat.buckets` no longer maps `teable-agent`.
- `401` -- the app and Infra Service disagree on the API key, or Infra Service
  cannot read the `opensandbox-api-key` Secret at all (wrong namespace, missing
  RBAC); check the Infra Service logs to tell the two apart.
- `request failed: ...` -- the app never reached the Infra host: DNS, ingress or
  a TLS chain it does not trust.

A `200` here with saves still failing points at `fileBrowser.readOnly: true`:
reads keep working while every write hits a read-only filesystem and returns a
bare 500.

### Skills are saved but the agent never uses them

The sandbox mounts a different volume than the one Infra Service writes to:
the mount succeeds, the skills directory inside the sandbox is empty, and
nothing logs an error. Both must resolve to one shared filesystem -- see
[`helm/README.md`](helm/README.md), "AI Agent skills".

### AI sessions fail right after starting: `self-signed certificate in certificate chain`

The stack is healthy and the UI works, but sandboxes reject the callback to
your Teable/infra hosts (`SELF_SIGNED_CERT_IN_CHAIN`,
`UNABLE_TO_VERIFY_LEAF_SIGNATURE`, or builds failing on `git push` with
`SSL certificate problem`). Your hosts serve certificates from a private CA
that the sandboxes do not trust — mount the root CA into the sandbox template:
see [`helm/private-ca.md`](helm/private-ca.md).

## Docker all-in-one

`./doctor.sh` covers the mainline failures (entry routing, `/v1` split,
storage, sandbox engine, and in server mode the certificate names, wildcard
DNS and private-CA mounts). Deploying on a private network? The checklist in
[`docker/all-in-one/private-network.md`](docker/all-in-one/private-network.md)
prevents most of the entries below.

### AI chat spins forever; Teable logs `SandboxReadyTimeoutException ... fetch failed` (server)

The sandbox is running (its log shows `Server listening`) but the Teable app
never reaches it. The app dials every sandbox at
`<port>-<sandbox-id>.sandbox.<BASE_DOMAIN>`, resolved through the machine's
resolvers, and that wildcard does not resolve -- typically because the domain
was "set up" in a hosts file, which cannot express wildcards and is not read by
containers. Add `*.sandbox.<BASE_DOMAIN>` (and `*.app.`) on a DNS server the
machine uses; `./doctor.sh` confirms with its "wildcard DNS resolves inside
containers" line.

### Sandboxes exit immediately; their log shows `sudo: a password is required`

The sandbox container dies within a second with
`sudo: a terminal is required to read the password` / `sudo: a password is
required`. Teable app images published between 2026-08-18 and 2026-09-04
started Docker-runtime sandboxes through `sudo`, while the agent image had
already dropped its passwordless sudo grant -- the two changes crossed.
Kubernetes deployments are not affected.

**Fix: upgrade the Teable app** to `release.2026-09-07T01-58-27Z.2952` or
later -- every platform release from v2026.9.9 on pins one (`./pin-image.sh`,
or set `TEABLE_IMAGE` in `.env`, then `docker compose up -d teable`). Sandboxes start
through the direct entrypoint again; the workspace-directory ownership the
`sudo` path was meant to fix is handled by the sandbox engine
(`opensandbox-server` >= `v0.2.0-fix8`, pinned here).

If you cannot upgrade yet, restore the grant from the host as a stopgap:

```bash
echo "agent ALL=(ALL) NOPASSWD:ALL" | sudo tee /opt/teable/sandbox-sudoers >/dev/null
sudo chown root:root /opt/teable/sandbox-sudoers && sudo chmod 0440 /opt/teable/sandbox-sudoers
```

then in `.env`:

```bash
SANDBOX_EXTRA_BINDS=/opt/teable/sandbox-sudoers:/etc/sudoers.d/91-agent:ro
```

and `./apply.sh server --with-app` (or `local`) followed by
`docker compose up -d` (the engine is recreated with the new config). New
sandboxes start again. Remove the line (and re-run the same two commands) once
the fixed Teable release is running: it hands the AI agent passwordless root
inside every sandbox, which the fixed release no longer needs.

### Admin sandbox check: `SELF_SIGNED_CERT_IN_CHAIN` (server)

The entry's certificate is signed by a private/corporate CA and the app-side
containers do not trust it. Set `PRIVATE_CA_FILE` in `.env` to the CA root
certificate (PEM), re-run `./apply.sh server --with-app`, then
`docker compose up -d`: the Teable app, the Infra Service and the sandbox
engine are recreated with the CA. The same two commands apply after replacing
the CA file's content (rotation) -- `apply.sh` records its fingerprint, so
compose knows to recreate. See
[`private-network.md`](docker/all-in-one/private-network.md).

### Admin sandbox check: `ERR_TLS_CERT_ALTNAME_INVALID` (server)

`Host: infra.<BASE_DOMAIN> is not in the cert's altnames: ...` -- the
certificate on 443 does not list that name. Usually after changing
`BASE_DOMAIN` without replacing the certificate, or a certificate missing the
wildcards. Replace the files behind `TLS_CERT_FILE` / `TLS_KEY_FILE` with one
covering all four names, then `./apply.sh server [--with-app]` and
`docker compose up -d` -- `apply.sh` records the certificate's fingerprint, so
the entry is recreated (a running Caddy never re-reads a replaced file on its
own).

### Wrong certificate on 443 (for example `DNS:ingress.local`) (server)

`openssl s_client` against port 443 from a workstation shows a certificate that
is not yours -- `ingress.local` is the default certificate of a Kubernetes
ingress controller. Something else on the machine (a k3s or other Kubernetes
ingress, nginx, a control panel) answers 443 for LAN clients. Testing from the
machine itself does not show this: a local connection takes Docker's own
forwarding and reaches the entry. Free 80/443 for the entry (disable that
ingress, or use a machine of its own); the stack has no option to run on
another port.

### Admin page still shows an old TLS error after the fix (server)

The "version and compatibility" check runs once when the Teable app starts and
keeps its last result. After fixing certificates or DNS, restart the app so it
re-checks: `docker compose restart teable`.

### Browser preview URLs do not resolve (server)

The `*.sandbox.<BASE_DOMAIN>` and `*.app.<BASE_DOMAIN>` wildcard DNS records
are missing — both must point at the machine, DNS-only (no proxy).

### Certificate issuance fails on first start (server, automatic certificates)

`CLOUDFLARE_API_TOKEN` lacks the Zone/DNS edit permission, the DNS records
point somewhere else, or the machine cannot reach Let's Encrypt / the Cloudflare
API outbound. Check `docker compose logs caddy` for the ACME error. On a network
without that outbound access, bring your own certificate instead
(`TLS_CERT_FILE` / `TLS_KEY_FILE`).

### doctor entry checks return `000` on the machine itself (server)

Cloud VMs usually cannot reach their own public IP (GCP, for example, does not
hairpin NAT), so every `https://<your-domain>` check fails with `000` when run
on the machine -- while the deployment is perfectly reachable from outside.
In-stack traffic is unaffected (containers reach the entry through an internal
network alias). Either verify from your workstation, or point the two
non-wildcard hosts at the local entry and re-run:

```bash
echo "127.0.0.1 <BASE_DOMAIN> infra.<BASE_DOMAIN>" | sudo tee -a /etc/hosts
./doctor.sh
```

### S3 tools cannot connect through `infra.<BASE_DOMAIN>`

The entry proxies **object paths only** (`/<bucket>/…` -- exactly what
presigned upload/download URLs use, which is all the platform needs). The
bucket-management API (list buckets, etc.) is not routed, so `mc alias set`
and similar clients fail against the entry; point them at MinIO directly
(SSH tunnel) for admin tasks.
