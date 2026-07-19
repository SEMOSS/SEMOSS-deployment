# SEMOSS example stacks

Self-contained, fully-filled-in Kubernetes examples that stand up SEMOSS together
with all of its dependencies in-cluster — no external database or storage required.
They differ only in the cluster-coordination backend. **Each folder has its own
README** with a component breakdown and the port-forward access step.

| Example | Coordination backend | Contents |
|:--------|:---------------------|:---------|
| [`semoss-with-postgres-minio-zk`](./semoss-with-postgres-minio-zk) | ZooKeeper (single node) | Postgres + MinIO + ZooKeeper + SEMOSS |
| [`semoss-with-postgres-minio-redis`](./semoss-with-postgres-minio-redis) | Redis (single node) | Postgres + MinIO + Redis + SEMOSS |
| [`semoss-with-postgres-minio-zk-ha`](./semoss-with-postgres-minio-zk-ha) | ZooKeeper 3-node ensemble | Postgres + MinIO + ZK ensemble + SEMOSS |
| [`semoss-with-postgres-minio-redis-ha`](./semoss-with-postgres-minio-redis-ha) | Redis + Sentinel (HA) | Postgres + MinIO + Redis/replicas + Sentinels + SEMOSS |

The `-ha` variants make the coordination layer fault-tolerant: a 3-node ZooKeeper
ensemble (tolerates 1 node down), or Redis with Sentinel automatic failover.
SEMOSS' Redis client is Sentinel-aware, so it connects to the Sentinels directly
(`REDIS_SENTINEL_ENABLED` / `REDIS_MASTER_NAME` / `REDIS_SENTINEL_NODES`) and
follows failovers — no proxy required.

These stacks expose SEMOSS as a `ClusterIP` service and are accessed via
`kubectl port-forward` (see each folder's README). To reach SEMOSS through a real
URL with an NGINX ingress instead, see [`ingress/`](./ingress) — it covers the
required ingress controller, plus DNS + TLS for production.

Each stack includes:

- **Postgres** — a `Deployment` + `Service` + PVC, with an init `ConfigMap` that
  creates the eight databases SEMOSS needs on first startup.
- **MinIO** — an S3-compatible object store as a `StatefulSet` + `Service`, plus a
  one-shot `Job` that creates the `semoss` bucket.
- **ZooKeeper or Redis** — the coordination backend as a `StatefulSet` + `Service`.
- **SEMOSS** — a `Deployment` (config via `envFrom` a `ConfigMap`/`Secret`) + `Service`.
  Its `initContainers` wait for Postgres, MinIO, and the backend to be reachable,
  so a single `kubectl apply -k .` works regardless of creation order.

## Deploy

```
cd semoss-with-postgres-minio-zk      # or semoss-with-postgres-minio-redis
kubectl apply -k .
```

Watch it come up:

```
kubectl -n semoss get pods -w
```

Reach the UI by port-forwarding the service (use port **8080** — the config's
`REDIRECT` is hardcoded to `localhost:8080`):

```
kubectl -n semoss port-forward svc/semoss-service 8080:8080
```

| What | URL |
|:-----|:----|
| Health / readiness check | http://localhost:8080/Monolith/health/ready (READY=200) |
| SEMOSS UI | http://localhost:8080/SemossWeb/packages/client/dist/ |

## Example credentials (demo only — do not use in production)

| Component | Value |
|:----------|:------|
| Postgres user / password | `myuser` / `mypassword` |
| Postgres databases | `security`, `localmaster`, `scheduler`, `themes`, `user_tracking`, `model_logs`, `prompt_hub`, `audit_logs` |
| MinIO access / secret key | `minioadmin` / `minioadmin` |
| MinIO bucket / endpoint | `semoss` / `http://minio:9000` |

> **Note:** The example SEMOSS pod requests 8Gi / limits 16Gi. Make sure your
> cluster/node has the headroom, or adjust the values in `semoss-deployment.yml`
> to fit your environment.

## Cleanup

```
kubectl delete -k .          # removes everything except PVCs
kubectl -n semoss delete pvc --all   # also delete persistent volumes
```
