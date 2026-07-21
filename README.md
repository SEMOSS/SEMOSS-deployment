# SEMOSS-deployment
## Kubernetes deployment guide

SEMOSS can be deployed as a service running in a Kubernetes cluster on a cloud provider. The SEMOSS deployment requires the following infrastructure resources:

- Storage bucket.
- Database (PostgreSQL)
- Kubernetes cluster

The Following diagram details the Kubernetes and cloud provider resources that will be created (exmaple for Azure).

<div align="center">
  <a href="img/kubernetes-deployment-azure.png">
    <img alt="SEMOSS Kubernetes deployment architecture (Azure example)" width="840" src="img/kubernetes-deployment-azure.png">
  </a>
  </br>
</div>

Before deploying the SEMOSS container, ensure that the pod has access to both the storage bucket (e.g., S3, Azure Blob, Google Bucket) and the database. Once the necessary policies are in place, the pods and services can be deployed to the Kubernetes cluster.

The details of these cloud resources are passed to the SEMOSS pods as environment variables. These are centralized in the [`semoss-config-and-secrets.yml`](./semoss-config-and-secrets.yml) manifest — a `ConfigMap` for non-sensitive settings and a `Secret` for credentials — which the SEMOSS `Deployment` consumes via `envFrom` rather than inlining every variable.

## Repository layout

| File | Purpose |
|:-----|:--------|
| [`namespace.yml`](./namespace.yml) | Creates the `semoss` namespace |
| [`semoss-config-and-secrets.yml`](./semoss-config-and-secrets.yml) | `ConfigMap` (non-sensitive settings) + `Secret` (credentials), consumed by the SEMOSS pod via `envFrom` |
| [`semoss-deployment.yml`](./semoss-deployment.yml) | SEMOSS `Deployment` |
| [`semoss-service.yml`](./semoss-service.yml) | SEMOSS `Service` (ClusterIP) |
| [`semoss-ingress.yml`](./semoss-ingress.yml) | NGINX `Ingress` |
| `redis-statefulset.yml` / `redis-headless-service.yml` / `redis-config-configmap.yml` / `sentinel-statefulset.yml` / `redis-sentinel-service.yml` / `sentinel-config-configmap.yml` | Redis + Sentinel coordination backend (**default** — HA) |
| `zookeeper-statefulset.yml` / `zookeeper-headless-service.yml` / `zookeeper-service.yml` | ZooKeeper coordination backend (alternative — 3-node ensemble) |
| [`kustomization.yaml`](./kustomization.yaml) | Aggregates all manifests for `kubectl apply -k .` |
| [`deploy.sh`](./deploy.sh) | Staged deploy that waits for each dependency to be Ready before the next |
| [`example/`](./example/) | Filled-in, self-contained runnable stacks (single-node + HA) |
| [`legacy/`](./legacy/) | Superseded manifests kept for reference (e.g. the old ZooKeeper `Deployment`) |

## Quick deploy

There are two ways to bring up the whole stack in dependency order. Both read their configuration from [`semoss-config-and-secrets.yml`](./semoss-config-and-secrets.yml), so edit that file first — fill in the database, storage, image, and auth placeholders.

