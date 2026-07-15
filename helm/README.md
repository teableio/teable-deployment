# Teable on Kubernetes (Helm)

The full Teable platform on an existing Kubernetes cluster: the app, its
datastores, and the AI runtime plane — everything self-hosted inside your
cluster, driven by one umbrella chart.

## Prerequisites

- An ingress-nginx controller with a public IP
- cert-manager (or bring your own TLS certificates — see the values example)
- A default StorageClass (or set the `storageClassName` fields per component)
- One base domain with DNS control -- typically a subdomain of yours (e.g.
  `teable.example.com`): four records point at your ingress controller
  (listed in the values example), all derived from that single domain

## Quick start

```bash
cp helm/examples/values.example.yaml my-values.yaml   # set global.baseDomain, read the TLS section
helm dependency build helm/teable-infra
helm install teable helm/teable-infra -n opensandbox-system --create-namespace \
  -f my-values.yaml --wait --timeout 15m
./helm/doctor.sh          # all green = deployed
```

`--wait` holds until every workload is ready — the first install pulls images
and runs database migrations, so give it a few minutes.

Open `https://<baseDomain>` and register the first account (it becomes the
admin). The infra console is at `https://infra.<baseDomain>`.

## If you know Kubernetes but not Helm

Helm here plays the role docker compose plays on the Docker path:

| docker compose | Helm |
|---|---|
| `docker compose up -d` | `helm install teable helm/teable-infra -f my-values.yaml ...` |
| edit `.env`, `up -d` again | edit `my-values.yaml`, `helm upgrade teable helm/teable-infra -f my-values.yaml` |
| `docker compose down` | `helm uninstall teable` (PVCs and their data survive) |

Everything an install creates is readable up front in
[`teable-infra/manifests/crds.yaml`](teable-infra/manifests/crds.yaml) and
[`manifests/default.yaml`](teable-infra/manifests/default.yaml) — read them
before installing, or diff them between releases before upgrading.

Applying those files directly with kubectl also works as an escape hatch:
create the namespace first (`kubectl create namespace opensandbox-system`),
replace the placeholder Secret values with your own random material, apply
`crds.yaml` then `default.yaml` — and accept that you lose Helm's release
management (upgrades become re-applies).

## Pinning and upgrading images

[`examples/images.values.yaml`](examples/images.values.yaml) carries the image
keys of the release and nothing else:

```bash
helm upgrade teable helm/teable-infra -n opensandbox-system \
  --reuse-values -f helm/examples/images.values.yaml
```

Prefer this over `kubectl set image`: it updates the same containers **and**
keeps the Helm release in sync, so the next upgrade will not silently roll
your images back. (On Helm 4 add `--server-side=true --force-conflicts` if
images were previously swapped by hand.)

## Health and drift

```bash
./helm/doctor.sh [release] [namespace]     # defaults: teable opensandbox-system
```

Checks that every workload is ready, certificates are issued, and that the
images running in the cluster still match what the Helm release installed —
with the exact commands to reconcile if they drifted. It also compares what is
running against the platform release manifest (`versions.yaml`) and reports one
of three states: compatible, upgrade the Teable app, or an unknown (unverified)
component combination.

## Private CA / self-signed certificates

If your Teable hosts serve certificates from a private/corporate CA, sandboxes
reject the callbacks (AI sessions fail to start, builds fail on `git push`)
until they trust that CA — see [`private-ca.md`](private-ca.md) for the sandbox
template override that mounts your root CA.

## When something fails

See [`../TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) — the Kubernetes section
covers the failure modes we have actually hit, each with the first place to
look.
