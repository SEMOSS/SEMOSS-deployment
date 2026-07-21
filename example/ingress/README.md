# Exposing SEMOSS through an NGINX Ingress

The example stacks expose SEMOSS only as a `ClusterIP` service and are reached via
`kubectl port-forward` — deliberately, because an Ingress has a dependency the
manifests can't satisfy on their own: **a running ingress controller**. This folder
shows how to add one when you want a real URL instead of port-forwarding.

Two manifests are provided:

| File | Use |
|:-----|:----|
| [`ingress-local.yml`](./ingress-local.yml) | Laptop or single-node (minikube/kind/Docker Desktop, RKE2/K3s): HTTP only, no TLS, no host — access via `localhost` or the node/LB IP |
| [`ingress-tls.yml`](./ingress-tls.yml) | Production: real hostname + TLS + forced HTTPS (mirrors the root [`semoss-ingress.yml`](../../semoss-ingress.yml)) |

Both route `/` to `semoss-service:8080` in the `semoss` namespace, so deploy one of
the example stacks **first**, then add an ingress here.

---

## Prerequisite (both paths): an ingress controller

An `Ingress` object does nothing until an **ingress controller** is running in the
cluster to act on it. Install [ingress-nginx](https://kubernetes.github.io/ingress-nginx/deploy/)
for your environment, e.g.:

```
# minikube
minikube addons enable ingress

# kind
kubectl apply -f https://kubernetes.github.io/ingress-nginx/deploy/static/provider/kind/deploy.yaml

# generic / cloud
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

Wait for it to be ready:

```
kubectl -n ingress-nginx get pods
```

---

## Laptop or single-node — HTTP, no TLS

Works the same on a laptop (minikube / kind / Docker Desktop) and on a single cloud
node (RKE2 / K3s). The ingress is host-less, so it matches any request that reaches
the controller — only the address you open differs (`localhost` vs the node IP).

1. Install a controller (above). RKE2 ships ingress-nginx by default; K3s ships Traefik (either works — adjust `ingressClassName` if not `nginx`).
2. Apply the ingress:
   ```
   kubectl apply -f ingress-local.yml
   ```
3. Find the address the controller is reachable on:
   ```
   kubectl -n ingress-nginx get svc ingress-nginx-controller   # EXTERNAL-IP, or the node's IP
   ```
   On a single cloud node this is typically the node's public/private IP (open port 80 in the security group).
4. Open **http://&lt;node-or-LB-IP&gt;/** — the ingress has no `host:` rule, so it matches any request that reaches the controller, and `app-root` redirects `/` to the SEMOSS web app. (On a laptop controller that binds localhost — Docker Desktop / `minikube tunnel` / kind — this is just `http://localhost/`.)

> **Update `REDIRECT`.** The example config sets `REDIRECT: "http://localhost:8080/#/"`
> for the port-forward flow. When you go through the ingress, change `REDIRECT` in
> the stack's `semoss-config-and-secrets.yml` to the ingress URL
> (`http://<node-or-LB-IP>/`) and re-apply, or logins will redirect to the wrong place.

---

## Production — real DNS + TLS

A production ingress needs infrastructure that only you can provide:

1. **A DNS record.** Point your hostname (e.g. `semoss.example.com`) at the ingress
   controller's external LoadBalancer address:
   ```
   kubectl -n ingress-nginx get svc ingress-nginx-controller   # note EXTERNAL-IP / hostname
   ```
   Create an `A` (or `CNAME`) record for your host pointing at it.
2. **A TLS certificate** as a Kubernetes secret in the `semoss` namespace. Either
   bring your own cert:
   ```
   kubectl -n semoss create secret tls tls-secret \
     --cert=path/to/tls.crt --key=path/to/tls.key
   ```
   or provision automatically with [cert-manager](https://cert-manager.io/) +
   Let's Encrypt (add an `Issuer`/`ClusterIssuer` and a `cert-manager.io/cluster-issuer`
   annotation).
3. **Edit `ingress-tls.yml`** — replace both `<DNS>` placeholders with your hostname
   (and the `secretName` if you named the TLS secret differently), then:
   ```
   kubectl apply -f ingress-tls.yml
   ```
4. **Set `REDIRECT`** in the stack's `semoss-config-and-secrets.yml` to
   `https://<your-host>/SemossWeb/packages/client/dist/` and re-apply.

Open **https://your-host/** — `force-ssl-redirect` upgrades HTTP to HTTPS and
`app-root` sends `/` to the SEMOSS web app.

---

## Notes

- The manifests set `proxy-body-size: 500m` to match SEMOSS's file upload limits
  (`FILE_UPLOAD_LIMIT` / `FILE_TRANSFER_LIMIT`). Lower it if your controller caps
  request sizes.
- `affinity: cookie` (sticky sessions) matters when you scale SEMOSS to more than
  one replica behind the ingress.
- These aren't part of any `kustomization.yaml` — apply them with `kubectl apply -f`
  after the stack is up, so the base examples stay dependency-free.
