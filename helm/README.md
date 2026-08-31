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

## Sandbox capacity

How many sandboxes fit on a node is derived from one value —
`global.sandboxScheduling.memoryRequest`, the "price of a seat" the scheduler
subtracts from node allocatable memory. Set too low it oversubscribes nodes and
sessions get OOM-killed; set too high the cluster refuses new sandboxes while
nodes look idle. Start at `1300Mi` for a mixed AI-session and app-build
workload, and re-derive it if yours differs — see
[`sandbox-capacity.md`](sandbox-capacity.md) for the sizing method, a worked
per-node example, and the related limit/backpressure knobs.

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
./helm/doctor.sh --from vYYYY.M.N          # + migrations pending since that release
```

Checks that every workload is ready, certificates are issued, and that the
images running in the cluster still match what the Helm release installed —
with the exact commands to reconcile if they drifted. It also compares what is
running against the platform release manifest (`versions.yaml`) and reports one
of three states: compatible, upgrade the Teable app, or an unknown (unverified)
component combination. Upgrading from an older platform release, pass
`--from <the release you run today>`: it reads `migrationCatalog` from
`versions.yaml` and prints the migrations your install still has to run, in
order (see also "Upgrading across releases" in `VERSIONS.md`).

## Hardening sandboxes

Sandboxes run as root with an unconfined seccomp profile by default, because
the sandbox entrypoint historically fixed up volume ownership at startup. Two
switches tighten that; both only affect **new** sandboxes, and both override
the matching fields of a `batchSandboxTemplate` you provide:

```yaml
global:
  sandboxSecurity:
    seccompProfile: RuntimeDefault   # replaces the default Unconfined profile
    nonRoot:
      enabled: true                  # uid/gid 1000, no privilege escalation, all capabilities dropped
```

`seccompProfile` is safe to flip on its own. `nonRoot` needs preparation:

- It requires `opensandbox-server` >= `v0.2.0-fix7` and `opensandbox-execd` >=
  `v1.0.19-fix3` -- the versions pinned by this release. With an older execd
  every command inside a non-root sandbox fails with `operation not permitted`.
  The identity is fixed at uid/gid 1000, matching the agent image; a different
  uid would hit the same failure.
- Agents can no longer install **system** packages (`sudo apt-get install`);
  user-space installs (`uv`, `pip`, `npm`, `pnpm`) are unaffected, so
  pre-install the system packages your workloads need in the sandbox image.
- On a **shared** sandbox volume (one PVC mounted into every sandbox under
  per-sandbox `subPath`s) two things need handling -- see below.

Rolling back means setting both switches back **and** pinning the previous
image versions -- the template and the execd version are a matched pair.

### Shared sandbox volumes

Skip this if your sandboxes only use the default `emptyDir` workspace.

Existing files written by earlier root sandboxes stay root-owned and become
read-only. Chown them once, from any pod that mounts the volume:

```bash
find /mnt/agent-data -uid 0 | head          # what would break
chown -R 1000:1000 /mnt/agent-data/teable   # one-time migration
```

That covers what already exists. New `subPath` directories are created by the
kubelet as `root:root` whenever a new user gets their first sandbox, so an
unprivileged sandbox could not write them either. The server pre-creates them
instead -- mount the same PVC into the server and declare the mapping:

```yaml
opensandbox-server:
  server:
    volumes:
      - name: agent-data
        persistentVolumeClaim:
          claimName: <your sandbox PVC>
    volumeMounts:
      - name: agent-data
        mountPath: /mnt/agent-data
  configToml: |
    ...                                   # keep the rest of your config
    [kubernetes.volume_subpath_precreate]
    uid = 1000
    gid = 1000

    [kubernetes.volume_subpath_precreate.mounts]
    # sandbox-side claim name = where the server mounts that same volume
    "<your sandbox PVC>" = "/mnt/agent-data"
