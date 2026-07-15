# Private CA / self-signed certificates and sandboxes

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
need any of this. On a private PKI, pick one of the two options below. Both
work by overriding the sandbox pod template
(`opensandbox-server.server.batchSandboxTemplate`) in your values file --
copy the default block from `helm/teable-infra/values.yaml` and add the
marked lines.

## Option A (recommended): mount your root CA into every sandbox

1. Provide your root CA certificate as a PEM file, e.g. `root-ca.crt`, and
   create a ConfigMap in the **sandbox namespace** (`teable-sandbox` by
   default; use your `sandboxNamespace` override if you changed it):

   ```bash
   kubectl -n teable-sandbox create configmap sandbox-root-ca \
     --from-file=root-ca.crt=./root-ca.crt
   ```

2. Override the sandbox pod template in your values -- the default block plus
   the four marked additions:

   ```yaml
   opensandbox-server:
     server:
       batchSandboxTemplate: |
         # Metadata template (merged with runtime-generated metadata)
         metadata:
         # Spec template
         spec:
           replicas: 1
           template:
             spec:
               restartPolicy: Never
               securityContext:
                 runAsUser: 0
                 runAsGroup: 0
                 fsGroup: 0
                 fsGroupChangePolicy: OnRootMismatch
                 seccompProfile:
                   type: Unconfined
               containers:
                 - name: sandbox
                   volumeMounts:
                     - name: workspace-state
                       mountPath: /home/agent/workspace-state
                     - name: sandbox-root-ca                    # added
                       mountPath: /etc/ssl/private-ca/root-ca.crt
                       subPath: root-ca.crt
                       readOnly: true
                   env:                                         # added
                     - name: NODE_EXTRA_CA_CERTS
                       value: /etc/ssl/private-ca/root-ca.crt
               volumes:
                 - name: workspace-state
                   emptyDir: {}
                 - name: sandbox-root-ca                        # added
                   configMap:
                     name: sandbox-root-ca
   ```

3. `helm upgrade` with your values. Only **new** sandboxes pick the template
   up; sandboxes are ephemeral, so the fleet converges on its own (or delete
   the running ones to force it).

`NODE_EXTRA_CA_CERTS` **extends** the default trust store and covers the AI
agent and Node tooling -- the paths Teable itself depends on. If user code
inside sandboxes also reaches your internal hosts with Python or curl/git,
additionally set:

```yaml
                     - name: SSL_CERT_FILE
                       value: /etc/ssl/private-ca/root-ca.crt
                     - name: REQUESTS_CA_BUNDLE
                       value: /etc/ssl/private-ca/root-ca.crt
                     - name: CURL_CA_BUNDLE
                       value: /etc/ssl/private-ca/root-ca.crt
                     - name: GIT_SSL_CAINFO
                       value: /etc/ssl/private-ca/root-ca.crt
```

Unlike `NODE_EXTRA_CA_CERTS`, these **replace** the default store instead of
extending it. If sandboxes must also reach the public internet, point them at
a full bundle (public roots plus your CA appended) instead of the single root
certificate.

## Option B (trial only): disable TLS verification

Same template override, but instead of the mount:

```yaml
                   env:
                     - name: NODE_TLS_REJECT_UNAUTHORIZED
                       value: "0"
```

This disables certificate verification for **all** Node TLS inside the
sandbox, agent included, and it is Node-only (Python and curl need their own
switches). Acceptable for a short trial on an isolated network; do not run
production this way -- prefer Option A.

## The Docker path

Usually not needed: `local` mode serves plain HTTP, and `server` mode issues
**publicly trusted** certificates via ACME DNS-01 -- which works on intranet
servers too, because the certificate is proven through a DNS record and the
machine never needs to be reachable from the internet.

If your sandboxes still face a private CA (typically a corporate TLS
terminator in front of the stack), two `.env` switches cover it (both need
`opensandbox-server` >= `v0.2.0-fix6`):

```bash
# Proper trust: mount your root CA into every sandbox + NODE_EXTRA_CA_CERTS
SANDBOX_CA_CERT_FILE=/opt/teable/root-ca.crt   # absolute host path, PEM

# Or, for short trials only: disable Node TLS verification inside sandboxes
SANDBOX_TLS_NO_VERIFY=1
```

Then re-run `./apply.sh server [--with-app]` and
`docker compose up -d opensandbox-server` -- new sandboxes pick it up. The
same appended-vs-replaced caveat as Option A applies if you add more trust
variables by editing `opensandbox.toml` (`[docker] sandbox_env`).
