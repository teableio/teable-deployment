# Teable Self-Host Deployment

Run the full Teable platform on your own infrastructure: the Teable app plus its
AI runtime plane — sandboxes, the app builder and app deployments.

Just want to try Teable (AI Spreadsheet, APP Builder, AI Workflows)? Use
[teable.ai](https://teable.ai) — nothing to deploy.

## Pick your path

Two independent paths. Docker users never need Kubernetes concepts, and
Kubernetes users never need to read the compose files.

|  | Docker all-in-one | Kubernetes (Helm) |
|---|---|---|
| Best for | first full deployment; everything on one machine | an existing cluster; production isolation and scaling |
| Machine / cluster | 1 Docker machine (see `VERSIONS.md` for sizing) | a production K8s cluster (see `VERSIONS.md` for sizing) |
| Sandbox node pool | not needed | recommended, isolates sandbox load |
| Domain & DNS | local: none (`*.localhost`) · cloud: one managed domain | one managed domain with DNS control |
| Start here | [`docker/all-in-one/`](docker/all-in-one/README.md) | below |

## Kubernetes quick start

Prerequisites: an ingress-nginx controller with a public IP, cert-manager (or
bring your own TLS certificates), a default StorageClass, and DNS records for
the six entries listed in the example values file — all derived from one root
domain.

```bash
cp helm/examples/values.example.yaml my-values.yaml   # set global.baseDomain, read the TLS section
helm dependency build helm/teable-infra
helm install teable helm/teable-infra -n opensandbox-system --create-namespace \
  -f my-values.yaml --wait --timeout 15m
./helm/doctor.sh          # all green = deployed
```

`--wait` holds until every workload is ready (first install pulls images and
runs database migrations, so give it a few minutes).

Open `https://<baseDomain>` and register the first account (it becomes the
admin). The infra console is at `https://infra.<baseDomain>`.

If you know Kubernetes but not Helm: Helm here plays the role docker compose
plays on the Docker path — `helm install` ↔ `up`, edit values +
`helm upgrade -f` ↔ edit config + `up`, `helm uninstall` ↔ `down`. Everything
an install creates is readable up front in
`helm/teable-infra/manifests/crds.yaml` and `manifests/default.yaml`; diff them
between releases before upgrading. Applying those files directly with kubectl
also works as an escape hatch — create the namespace first
(`kubectl create namespace opensandbox-system`), replace the placeholder
Secret values, and accept the cost of losing Helm's release management.

To pin or upgrade image versions, apply
[`helm/examples/images.values.yaml`](helm/examples/images.values.yaml) — it
carries the image keys and nothing else.

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
[`migration/basic-to-full-featured.md`](migration/basic-to-full-featured.md).

## Versions

Each release of this repository pins a compatible set of images — see
[`VERSIONS.md`](VERSIONS.md). Docker deployments default to `latest` and just
work; production Kubernetes deployments should pin versions and upgrade
deliberately.
