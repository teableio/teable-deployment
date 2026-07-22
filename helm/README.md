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
  -f my-values.yaml
./helm/doctor.sh          # all green = deployed
```

The first install pulls images, issues certificates and runs database
migrations — give it a few minutes (`kubectl get pods -n opensandbox-system -w`
to watch). Do **not** add `--wait`: the storage buckets are created by a
post-install hook, which Helm only runs *after* `--wait` would return, while
the app cannot become ready *without* them — `--wait` deadlocks and times out
on a first install.

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

## Storage

The git-registry and VictoriaMetrics data PVCs support three modes, per
component (`gitRegistry.persistence` / `infraService.victoriaMetrics.persistentVolumeClaim`):

- **Dynamic (default):** leave `volumeName` and `existingClaim` blank; set
  `storageClassName` or leave it blank for the cluster default StorageClass.
- **Static PV binding:** set `volumeName` to a pre-provisioned PV and keep
  `storageClassName: ""` — the empty string is emitted on the PVC so the
  dynamic provisioner stays out of the way. Adjust `accessModes` to match the PV.
- **Bring your own PVC:** set `existingClaim` to a PVC you created beforehand;
  the chart then creates no PVC at all. Use this when PVC lifecycle is owned by
  a storage/cluster admin rather than the deploy account.

Both PVCs carry `helm.sh/resource-policy: keep`, so `helm uninstall` leaves
the data in place; delete the PVC explicitly to discard it.

## External gateway entry (no ingress controller)

If an external SLB/nginx terminates TLS in front of the cluster, set:

```yaml
global:
  entry:
    mode: external-nginx
```

The chart then renders no Ingress or Certificate objects (the ingress-nginx
and cert-manager prerequisites no longer apply) and renders a
`<release>-nginx-routes` ConfigMap instead — the host/path → Service routing
contract for your gateway team, including the entry requirements (preserve
Host, no path rewrite, longest-prefix path matching, WebSocket, long
timeouts). The ConfigMap declares routes; it does not configure the external
gateway by itself.

This mode requires `appRuntime.ingress.mode: gateway` and the chart refuses
to render otherwise: the default `dynamic` mode creates per-app Ingress
objects at runtime, which nothing would serve without an ingress controller.

## Restricted deploy accounts

If your deploy account only holds namespace-scoped permissions, have a cluster
admin apply the pre-rendered cluster half first:

```bash
kubectl apply -f helm/teable-infra/manifests/crds.yaml
kubectl apply -f helm/teable-infra/manifests/cluster-rbac.yaml
```

(Both are pre-rendered from the default profile for release name `teable` in
namespace `opensandbox-system` — the quick-start defaults. Installing under a
different release name or namespace, or enabling components that are off by
default (e.g. `registryGc`)? Re-render the cluster half from the chart with
`rbac.namespaceScope.create: false` set on infra-service and
opensandbox-server, and apply the resulting ClusterRole/ClusterRoleBinding
documents.)

Then install as the deploy account with:

```yaml
# Namespaces are cluster-scoped: have the admin create the release namespace
# plus the two runtime namespaces below, and keep the chart from rendering them.
sandboxNamespace:
  create: false      # admin pre-creates teable-sandbox
appRuntime:
  createNamespace: false   # admin pre-creates the app-deploy namespace
infraService:
  rbac:
    clusterScope:
      create: false   # cluster admin pre-provisioned the ClusterRole/Binding
    knativeCompat: false   # only if the account cannot grant serving.knative.dev
registryGc:
  rbac:
    clusterScope:
      create: false
opensandbox-server:
  server:
    rbac:
      clusterScope:
        create: false
    gateway:
      rbac:
        clusterScope:
          create: false
opensandbox-controller:
  rbac:
    clusterScope:
      create: false   # keeps the namespaced leader-election Role/RoleBinding
  crds:
    install: false
```

The chart then renders only namespace-scoped RBAC (ServiceAccounts, Roles,
RoleBindings) alongside the workloads; the workloads keep referencing the same
ServiceAccount names either way. Combine with the Storage section
(`existingClaim` against admin-provisioned PVs) and the external gateway entry
mode above when those restrictions apply too.

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