> **Prerequisites:** an external PostgreSQL database and a storage bucket must already exist (see [Database configuration](#database-configuration)), and an NGINX ingress controller should be installed (see [Ingress service](#ingress-service)).

**Option A — declarative, one command (Kustomize):**
```
kubectl apply -k .
```
Creates objects in a dependency-friendly order (Namespace → ConfigMap/Secret → Services → workloads → Ingress). It does **not** wait for readiness between objects; SEMOSS retries its connections until the database and coordination backend are up.

**Option B — staged, with readiness gating:**
```
./deploy.sh                            # Redis + Sentinel backend (default)
CLUSTER_BACKEND=zookeeper ./deploy.sh  # ZooKeeper ensemble instead
TIMEOUT=300s ./deploy.sh               # override the per-stage readiness timeout
```
Applies each stage and blocks on `kubectl rollout status` until the coordination backend is Ready before starting SEMOSS.

Both default to the **Redis + Sentinel** coordination backend. To use **ZooKeeper** instead, see [Cluster coordination backend](#cluster-coordination-backend-redis-or-zookeeper). Whichever backend you choose in the manifests must match the one enabled in `semoss-config-and-secrets.yml`.

The sections below walk through the same resources individually for manual / customized deploys.

## Database configuration

If you are using a managed database service, the following databases or schemas need to be created.

Databases/Schemas that need to be created:

- security
- localmaster
- scheduler
- themes
- user_tracking
- prompt_hub

It is best to make these separate database instances for independent scaling

- model_logs
- audit_logs

The names used for the schemas/databases can be changed to fit the project's naming standards.

If you are using a PostgreSQL database, you can use [psql](https://www.postgresql.org/docs/current/app-psql.html) to create the databases or schemas.
<details>
  <summary>psql installation:</summary>

- Install psql [Ubuntu](https://www.postgresql.org/download/linux/ubuntu/):
```
apt install postgresql
```
- Install psql [Amazon Linux 2023](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ConnectToPostgreSQLInstance.html):
``` 
sudo dnf update -y
sudo dnf install postgresql -y
```

</details>

<details>
  <summary>psql example:</summary>

> **Note:** An AWS RDS is used in the following commands, please check your cloud provider for instructions on how to connect to the database.

1.- Connect to database.
```
psql -h mydb.xxxxxxx.us-east-1.rds.amazonaws.com -p 5432 -U myuser -d postgres
```
2.- Once connected, run the following commands inside the prompt.
```
CREATE DATABASE <DATABASE_NAME>;
```
3.- To confirm the databases have been created:
```
\l
```
4.- To exit from the database
```
\q
```

</details>


Once SEMOSS pods are launched, they will connect to the databases and initialize tables upon its first launch.

## Ingress service
We use a load balancer to expose the SEMOSS application, and a way to control the load balancer creation in a cloud environment is by using [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/). The [Ingress-NGINX](https://github.com/kubernetes/ingress-nginx) Ingress controller is recommended to externally expose the SEMOSS service.

The Ingress-Nginx can launch a load balancer and manage it using [annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/). The instructions on how to deploy the Ingress controller in the cloud environment can be found in the project's [guide](https://kubernetes.github.io/ingress-nginx/deploy/) page.

> **Note:** The Ingress-NGINX controller can use annotations from a cloud provider's controller, such as the [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller). Please see the documentation for your cloud provider for more information and the Ingress-NGINX documentation for compatibility and usage information.

## Cluster coordination backend (Redis or ZooKeeper)

First create the **semoss** namespace (the [Quick deploy](#quick-deploy) commands do this for you):

```
kubectl apply -f namespace.yml     # or: kubectl create ns semoss
```

SEMOSS uses a coordination backend to synchronize state across pods in a cluster. Choose **one** of the two options below — the backend you deploy must match the one enabled in [`semoss-config-and-secrets.yml`](./semoss-config-and-secrets.yml).

### Option A — Redis (default)

SEMOSS supports three Redis topologies — **standalone**, **Sentinel** (HA with
automatic failover), and **Redis Cluster** (sharded). Enable one by setting the
matching keys in the ConfigMap (`REDIS_SENTINEL_ENABLED` / `REDIS_CLUSTER_ENABLED`);
the shared keys apply to all modes:

| Mode | Enable flag | Additional keys | Also in `Secret` |
|:-----|:------------|:----------------|:-----------------|
| Standalone | (neither) | `REDIS_HOST`, `REDIS_PORT` | `REDIS_PASSWORD` |
| Sentinel (HA) | `REDIS_SENTINEL_ENABLED: "true"` | `REDIS_MASTER_NAME`, `REDIS_SENTINEL_NODES` | `REDIS_PASSWORD`, `REDIS_SENTINEL_PASSWORD` |
| Redis Cluster | `REDIS_CLUSTER_ENABLED: "true"` | `REDIS_CLUSTER_NODES`, `REDIS_CLUSTER_MAX_ATTEMPTS` | `REDIS_PASSWORD` |

Shared keys (all modes): `SEMOSS_IS_CLUSTER_REDIS`, `REDIS_ENABLED`, `REDIS_TIMEOUT_MS`, `REDIS_POOL_MAX_TOTAL`, `REDIS_POOL_MAX_IDLE`, `REDIS_POOL_MIN_IDLE`.

The **default** is a highly-available Sentinel setup: a master + 2 replicas (a `StatefulSet`) with 3 Sentinels (a `StatefulSet`). Deploy it with:

```
kubectl apply -f redis-headless-service.yml -f redis-config-configmap.yml -f redis-statefulset.yml
kubectl apply -f sentinel-config-configmap.yml -f redis-sentinel-service.yml -f sentinel-statefulset.yml
```

The Sentinel keys are already set in the ConfigMap (`REDIS_SENTINEL_NODES` lists the three Sentinel pods). Set `REDIS_PASSWORD` / `REDIS_SENTINEL_PASSWORD` in the `Secret` if your Redis/Sentinel require auth.

> **Simpler option:** for a single-node (standalone) Redis (dev / smoke tests), see the filled-in [`example/semoss-with-postgres-minio-redis`](./example/semoss-with-postgres-minio-redis) stack. A Redis Cluster is typically an externally-managed service; point `REDIS_CLUSTER_NODES` at its endpoints.

### Option B — ZooKeeper (alternative)

A **3-node ZooKeeper ensemble** (tolerates one node failing). Deploy its headless service (for peer discovery), client service, and the StatefulSet (which gives each node persistent `/data` and `/datalog` volumes):

```
kubectl apply -f zookeeper-headless-service.yml -f zookeeper-service.yml -f zookeeper-statefulset.yml
```

The ensemble is self-configuring: each pod derives a unique `ZOO_MY_ID` from its ordinal, and `ZOO_SERVERS` lists all three members via the headless service DNS. Then, in [`semoss-config-and-secrets.yml`](./semoss-config-and-secrets.yml), disable the Redis block (`SEMOSS_IS_CLUSTER_REDIS: "false"` and remove the Redis keys) and uncomment the ZooKeeper block (`SEMOSS_IS_CLUSTER_ZK`, `ZK_SERVER`). Use one backend or the other, not both.

> **Simpler option:** for a single-node ZooKeeper, see [`example/semoss-with-postgres-minio-zk`](./example/semoss-with-postgres-minio-zk). The older single-pod [Deployment](./legacy/zookeeper-deployment.yml) under `legacy/` is superseded by the StatefulSet.

## Configuring the SEMOSS deployment

SEMOSS configuration lives in [`semoss-config-and-secrets.yml`](./semoss-config-and-secrets.yml), split into a `ConfigMap` (non-sensitive settings) and a `Secret` (credentials). The [SEMOSS Deployment](./semoss-deployment.yml) pulls all of these in with `envFrom` instead of declaring each variable inline:

```yaml
      envFrom:
        - configMapRef:
            name: semoss-config
        - secretRef:
            name: semoss-secrets
```

Edit `semoss-config-and-secrets.yml` to set your database connection details, storage bucket/provider, authentication providers, and cluster backend. That file is organized into commented sections — backing databases, authentication & security (SSO providers), R/Python execution, file limits, clustering, object storage, and runtime/sandboxing — with placeholders (`<...>`) for the values you need to fill in.

Key groups to review:

| Section | What to set |
|:--------|:------------|
| Backing databases | `CUSTOM_<db>_DATABASE` / `_SCHEMA` names to match what you created; credentials + `_CONNECTION_URL` go in the `Secret` |
| Authentication & security | Only `NATIVE` and `MICROSOFT` are enabled by default; other SSO providers (`ADFS`, `GOOGLE`, `OKTA`, `LDAP`, …) ship as commented scaffolding. Secret keys / passwords live in the `Secret` |
| Object storage | `SEMOSS_STORAGE_PROVIDER` (`S3`, `MINIO`, `AZURE`, `GCP`, or `LOCAL_FILE_SYSTEM`) plus the matching keys; access/secret keys live in the `Secret` |
| Clustering | Enable exactly one of the ZooKeeper or Redis blocks |

### Example configurations

Fully filled-in, runnable stacks live under [`example/`](./example) — copy one as a starting point:

| Example | Coordination backend | Notes |
|:--------|:---------------------|:------|
| [`semoss-with-postgres-minio-zk`](./example/semoss-with-postgres-minio-zk) | ZooKeeper (single node) | Postgres + MinIO in-cluster; simplest |
| [`semoss-with-postgres-minio-redis`](./example/semoss-with-postgres-minio-redis) | Redis (single node) | Postgres + MinIO in-cluster |
| [`semoss-with-postgres-minio-zk-ha`](./example/semoss-with-postgres-minio-zk-ha) | ZooKeeper 3-node ensemble | HA coordination |
| [`semoss-with-postgres-minio-redis-ha`](./example/semoss-with-postgres-minio-redis-ha) | Redis + Sentinel | HA coordination (matches the root default) |

These examples run Postgres and MinIO **inside** the cluster. In production you'll more often point SEMOSS at **managed / SaaS** services instead — the section below lists the env vars that change.

### Using managed / SaaS dependencies

When the database and object storage are managed services (e.g. AWS RDS + S3, Cloud SQL + GCS, Azure Database + Blob) rather than in-cluster pods, you don't deploy the Postgres/MinIO manifests at all — you only change connection details in [`semoss-config-and-secrets.yml`](./semoss-config-and-secrets.yml).

**Databases (managed Postgres).** There is one set of keys per database (`security`, `localmaster`, `scheduler`, `themes`, `user_tracking`, `model_logs`, `prompt_hub`, `audit_logs`). Non-sensitive keys live in the `ConfigMap`; credentials and the URL live in the `Secret`. `<db>` below is the per-database prefix (e.g. `CUSTOM_SECURITY_...`).

| Env variable | In-cluster example | Managed / SaaS |
|:---|:---|:---|
| `CUSTOM_<db>_CONNECTION_URL` | `jdbc:postgresql://postgres:5432/security?currentSchema=public` | Point the host at the managed endpoint: `jdbc:postgresql://<rds-endpoint>:5432/security?currentSchema=public` |
| `CUSTOM_<db>_USERNAME` | `myuser` | The managed DB user |
| `CUSTOM_<db>_PASSWORD` | `mypassword` | The managed DB password |
| `CUSTOM_<db>_DATABASE` / `_SCHEMA` | `security` / `public` | The database and schema names you provisioned |

> `model_logs` and `audit_logs` are high-write; if you want to scale them independently, put them on their own managed instance by giving those two a different host in their `CONNECTION_URL`.

**Object storage (managed buckets).** Set `SEMOSS_STORAGE_PROVIDER` and the matching keys; access/secret keys go in the `Secret`. Omit `S3_ENDPOINT` (that key is only for pointing S3-mode at MinIO):

| Provider | `SEMOSS_STORAGE_PROVIDER` | Keys to set |
|:---|:---|:---|
| AWS S3 | `S3` | `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY`\*, `S3_SECRET_KEY`\* |
| Google Cloud Storage | `GCP` (or `GCS`/`GOOGLE`) | `GCP_REGION`, `GCP_BUCKET`, `GCP_SERVICE_ACCOUNT_FILE` (mount the JSON key file) |
| Azure Blob Storage | `AZURE` | `AZ_NAME`, `AZ_KEY`\*, `AZ_CONN_STRING`\*, `AZ_GENERATE_DYNAMIC_SAS` |

<sub>\* credentials belong in the `Secret`, not the `ConfigMap`.</sub>

#### Keyless object-storage access (IRSA / Workload Identity)

On a cloud cluster you can skip storage keys entirely and let the pod authenticate
through the cloud's pod-identity mechanism (AWS IRSA / GCP + Azure Workload
Identity) — the recommended approach in production, since no credentials live in
the manifests and they rotate automatically. The pod runs as the
[`serviceaccount.yml`](./serviceaccount.yml) `ServiceAccount` bound to a cloud IAM
role instead of using `S3_ACCESS_KEY` / `S3_SECRET_KEY`. See
[extra-cloud-config/aws-semoss-deployment.md](./extra-cloud-config/aws-semoss-deployment.md) for the full
walkthrough (IAM role, trust policy, and the GCP/Azure annotation equivalents).

**Other values you'll typically set** (managed or not):

| Env variable | Purpose |
|:---|:---|
| `REDIRECT` | The address your browser uses to reach SEMOSS (external host/IP + port or ingress URL) — post-login redirects here |
| `MONOLITH_COOKIE_SET_SECURE` | `"true"` makes the session cookie HTTPS-only. Set `"false"` when accessing over plain HTTP (local/dev) or the cookie isn't sent and login fails |
| coordination backend | `REDIS_SENTINEL_NODES` (default) or `ZK_SERVER` — point at your coordination service |
| `image` | The SEMOSS image to deploy (set in [`semoss-deployment.yml`](./semoss-deployment.yml)) |

For the full list of configuration parameters, refer to the [AI Server Configuration Parameters]().

After updating the configuration, deploy SEMOSS. With the [Quick deploy](#quick-deploy) commands the `Deployment` and `Service` are applied for you; to do it manually, apply the [SEMOSS-deployment](./semoss-deployment.yml) and then expose the pods with the [SEMOSS-service](./semoss-service.yml) YAML file:

```apiVersion: v1
kind: Service
metadata:
  name: semoss-service
  namespace: semoss
spec:
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app.kubernetes.io/instance: semoss
    app.kubernetes.io/name: semoss
  sessionAffinity: None
  type: ClusterIP
```

## Creating the Ingress service


Use the [SEMOSS-ingress](./semoss-ingress.yml) YAML file to create the ingress resource and define the rules for routing traffic to the backend SEMOSS service.
> **Note:** The ingress resource can be configured to have externally-reachable URLs and terminate SSL / TLS. Please see the Kubernetes [documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/) for more information.

<details>
  <summary>Example of the SEMOSS-ingress resource that uses SSL certificates:</summary>

Create a kubernetes TLS secret:

```
kubectl -n semoss create secret tls <testsecret-tls> --cert=path/to/tls.crt --key=path/to/tls.key    
```

If the certifificate includes the cert and the encrypted RSA key (the cert will show *-----BEGIN RSA PRIVATE KEY-----* and *Proc-Type: 4,ENCRYPTED*) in the same file, obtain the key by running `openssl rsa -in encrypted.key -out tls.key`

After the secret has been created use the secret name in the Ingress resource manifest:
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: semoss-ingress
  namespace: semoss
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 500m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/session-cookie-expires: "172800"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "172800"
    nginx.ingress.kubernetes.io/session-cookie-name: semoss-nginx-sticky
    nginx.ingress.kubernetes.io/session-cookie-path: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.org/client-max-body-size: 500m
spec:
  tls:
  - hosts:
      - demo.semoss.org # URL
    secretName: testsecret-tls
  rules:
    - host: demo.semoss.org # URL
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: semoss-service
                port:
                  number: 8080

  
```
</details>

<details>
  <summary> Example of the SEMOSS-ingress resource that is not using SSL certificates</summary>

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/app-root: /SemossWeb
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-preload: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 500m
    nginx.ingress.kubernetes.io/proxy-cookie-path: ~*^/.* /
    nginx.ingress.kubernetes.io/proxy-read-timeout: "350"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "350"
    nginx.ingress.kubernetes.io/session-cookie-expires: "172800"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "172800"
    nginx.ingress.kubernetes.io/session-cookie-name: semoss-nginx-prod
    nginx.ingress.kubernetes.io/session-cookie-path: /
    nginx.ingress.kubernetes.io/session-cookie-secure: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.org/client-max-body-size: 500m
  name: semoss-ingress
  namespace: semoss
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - backend:
          service:
            name: semoss-service
            port:
              number: 8080
        path: /
        pathType: ImplementationSpecific
```
</details>

After the ingress resource has been created get the Load balancer's Address.
```
$ kubectl -n semoss get ingress -o wide
NAME             CLASS    HOSTS             ADDRESS                      PORTS   AGE
semoss-ingress   <none>   demo.semoss.org   ID.elb.REGION.amazonaws.com   80      87d
```

The address value will be used to replace the INGRESS_DNS placeholder mentioned in the **REDIRECT** key value.

## Additional information
- [AWS](./extra-cloud-config/aws-semoss-deployment.md)
