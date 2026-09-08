# Private-network deployment

The `server` mode of the all-in-one bundle also runs on a machine that has no
internet exposure: an intranet host, a corporate PKI, no DNS API, possibly no
registry access. Everything in the quick start still applies; this page covers
the four things that are different on such a network and the failures they
cause when skipped. Read it before the first `./apply.sh server`.

## Before you start: four questions

Answer these first. Each one has cost a day when discovered after the fact.

| Question | Why it matters |
|---|---|
| **Which DNS server** will hold the four records -- for your users *and* for this machine? | Two of the four names are wildcards. A hosts file cannot express a wildcard, and containers never read the host's hosts file. Without wildcard resolution the app cannot reach its own sandboxes. |
| **Where does the certificate come from?** | It must be one certificate covering four names. Automatic issuance needs a Cloudflare DNS API token; otherwise you bring your own certificate, and if a private CA signed it, the stack must be told to trust that CA. |
| **Is anything else on this machine using ports 80/443?** | The entry proxy must own both ports. A Kubernetes ingress, nginx, or a control panel on the same host silently hijacks 443 for LAN clients; there is no port-changing option. |
| **Can the machine pull images?** | If not, mirror the image set into a registry it can reach first -- including the sandbox agent image that matches the Teable release. |

## 1. DNS: four records, two of them wildcards

Create these records on a DNS server that both your users' machines and this
machine actually query, all pointing at the machine's IP:

```text
<BASE_DOMAIN>              A  <machine-ip>
infra.<BASE_DOMAIN>        A  <machine-ip>
*.app.<BASE_DOMAIN>        A  <machine-ip>
*.sandbox.<BASE_DOMAIN>    A  <machine-ip>
```

Notes that trip people up:

