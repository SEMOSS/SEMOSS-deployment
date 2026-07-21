# SEMOSS + Postgres + MinIO + Redis/Sentinel (HA)

A self-contained stack where the coordination layer is **highly available**: Redis
with **Sentinel automatic failover** (master + 2 replicas + 3 Sentinels). Postgres
and MinIO still run single-instance in-cluster. For the simpler single-node
version, see [`semoss-with-postgres-minio-redis`](../semoss-with-postgres-minio-redis).

## What's in here

| File(s) | Purpose |
|:--------|:--------|
| `namespace.yml` | Creates the `semoss` namespace |
| `postgres-deployment.yml` / `postgres-service.yml` / `postgres-init-configmap.yml` | Postgres (`Deployment` + PVC + `Service`); init `ConfigMap` creates the 8 SEMOSS databases |
| `minio-statefulset.yml` / `minio-service.yml` / `minio-createbucket-job.yml` | MinIO object store + a `Job` that creates the `semoss` bucket |
| `redis-statefulset.yml` | Redis **data plane** — 1 master + 2 replicas (`StatefulSet`, persistent) |
| `redis-headless-service.yml` | Stable per-pod DNS for the Redis nodes |
| `redis-config-configmap.yml` | Redis config + startup script that discovers the master (via Sentinel, else bootstraps redis-0) |
| `sentinel-statefulset.yml` | 3 **Sentinels** — the control plane that monitors the master and promotes a replica on failure |
| `redis-sentinel-service.yml` | Headless service — stable per-pod DNS for the Sentinels (listed in `REDIS_SENTINEL_NODES`) |
| `sentinel-config-configmap.yml` | Sentinel startup script (monitors master `semossmaster`, quorum 2) |
| `semoss-config-and-secrets.yml` | SEMOSS config/secrets; Sentinel topology (`REDIS_SENTINEL_ENABLED`, `REDIS_MASTER_NAME`, `REDIS_SENTINEL_NODES`) |
| `semoss-deployment.yml` / `semoss-service.yml` | SEMOSS `Deployment` (initContainers wait for Postgres/MinIO/Sentinel) + ClusterIP `Service` |
| `kustomization.yaml` | Ties it all together for `kubectl apply -k .` |

> **Redis vs. Sentinel** — both use the `redis:7` image (it ships both binaries).
> Redis (`redis-server`, port 6379) stores the data; Sentinel (`redis-sentinel`,
> port 26379) stores nothing and just supervises failover. SEMOSS supports
> Sentinel deployments, so it connects to the Sentinels and follows the master
> itself — no proxy needed.

## Demo credentials (not for production)

- Postgres: `myuser` / `mypassword` — databases `security`, `localmaster`, `scheduler`, `themes`, `user_tracking`, `model_logs`, `prompt_hub`, `audit_logs`
- MinIO: `minioadmin` / `minioadmin` — bucket `semoss`, endpoint `http://minio:9000`
- Redis / Sentinel: no auth in this example

## Common settings to adjust

Review these before deploying — in `semoss-config-and-secrets.yml` (and `semoss-deployment.yml` for sizing):

| Setting | Why you'd change it |
|:--------|:--------------------|
| `MONOLITH_COOKIE_SET_SECURE` | Set to `"false"` here so login works over plain **HTTP** (port-forward). Change to `"true"` when serving SEMOSS over HTTPS (an HTTPS-only cookie won't be sent over HTTP). |
| `REDIRECT` | The address your browser uses to reach SEMOSS. Defaults to `http://localhost:8080/#/` (port-forward); change it if you access via a node IP, NodePort, or ingress. |
| SEMOSS `resources:` | CPU/memory requests & limits in `semoss-deployment.yml` — raise or lower to fit your node. |

## Deploy

```
kubectl apply -k .
kubectl -n semoss get pods -w      # redis-0/1/2 + redis-sentinel-0/1/2, then semoss
```

The pod is ready when the readiness probe (`/Monolith/health/ready`) reports `READY` — watch for it to become `Ready` in the pod list above before accessing SEMOSS.

## Access (port-forward)

SEMOSS is exposed only as a `ClusterIP` service (no ingress). Reach it from your
laptop by port-forwarding:

```
kubectl -n semoss port-forward svc/semoss-service 8080:8080
```

Then open:

| What | URL |
|:-----|:----|
| Health / readiness check | http://localhost:8080/Monolith/health/ready (READY=200) |
| SEMOSS UI | http://localhost:8080/SemossWeb/packages/client/dist/ |

> Use port **8080** (`8080:8080`): the config's `REDIRECT` is `http://localhost:8080/#/`.
> For a real hostname/TLS setup instead of port-forward, see [`../ingress`](../ingress).

## Test failover (optional)

```
kubectl -n semoss delete pod redis-0          # kill the master
kubectl -n semoss logs redis-sentinel-0       # watch a Sentinel promote a replica
```

SEMOSS reconnects to the new master via the Sentinels automatically.

## Cleanup

```
kubectl delete -k .                      # removes everything except PVCs
kubectl -n semoss delete pvc --all       # also delete the persistent volumes
```
