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

### AI sessions fail right after starting: `self-signed certificate in certificate chain`

The stack is healthy and the UI works, but sandboxes reject the callback to
your Teable/infra hosts (`SELF_SIGNED_CERT_IN_CHAIN`,
`UNABLE_TO_VERIFY_LEAF_SIGNATURE`, or builds failing on `git push` with
`SSL certificate problem`). Your hosts serve certificates from a private CA
that the sandboxes do not trust — mount the root CA into the sandbox template:
see [`helm/private-ca.md`](helm/private-ca.md).

## Docker all-in-one

`./doctor.sh` covers the mainline failures (entry routing, `/v1` split,
storage, sandbox engine). Two frequent ones:

### Browser preview URLs do not resolve (server)

The `*.sandbox.<BASE_DOMAIN>` and `*.app.<BASE_DOMAIN>` wildcard DNS records
are missing — both must point at the machine, DNS-only (no proxy).

### Certificate issuance fails on first start (server)

`CLOUDFLARE_API_TOKEN` lacks the Zone/DNS edit permission, or the DNS records
point somewhere else. Check `docker compose logs caddy` for the ACME error.

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
