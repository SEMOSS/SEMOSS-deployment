# SEMOSS + Postgres + MinIO + ZooKeeper (Traefik / HTTP)

A self-contained stack: SEMOSS with all dependencies running **inside** the
cluster, using a **ZooKeeper** coordination backend and an nginx sidecar that
makes the deployment work under Traefik. HTTP only, no TLS. Good for a local
smoke test against a Traefik-managed cluster.

## Why the nginx sidecar

Traefik's `kubernetesIngressNGINX` provider silently ignores the
`nginx.ingress.kubernetes.io/proxy-cookie-path` annotation that the standard
SEMOSS manifests depend on. Without it, Set-Cookie headers from the application
arrive at the browser with their original path intact, breaking the session.

An nginx container runs as a sidecar in the SEMOSS pod. It listens on port 80,
proxies requests to Tomcat on `localhost:8080`, and rewrites cookie paths.

For full details see [`../../traefik/README.md`](../../traefik/README.md).

## What's in here

| File(s) | Purpose |
|:--------|:--------|
| `namespace.yml` | Creates the `semoss` namespace |
| `postgres-deployment.yml` / `postgres-service.yml` / `postgres-init-configmap.yml` | Postgres (`Deployment` + PVC + `Service`); the init `ConfigMap` creates the 8 SEMOSS databases on first start |
| `minio-statefulset.yml` / `minio-service.yml` / `minio-createbucket-job.yml` | MinIO object store (`StatefulSet` + `Service`) + a `Job` that creates the `semoss` bucket |
| `zookeeper-statefulset.yml` / `zookeeper-service.yml` / `zookeeper-headless-service.yml` | ZooKeeper coordination backend |
| `semoss-config-and-secrets.yml` | SEMOSS `ConfigMap` (settings) + `Secret` (credentials), consumed via `envFrom` |
| `semoss-nginx-config.yml` | nginx sidecar config (cookie path rewrite, 350s timeouts) |
| `semoss-deployment.yml` / `semoss-service.yml` | SEMOSS `Deployment` (with nginx sidecar + initContainers that wait for Postgres/MinIO/ZooKeeper) + ClusterIP `Service` |
| `kustomization.yaml` | Ties it all together for `kubectl apply -k .` |

## Demo credentials (not for production)

- Postgres: `myuser` / `mypassword` — databases `security`, `localmaster`, `scheduler`, `themes`, `user_tracking`, `model_logs`, `prompt_hub`, `audit_logs`
- MinIO: `minioadmin` / `minioadmin` — bucket `semoss`, endpoint `http://minio:9000`

## Common settings to adjust

Review these before deploying — in `semoss-config-and-secrets.yml` (and `semoss-deployment.yml` for sizing):

| Setting | Why you'd change it |
|:--------|:--------------------|
| `MONOLITH_COOKIE_SET_SECURE` | Set to `"false"` here so login works over plain **HTTP** (port-forward). Change to `"true"` when serving SEMOSS over HTTPS. |
| `REDIRECT` | The address your browser uses to reach SEMOSS. Defaults to `http://localhost:8080/#/` (port-forward); change it if you access via a node IP, NodePort, or ingress. |
| SEMOSS `resources:` | CPU/memory requests & limits in `semoss-deployment.yml` — raise or lower to fit your node. |

## Deploy

```
kubectl apply -k .
kubectl -n semoss get pods -w      # wait until the semoss pod is Running/Ready
```

The pod is ready when the readiness probe (`/Monolith/health/ready`) reports `READY` — watch for it to become `Ready` in the pod list above before accessing SEMOSS.

## Access (port-forward)

The stack exposes SEMOSS as a `ClusterIP` service (no ingress). Reach it from your laptop by port-forwarding:

```
kubectl -n semoss port-forward svc/semoss-service 8080:80
```

## Access using ingress (Traefik)

Traefik must be locally exposed on port 8080 (e.g. `--set "ports.web.hostPort=8080"` in the Helm install).

Additionally, the *nginx* ingress class needs to be present in the cluster and the `providers.kubernetesIngressNGINX` provider (requires Traefik v3.6.2+) needs to be enabled so Traefik can pick up the ingress manifests.

The ingress class name can look like the following:
```
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
```

Once the stack is up, apply the ingress manifest:

```
kubectl apply -f ../ingress/ingress-local-traefik.yml
```

Then open:

| What | URL |
|:-----|:----|
| Health / readiness check | http://localhost:8080/Monolith/health/ready (READY=200) |
| SEMOSS UI | http://localhost:8080/SemossWeb/packages/client/dist/ |

> Use port 8080: the config's REDIRECT is http://localhost:8080/#/, so a different local port would break post-login redirects. If the UI path 404s, try http://localhost:8080/SemossWeb/. For a real hostname/TLS setup instead of port-forward, see [`../ingress`](../ingress).

## Cleanup

```
kubectl delete -k .                      # removes everything except PVCs
kubectl -n semoss delete pvc --all       # also delete the persistent volumes
```