```

The server runs in the control-plane namespace and creates each directory with
the right owner before starting the sandbox; read-only mounts are skipped. Get
the claim name wrong and pre-creation is silently skipped -- verify with a fresh
user's first sandbox, not an existing one.

#### Storage owned by a different identity

Some storage platforms mandate their own owner uid on shared volumes and
disallow `chown`, while the sandbox identity is fixed at 1000. Do not try to
align the two uids -- either direction breaks: a sandbox uid other than 1000
fails every command (the execd credential match), and re-owning platform
storage violates its policy. Bridge them with a group instead. With `1001` as
the storage-owner identity, run the server *as that identity* and have it
create directories group-writable:

```yaml
opensandbox-server:
  server:
    podSecurityContext: {runAsUser: 1001, runAsGroup: 1001, runAsNonRoot: true}
    containerPort: 8080     # non-root cannot bind 80; mirror it in `[server] port`
    volumes:                # the same PVC mount as above -- pre-creation needs it
      - name: agent-data
        persistentVolumeClaim:
          claimName: <your sandbox PVC>
    volumeMounts:
      - name: agent-data
        mountPath: /mnt/agent-data
  configToml: |
    [server]
    port = 8080
    ...                     # keep the rest of your config

    # The metadata store defaults to a path under HOME, and a non-root uid
    # has no writable HOME on the stock image -- without this the server
    # exits at startup before serving anything.
    [store]
    path = "/tmp/opensandbox/opensandbox.db"

    [kubernetes.volume_subpath_precreate]
    uid = 1001              # the storage owner, not the sandbox uid
    gid = 1001
    dir_mode = 0o2775       # group-write + setgid; needs server >= v0.2.0-fix9

    [kubernetes.volume_subpath_precreate.mounts]
    "<your sandbox PVC>" = "/mnt/agent-data"
```

then give sandboxes that group: add `supplementalGroups: [1001]` to the
**pod-level** securityContext of your `batchSandboxTemplate` (the `nonRoot`
switch preserves it; container-level securityContext has no such field).

Directories come out `1001:1001 drwxrwsr-x`: the server, already being the
owner, never calls chown, and sandboxes (uid 1000) write through the
supplementary group. On engines older than fix9 use `dir_mode = 0o775` --
same write bridge, minus setgid group inheritance on new content. Pre-creation
sets mode only on directories it creates, so directories that already exist
with the wrong mode or owner must be fixed once by hand (or removed and left
for the server to recreate).

## AI Agent skills

Skills live as files, not as database rows: the app writes them through the
Infra Service object API and sandboxes read them back from a volume. Both
halves have to be in place, and a default install has neither.

**Turn the object API on.** `infraService.s3Compat.enabled` (default `false`)
serves `/s3/<bucket>/<key>` off the `infraService.fileBrowser` volume, and the
app writes the `teable-agent` bucket. While it -- or `fileBrowser.enabled` --
is off, creating or importing a skill fails with a 404 from the Infra API.
`fileBrowser.readOnly` also has to stay `false`, or reads keep succeeding while
every write fails with a 500.

**Give both sides the same files.** Infra Service writes to
`<fileBrowser.mountPath>/teable/<scope>/<id>/skills/`, and every sandbox mounts
those directories read-only from its own volume: the principal's own skills at
`~/.teable/skills/user` (that segment is fixed, whether the principal is a user,
an app or a bot), shared ones at `~/.teable/skills/base/<baseId>` and
`~/.teable/skills/space/<spaceId>`, instance-wide ones at
`~/.teable/skills/system`. Those mounts come from a *different*
PersistentVolumeClaim -- Infra Service runs in the control-plane namespace,
sandboxes in the sandbox namespace, and a PVC cannot be shared across
namespaces -- so both claims have to resolve to one shared filesystem.

Turn on only the first half and the failure is silent: the skill saves, the
sandbox mount succeeds, the directory is empty, and the agent behaves as if no
skill existed. There is no fallback delivery path. Leaving both off at least
keeps the feature visibly unavailable.

That same mount is how the Infra console reads sandbox-written data -- the file
browser and the AI task view -- so a shared filesystem is worth wiring even if
you never use skills.

### One share, two PV/PVC pairs

Any RWX-capable shared filesystem does the job -- NFS, AWS EFS, Azure Files,
CephFS, Alibaba NAS, JuiceFS. The shape never changes: **two statically
provisioned PV/PVC pairs pointing at the same export.**

- Dynamic provisioning cannot express this, even with an RWX StorageClass: each
  PVC receives its own volume or its own generated subdirectory, so the two
  never meet.
- The two PVs may differ in name, capacity and mount options. Only the share --
  and the directory inside it -- has to be identical.
- Keep both claim names. The sandbox-side one is fixed at `teable-agent-juicefs`
  by the app (a historical name; the storage behind it is your choice), and the
  control-plane one keeps the chart default `teable-agent-juicefs-monitor`,
  which the Infra console health check looks up by name. Bind them to your
  storage with `volumeName`, never by renaming.
- Pre-create the sandbox-side claim. If it is missing when the first sandbox
  starts, the sandbox engine provisions one under that name from the default
  StorageClass, and that volume is not the one Infra Service writes to.
- Do this at install time. A PVC is immutable once created, so an install that
  already has these claims needs them deleted and recreated -- move the data off
  first, and expect `pvc-protection` to hold the delete until every pod using
  the claim is gone.

An NFS example. You create three objects -- both PVs and the sandbox-side claim
-- and leave the control-plane claim to the chart:

```yaml
# --- the volume Infra Service mounts ---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: teable-agent-control
spec:
  accessModes: [ReadWriteMany]
  capacity:
    storage: 1Ti
  nfs:
    server: nfs.internal.example.com
    path: /exports/teable-agent      # the same export and directory on both sides
  persistentVolumeReclaimPolicy: Retain
