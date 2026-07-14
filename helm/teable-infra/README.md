# teable-infra Helm Chart

Umbrella chart for the Teable Infra runtime. A bare install deploys the sandbox engine only; every
other component ships disabled and is opted into via values.

## What this chart deploys

Always (as sub-charts):

- **opensandbox-controller** -- Kubernetes operator managing the `Pool`, `BatchSandbox`, and
  `SandboxSnapshot` CRDs (resource pooling, batch delivery, pause/resume).
- **opensandbox-server** -- lifecycle REST API for creating and managing sandboxes, with an
  optional ingress gateway.

Optional umbrella components, each behind its own `enabled` flag (all `false` by default, so a
bare install deploys only the sandbox engine):

| Component | Values key | Purpose |
|-----------|------------|---------|
| Infra Service | `infraService.enabled` | Control-plane API: monitoring, file browser, sandbox and App Runtime orchestration |
| Git Registry | `gitRegistry.enabled` | Git-over-HTTP registry for App Builder sources |
| App Runtime | `appRuntime.enabled` | Namespace, quotas, RBAC, and ingress for deployed apps |
| Image Preheater | `imagePreheater.enabled` | DaemonSet that pre-pulls sandbox images onto nodes |
| Runtime NetworkPolicy | `runtimeNetworkPolicy.enabled` | Egress policies for the sandbox and app namespaces |
| Registry GC | `registryGc.enabled` | CronJob pruning `ci-*` tags of an existing docker-registry |
| Storage Autoscaler | `storageAutoscaler.enabled` | PVC autoscaling policies (Alibaba Cloud ACK only) |

Enable a component in your values file, for example:

```yaml
infraService:
  enabled: true
  image: your-registry/infra-service:TAG

appRuntime:
  enabled: true
```

## Prerequisites

- Kubernetes 1.21.1+ and Helm 3.
- [cert-manager](https://cert-manager.io) with a `ClusterIssuer` if you use the TLS/certificate
  examples (the defaults reference an issuer named `letsencrypt-dns`).
- An existing Secret `infra-service-session` (session signing secret) and the
  `opensandbox-api-key` Secret in the control-plane namespace when `infraService` is enabled.
- The sandbox dataplane namespace (default `teable-sandbox`, see the server config
  `[kubernetes] namespace`) must exist before the first sandbox is created; the chart does not
  create it.

## Quick start

```bash
# From the repository root (the chart ships at helm/teable-infra)
helm dependency build helm/teable-infra

helm install opensandbox helm/teable-infra \
  --namespace opensandbox-system \
  --create-namespace \
  -f your-values.yaml
```

> **Namespaces**: workload namespaces are controlled by `namespaceOverride`-style values
> (for example `infraService.namespaceOverride`, the sub-charts' `namespaceOverride`,
> `appRuntime.namespace`), not by the `helm -n` flag. The `-n` flag only sets where Helm stores
> release metadata.

## Values highlights

| Key | Default | Description |
|-----|---------|-------------|
| `opensandbox-controller.controller.*` | see values.yaml | Controller image, replicas, snapshot settings |
| `opensandbox-server.server.*` | see values.yaml | Server image, replicas, gateway, config.toml |
| `infraService.enabled` | `false` | Deploy the Infra Service control plane (`infraService.image` required) |
| `gitRegistry.enabled` | `false` | Deploy the Git Registry (`gitRegistry.publicUrl` required) |
| `appRuntime.enabled` | `false` | Provision the app namespace, quotas, RBAC, and ingress |
| `imagePreheater.enabled` | `false` | Pre-pull sandbox images on nodes |
| `runtimeNetworkPolicy.enabled` | `false` | Apply egress NetworkPolicies to runtime namespaces |
| `registryGc.enabled` | `false` | Weekly docker-registry GC (requires an existing registry) |
| `storageAutoscaler.enabled` | `false` | ACK-specific PVC autoscaling policies |
| `global` | `{}` | Optional GKE integration keys (`projectId`, `gkeLocation`, `gkeClusterName`) |

Sub-chart values are documented in the sub-chart READMEs
([controller](../opensandbox-controller/README.md), [server](../opensandbox-server/README.md))
and can be overridden under the `opensandbox-controller:` and `opensandbox-server:` keys.

## Upgrade and uninstall

```bash
helm dependency build helm/teable-infra
helm upgrade opensandbox helm/teable-infra -n opensandbox-system -f your-values.yaml

helm uninstall opensandbox -n opensandbox-system
```

CRDs are kept on uninstall by default. To remove them:

```bash
kubectl delete crd batchsandboxes.sandbox.opensandbox.io
kubectl delete crd pools.sandbox.opensandbox.io
kubectl delete crd sandboxsnapshots.sandbox.opensandbox.io
```

## License

Apache 2.0
