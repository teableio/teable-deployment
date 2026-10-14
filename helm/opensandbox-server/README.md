# opensandbox-server Helm Chart

OpenSandbox Lifecycle API server: provides sandbox create/delete and other lifecycle APIs, typically used with BatchSandbox/Pool on Kubernetes.

## Prerequisites

- Kubernetes 1.21.1+
- Helm 3.0+
- OpenSandbox CRDs installed (deploy opensandbox-controller first)

## Install

> **Note**: the deployment namespace is controlled by the chart's `namespaceOverride` value
> (default `opensandbox-system`), not by the `helm -n` flag.

```bash
# Server only (default namespace opensandbox-system)
helm install opensandbox-server helm/opensandbox-server \
  --namespace opensandbox-system \
  --create-namespace

# With custom image and config
helm install opensandbox-server helm/opensandbox-server \
  --set server.image.repository=your-registry/opensandbox/server \
  --set server.image.tag=v0.1.0 \
  --namespace opensandbox-system \
  --create-namespace
```

### Deploy server and ingress-gateway together

To run both the Lifecycle API server and the ingress gateway (components/ingress) in one release, set `server.gateway.enabled=true`. The chart will deploy the server and the gateway (Deployment, Service, RBAC), and write server config `[ingress] mode = "gateway"` so the server returns the correct gateway address to clients.

```bash
helm install opensandbox-server helm/opensandbox-server \
  --namespace opensandbox-system \
  --create-namespace \
  --set server.gateway.enabled=true \
  --set server.gateway.host=gateway.example.com
```

Optional: override gateway image, replicas, or resources (see `server.gateway.*` in Configuration).

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `server.image.repository` | Server image repository | `ghcr.io/teableio/opensandbox-server` |
| `server.image.tag` | Server image tag | `v0.2.0-fix11` |
| `server.replicaCount` | Server replicas | `2` |
| `server.resources` | CPU/memory requests and limits | See values.yaml |
| `namespaceOverride` | Deployment namespace | `opensandbox-system` |
| `configToml` | config.toml content ([ingress] block generated from server.gateway) | See values.yaml |
| `server.gateway.enabled` | When true: set server config to gateway and deploy components/ingress gateway | `false` |
| `server.gateway.host` | config `gateway.address` (address returned to clients) | `opensandbox.example.com` |
| `server.gateway.gatewayRouteMode` | server config and gateway route mode (header/uri) | `header` |
| `server.gateway.secureAccess.keys` | OSEP-0011 signing keys `[{key_id, key}]` shared by server and gateway (`key_id`: one char `[0-9a-z]`, `key`: base64); explicit keys always win | `[]` |
| `server.gateway.secureAccess.activeKey` | Key id used for new signatures (explicit keys only) | first `key_id` |
| `server.gateway.secureAccess.autoGenerate` | With the gateway enabled and no `keys`: generate one key at install and reuse it on upgrade (Helm `lookup`) | `false` |
| `server.gateway.*` | Gateway image, replicas, port, dataplaneNamespace, providerType, resources | See values.yaml |

Versioning note:

- `server.image.tag` is pinned in values.yaml (currently `v0.2.0-fix11`); it only falls
  back to the chart `appVersion` if you set it to an empty string.
- The chart package `version` and the image tag are intentionally separate. A server
  release branch or tag does not automatically imply a new Helm chart package version.
- If you want the chart to deploy a specific server release, override
  `server.image.tag` explicitly or consume a Helm package release whose chart
  version was published for that purpose.

**Gateway**: When `server.gateway.enabled=true`, the chart writes `[ingress] mode = "gateway"` in config.toml and deploys **components/ingress** Deployment/Service/RBAC; gateway `--mode` matches config. External access must be configured separately.

**Secure access (OSEP-0011)**: with signing keys in effect (`server.gateway.secureAccess.keys`, or `autoGenerate`), the server config gains `[ingress.secure_access]` and is stored as a Secret, and the gateway reads `--secure-access-keys` from the `opensandbox-ingress-gateway-secure-access` Secret. Keys alone enforce nothing: sandboxes created with `secureAccess: true` then only answer signed links or their access token. `autoGenerate` keeps the generated key in that Secret and reads it back with `lookup`, so renderers without cluster access (`helm template`, `--dry-run`, Argo CD) get a new key on every render; use explicit `keys` there. To rotate a generated key, delete the Secret and upgrade.

Set `[kubernetes].namespace` in config for the sandbox workload namespace. Override `api_key` via Secret or values in production.

## Upgrade and uninstall

```bash
helm upgrade opensandbox-server helm/opensandbox-server -n opensandbox-system
helm uninstall opensandbox-server -n opensandbox-system
```

## References

- [OpenSandbox](https://github.com/alibaba/OpenSandbox)
