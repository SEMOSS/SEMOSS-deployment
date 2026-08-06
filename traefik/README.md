# Traefik

## Background

SEMOSS manifests were originally deployed with an ingress-nginx controller. This folder documents the changes required to make the same deployment work under Traefik using the `kubernetesIngressNGINX` provider.

The `kubernetesIngressNGINX` provider watches `Ingress` resources with `ingressClassName: nginx`, so the existing `semoss-ingress.yml` is picked up by Traefik without changing the class name. Most `nginx.ingress.kubernetes.io/`
annotations are honored.

## Blocker: `proxy-cookie-path`

The original manifests relied on:

```yaml
nginx.ingress.kubernetes.io/proxy-cookie-path:  ~*^/.* /
```

Traefik silently ignores this annotation. Without it, Set-Cookie headers from the application arrive at the browser with their original path intact. The annotation captures any cookie path and rewrites it to `/`, ensuring cookies are sent on all requests.

## Blocker: HSTS

The original manifests relied on:

```yaml
nginx.ingress.kubernetes.io/hsts: "true"
nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
nginx.ingress.kubernetes.io/hsts-preload: "true"
```

Traefik silently ignores these annotations under `kubernetesIngressNGINX`. 

**Solution**: nginx sidecar

An nginx sidecar container is added to the SEMOSS pod. It sits between Traefik and Tomcat: it listens on port 80, proxies requests to Tomcat on localhost:8080, adds the HSTS header in the `server {}` block, and rewrites Set-Cookie headers using `proxy_cookie_path ~*^/.* /;` before returning them to the client.

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

`always` emits the header on all response codes (200, 302, 4xx, 5xx).

```
Before:  Traefik → Service:8080 → Tomcat:8080
          ↳ Set-Cookie: ...; Path=/Monolith   ← not rewritten, session breaks

After:   Traefik → Service:80 → nginx sidecar:80 → Tomcat:8080
          ↳ Set-Cookie: ...; Path=/            ← rewritten by sidecar
```

### Changes per file

**semoss-ingress.yml**

- Removed `nginx.ingress.kubernetes.io/proxy-cookie-path` — handled by the sidecar now.
- Removed HSTS annotations — handled by the sidecar now.
- Service port changed from 8080 to 80 — routes to the sidecar.

**semoss-service.yml**

- `port` and `targetPort` changed from 8080 to 80.

**semoss-deployment.yml**

- Added nginx sidecar container (nginx:1.31-alpine, port 80).
- Added `volumeMounts` on the sidecar pointing to the nginx config.
- Added `volumes` block referencing the `semoss-nginx-sidecar-config` ConfigMap.

**semoss-nginx-config.yml** (new file)

- New ConfigMap (`semoss-nginx-sidecar-config`) with the sidecar nginx config:
  - `proxy_pass http://localhost:8080` — forwards to Tomcat.
  - `proxy_cookie_path ~*^/.* /;` — rewrites any cookie path to `/`.
  - `add_header Strict-Transport-Security ...` — emits HSTS on all responses.
  - `proxy_read_timeout 350s; proxy_send_timeout 350s;` — prevents 504s during long LLM inference (nginx default is 60s).
  - All `*_temp_path` directives use `/tmp` so nginx runs without write access to `/var/cache/nginx` (the pod runs as UID 1001).

## Note: sidecar timeout

The `proxy-read-timeout` and `proxy-send-timeout` ingress annotations set the timeout at the Traefik → Service boundary. The nginx sidecar has its own separate `proxy_read_timeout` (nginx default: 60s) that applies to the sidecar → Tomcat connection. Without explicit directives in the sidecar config, slow responses (e.g. LLM inference) will time out at the sidecar before Traefik's annotation timeout fires.

`semoss-nginx-config.yml` sets both to 350s to match the ingress annotation.
