# SEMOSS + Postgres + MinIO + ZooKeeper (single node)

The simplest self-contained stack: SEMOSS with all dependencies running **inside**
the cluster, and a **single-node** ZooKeeper for cluster coordination. Good for a
local smoke test. For a fault-tolerant coordination layer, see the
[`-ha`](../semoss-with-postgres-minio-zk-ha) variant.

## What's in here

| File(s) | Purpose |
|:--------|:--------|
| `namespace.yml` | Creates the `semoss` namespace |
| `postgres-deployment.yml` / `postgres-service.yml` / `postgres-init-configmap.yml` | Postgres (`Deployment` + PVC + `Service`); the init `ConfigMap` creates the 8 SEMOSS databases on first start |
| `minio-statefulset.yml` / `minio-service.yml` / `minio-createbucket-job.yml` | MinIO object store (`StatefulSet` + `Service`) + a `Job` that creates the `semoss` bucket |
| `zookeeper-statefulset.yml` / `zookeeper-service.yml` | Single-node ZooKeeper coordination backend |
| `semoss-config-and-secrets.yml` | SEMOSS `ConfigMap` (settings) + `Secret` (credentials), consumed via `envFrom` |
| `semoss-deployment.yml` / `semoss-service.yml` | SEMOSS `Deployment` (with initContainers that wait for Postgres/MinIO/ZooKeeper) + ClusterIP `Service` |
| `kustomization.yaml` | Ties it all together for `kubectl apply -k .` |

## Demo credentials (not for production)

- Postgres: `myuser` / `mypassword` — databases `security`, `localmaster`, `scheduler`, `themes`, `user_tracking`, `model_logs`, `prompt_hub`, `audit_logs`
- MinIO: `minioadmin` / `minioadmin` — bucket `semoss`, endpoint `http://minio:9000`

## Deploy

```
kubectl apply -k .
kubectl -n semoss get pods -w      # wait until the semoss pod is Running/Ready
```

The pod is ready when the readiness probe (`/Monolith/health/ready`) reports `READY` — watch for it to become `Ready` in the pod list above before accessing SEMOSS.

## Access (port-forward)

The stack exposes SEMOSS only as a `ClusterIP` service (no ingress). Reach it from
your laptop by port-forwarding:

```
kubectl -n semoss port-forward svc/semoss-service 8080:8080
```

Then open:

| What | URL |
|:-----|:----|
| Health / readiness check | http://localhost:8080/Monolith/health/ready (READY=200) |
| SEMOSS UI | http://localhost:8080/SemossWeb/packages/client/dist/ |

> Use port **8080** (`8080:8080`): the config's `REDIRECT` is `http://localhost:8080/#/`,
> so a different local port would break post-login redirects. If the UI path 404s,
> try http://localhost:8080/SemossWeb/. For a real hostname/TLS setup instead of
> port-forward, see [`../ingress`](../ingress).

## Cleanup

```
kubectl delete -k .                      # removes everything except PVCs
kubectl -n semoss delete pvc --all       # also delete the persistent volumes
```