---
# --- the volume every sandbox mounts ---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: teable-agent-sandbox
spec:
  accessModes: [ReadWriteMany]
  capacity:
    storage: 1Ti
  nfs:
    server: nfs.internal.example.com
    path: /exports/teable-agent      # identical to the PV above
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: teable-agent-juicefs         # fixed name, see above
  namespace: teable-sandbox
spec:
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 1Ti
  storageClassName: ""
  volumeName: teable-agent-sandbox
```

The chart keeps its own claim name and binds it to the first PV:

```yaml
infraService:
  fileBrowser:
    enabled: true
    persistentVolumeClaim:
      create: true                   # keep the chart owning this claim
      accessModes: [ReadWriteMany]
      storage: 1Ti
      storageClassName: ""
      volumeName: teable-agent-control
  s3Compat:
    enabled: true
```

Verify end to end: create one skill in the UI, then look at both sides.

```bash
kubectl exec deploy/<release>-infra-service -n opensandbox-system -- \
  ls /mnt/juicefs/teable                     # scope directories show up here
kubectl get pods -n teable-sandbox           # pick a running sandbox pod
kubectl exec <sandbox-pod> -n teable-sandbox -- \
  ls /home/agent/.teable/skills/user         # the same skill, read-only
```

`doctor.sh` in this directory probes the same contract automatically whenever
`s3Compat.enabled` is on: the `/s3` endpoint end to end, both claims, and --
when a sandbox pod is running -- the shared-filesystem property itself.

A shared volume also brings the directory-ownership handling described under
[Shared sandbox volumes](#shared-sandbox-volumes) into play once you turn on the
non-root sandbox switches.

## Private CA / self-signed certificates

If your Teable hosts serve certificates from a private/corporate CA, sandboxes
reject the callbacks (AI sessions fail to start, builds fail on `git push`)
until they trust that CA — see [`private-ca.md`](private-ca.md) for the sandbox
template override that mounts your root CA.

## When something fails

See [`../TROUBLESHOOTING.md`](../TROUBLESHOOTING.md) — the Kubernetes section
covers the failure modes we have actually hit, each with the first place to
look.
