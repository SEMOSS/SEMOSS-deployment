# Exposing SEMOSS through an NGINX Ingress

The example stacks expose SEMOSS only as a `ClusterIP` service and are reached via
`kubectl port-forward` — deliberately, because an Ingress has a dependency the
manifests can't satisfy on their own: **a running ingress controller**. This folder
shows how to add one when you want a real URL instead of port-forwarding.

Two manifests are provided:

| File | Use |
|:-----|:----|
| [`ingress-local.yml`](./ingress-local.yml) | Laptop: HTTP only, no TLS, host `semoss.127.0.0.1.nip.io` |
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

## Local (laptop) — HTTP, no TLS

1. Install a controller (above).
2. Apply the local ingress:
   ```
   kubectl apply -f ingress-local.yml
   ```
3. Make the controller reachable on `localhost`:
   - **minikube:** `minikube tunnel` (keep it running), or use `minikube ip` as the host.
   - **kind:** the deploy manifest above maps ports 80/443 to localhost.
   - **Docker Desktop:** the controller is on `localhost` by default.
4. Open **http://semoss.127.0.0.1.nip.io/** — `nip.io` resolves that name to
   `127.0.0.1`, so no `/etc/hosts` edit is needed. `app-root` redirects `/` to the
   SEMOSS web app.

> **Update `REDIRECT`.** The example config sets `REDIRECT: "http://localhost:8080/#/"`
> for the port-forward flow. When you go through the ingress, change `REDIRECT` in
> the stack's `semoss-config-and-secrets.yml` to the ingress URL
> (`http://semoss.127.0.0.1.nip.io/...`) and re-apply, or logins will redirect to
> the wrong place.

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
