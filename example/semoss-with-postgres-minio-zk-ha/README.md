# SEMOSS + Postgres + MinIO + ZooKeeper ensemble (HA)

A self-contained stack where the coordination layer is **highly available**: a
**3-node ZooKeeper ensemble** (tolerates one node down). Postgres and MinIO still
run single-instance in-cluster. For the simpler single-node version, see
[`semoss-with-postgres-minio-zk`](../semoss-with-postgres-minio-zk).

## What's in here

| File(s) | Purpose |
|:--------|:--------|
| `namespace.yml` | Creates the `semoss` namespace |
| `postgres-deployment.yml` / `postgres-service.yml` / `postgres-init-configmap.yml` | Postgres (`Deployment` + PVC + `Service`); init `ConfigMap` creates the 8 SEMOSS databases |
| `minio-statefulset.yml` / `minio-service.yml` / `minio-createbucket-job.yml` | MinIO object store + a `Job` that creates the `semoss` bucket |
| `zookeeper-statefulset.yml` | **3-node** ZooKeeper ensemble; each pod derives a unique `ZOO_MY_ID` from its ordinal |
| `zookeeper-headless-service.yml` | Headless service — stable per-pod DNS (`zookeeper-0.zookeeper-headless`, …) for peer quorum/election |
| `zookeeper-service.yml` | Client-facing ClusterIP |
| `semoss-config-and-secrets.yml` | SEMOSS config/secrets; `ZK_SERVER` lists all three ensemble members |
| `semoss-deployment.yml` / `semoss-service.yml` | SEMOSS `Deployment` (initContainers wait for Postgres/MinIO/ZooKeeper) + ClusterIP `Service` |
| `kustomization.yaml` | Ties it all together for `kubectl apply -k .` |

## Demo credentials (not for production)

- Postgres: `myuser` / `mypassword` — databases `security`, `localmaster`, `scheduler`, `themes`, `user_tracking`, `model_logs`, `prompt_hub`, `audit_logs`
- MinIO: `minioadmin` / `minioadmin` — bucket `semoss`, endpoint `http://minio:9000`

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
kubectl -n semoss get pods -w      # zookeeper-0/1/2 should all become Ready, then semoss
```

The three ZooKeeper pods form a quorum before SEMOSS's init container proceeds.
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

## Test the ensemble (optional)

```
kubectl -n semoss delete pod zookeeper-0      # kill a member
kubectl -n semoss get pods -w                 # it rejoins; quorum (2/3) keeps SEMOSS running
```

## Cleanup

```
kubectl delete -k .                      # removes everything except PVCs
kubectl -n semoss delete pvc --all       # also delete the persistent volumes (3 ZK pods each have 2)
```