- **A public domain pointing at a private IP is fine.** If you own a domain on
  a public DNS provider, adding the records there works for an intranet
  deployment -- nothing needs to be reachable from the internet. Some corporate
  resolvers drop public answers that contain private addresses ("DNS rebinding
  protection"); if `nslookup` from a workstation returns nothing while the
  records exist, ask your network team to allow the zone.
- **The hosts file is not a substitute.** It resolves the two fixed names for
  one machine, but never the wildcards, and the containers on the server do not
  read it. The symptom is AI chat spinning forever while the sandbox itself
  looks healthy.
- **Who needs which name.** The fixed names are also resolved inside the
  stack through internal aliases, so they work even before DNS is right. The
  wildcards are used by browsers (previews and published apps) and by the
  Teable app itself: it dials every sandbox at
  `<port>-<sandbox-id>.sandbox.<BASE_DOMAIN>` through the machine's resolver.

Verify from a workstation and from the machine:

```bash
nslookup infra.<BASE_DOMAIN>
nslookup anything.sandbox.<BASE_DOMAIN>       # must return the machine IP
```

`./doctor.sh` repeats the wildcard check from inside a container after the
stack is up.

## 2. Certificate: one certificate, four names

### Option A: automatic (works on intranets too)

If the domain's DNS is on Cloudflare, fill `ACME_EMAIL` and
`CLOUDFLARE_API_TOKEN` in `.env` as in the quick start. The DNS-01 challenge
is answered by a DNS record, so the machine does not need to be reachable from
the internet -- but it does need to reach Let's Encrypt and the Cloudflare API
outbound.

### Option B: bring your own certificate

For a corporate PKI or a domain without a DNS API, point `.env` at the files:

```bash
TLS_CERT_FILE=/opt/teable/certs/fullchain.pem   # full chain, PEM, absolute path
TLS_KEY_FILE=/opt/teable/certs/privkey.pem
```

Leave the Cloudflare lines blank. `apply.sh` derives `TLS_MODE=static`, runs
the official Caddy image instead of the DNS-plugin build, and serves your
certificate on all four sites.

The certificate must list all four names in its Subject Alternative Names;
check before applying:

```bash
openssl x509 -in /opt/teable/certs/fullchain.pem -noout -text | grep -A1 "Subject Alternative Name"
# DNS:<BASE_DOMAIN>, DNS:infra.<BASE_DOMAIN>, DNS:*.app.<BASE_DOMAIN>, DNS:*.sandbox.<BASE_DOMAIN>
```

`apply.sh` warns about each missing name. A missing wildcard shows up later as
`ERR_TLS_CERT_ALTNAME_INVALID` in the admin sandbox check.

**Replacing the certificate** (renewal, or after changing `BASE_DOMAIN`): copy
the new files over the old paths, then re-run apply and up. A running Caddy
reads the files once at start and never picks up a replaced file on its own;
`apply.sh` records the certificate's fingerprint so compose recreates it:

```bash
./apply.sh server --with-app && docker compose up -d
```

### Signed by a private CA? Tell the stack to trust it

Browsers on managed workstations already trust the corporate root. The
containers do not: the Teable app calls the Infra entry, the Infra Service
calls the artifact store through the entry, and sandboxes call back into
Teable -- all over HTTPS, all rejecting the certificate with
`SELF_SIGNED_CERT_IN_CHAIN` until told otherwise. One `.env` line covers all
three:

```bash
PRIVATE_CA_FILE=/opt/teable/certs/root-ca.crt    # the CA root certificate, PEM, absolute path
```

`apply.sh` mounts the file into `infra-service`, the Teable app, and every
sandbox, and sets `NODE_EXTRA_CA_CERTS` on each. The corporate root alone is
enough: Node appends it to its built-in roots, so public sites keep working.
(This differs from the Kubernetes guide, where the file replaces the system
trust store and must therefore be a full bundle.)

Adding it to a running stack, or replacing the CA file's content later
(rotation), is the same two commands: `./apply.sh server --with-app` records
the file's fingerprint, and `docker compose up -d` recreates the Teable app,
the Infra Service and the sandbox engine with it (new sandboxes pick it up).

`root-ca.crt` is the CA's root certificate, not `fullchain.pem`. If your PKI
team only gave you the chain, the last certificate in `fullchain.pem` is the
root when its subject equals its issuer -- extract it, or use the whole chain
file (harmless, but then it changes on every renewal).

Not covered by `PRIVATE_CA_FILE`: `curl`, `git`, and Python inside sandboxes
(they do not read `NODE_EXTRA_CA_CERTS`; the AI agent itself and builds are
fine), Java, and published app containers on the Docker backend. See
[`helm/private-ca.md`](../../helm/private-ca.md) for the full matrix.

## 3. Ports 80 and 443 belong to the entry proxy

Every address the stack generates is on port 443: the sandbox endpoints the
app dials, `PUBLIC_ORIGIN`, previews, published apps. There is no option to
move the entry to another port, so nothing else on the machine may answer 443.

Before deploying:

```bash
ss -ltnp | grep -E ':(80|443) '          # a listening socket: nginx, apache, a panel ...
iptables -t nat -S 2>/dev/null | grep -E 'dport (80|443) '   # a forwarding rule: a Kubernetes ingress (hostPort/servicelb) on the same host
```

Either should be empty, or show only Docker's own forwarding once the stack is
up. A Kubernetes distribution on the same host (k3s, for example, ships an
ingress that claims 80/443 through iptables) is the usual culprit: disable its
ingress, or deploy Teable on a machine of its own. Fronting the entry with that
other ingress is possible but unsupported here -- it doubles every
troubleshooting step.

**Verify from a workstation, not from the machine.** A connection from the
machine to its own 443 takes Docker's forwarding path and reaches the entry
even when LAN clients are being hijacked by another rule. From another machine:

```bash
openssl s_client -connect <machine-ip>:443 -servername infra.<BASE_DOMAIN> </dev/null 2>/dev/null \
  | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

The names must be yours. `DNS:ingress.local` or a certificate you do not
recognize means something else answered.

## 4. Images without registry access

Mirror the image set and the matching sandbox agent tag into a registry the
machine can reach, then point the image references in `.env` at it -- see
[`images/README.md`](../../images/README.md), section "Air-gapped / private
registry". Two points specific to this page:

- With your own certificate the entry runs the official Caddy image,
  `CADDY_STATIC_IMAGE` in `.env` (default `caddy:2.9.1`): mirror it and point
  that line at the mirror. (The automatic-certificate option builds its Caddy
  locally from `Dockerfile.caddy`, which needs registry and Go module access
  and is therefore not an option on such a host.)
- The sandbox agent image is pulled at runtime by the app (it preheats
  `<SANDBOX_OPENSANDBOX_IMAGE>:<its own release tag>` through the Infra API),
  so mirror the tag that pairs with the Teable release you run, and again
  before every Teable upgrade.

## 5. Apply and verify

```bash
cd docker/all-in-one
cp .env.server.example .env
$EDITOR .env                     # BASE_DOMAIN, TLS option B, PRIVATE_CA_FILE if applicable, image prefixes if mirrored
./apply.sh server --with-app     # derives TLS_MODE, renders the entry config, validates the certificate names
docker compose up -d
./doctor.sh
```

`doctor.sh` in server mode now also reports the TLS mode, the names on the
certificate actually served on 443, whether `*.sandbox.<BASE_DOMAIN>` resolves
from inside a container, and whether the private CA is mounted where it should
be.

Then walk the product once, in this order -- each step exercises one link of
the chain that the previous steps did not:

1. Open `https://<BASE_DOMAIN>`, register the first account.
2. Admin settings, AI chat runtime: the version check and the sandbox test
   (preheat, ready, test chat) must all pass.
3. Send a message in a real chat, then leave it idle for two minutes and send
   another: proves the streaming connection is not cut by an intermediate
   proxy.
4. Upload an attachment larger than 1 MB.
5. Open an app preview once.

## What apply.sh generates in server mode

| In `.env` | Meaning |
|---|---|
| `TLS_MODE` | `cloudflare` or `static`, derived from which inputs are filled |
| `CADDY_IMAGE` | the DNS-plugin build, or the official image for `static` |
| `COMPOSE_FILE` | gains `compose.server.caddy-build.yaml` or `compose.server.static-tls.yaml`, plus `compose.private-ca.yaml` / `compose.app.private-ca.yaml` when `PRIVATE_CA_FILE` is set |

`Caddyfile.server.generated` / `Caddyfile.app.server.generated` are rendered
from the templates with the TLS directives for the mode; they are gitignored
and regenerated on every `apply.sh`.
