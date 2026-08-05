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

Traefik silently ignores this annotation. Without it, Tomcat's session cookie arrives at the browser with Path=/Monolith (because the WAR is deployed as
Monolith.war). The browser then only sends the cookie back for requests under /Monolith/*, not for /SemossWeb/* static assets — breaking the session.

**Solution**: nginx sidecar

An nginx sidecar container is added to the SEMOSS pod. It sits between Traefik and Tomcat: it listens on port 80, proxies requests to Tomcat on localhost:8080, and rewrites Set-Cookie headers using `proxy_cookie_path /Monolith /;` before Traefik sees them.

```
Before:  Traefik → Service:8080 → Tomcat:8080
          ↳ Set-Cookie: ...; Path=/Monolith   ← not rewritten, session breaks

After:   Traefik → Service:80 → nginx sidecar:80 → Tomcat:8080
          ↳ Set-Cookie: ...; Path=/            ← rewritten by sidecar
```

### Changes per file

**semoss-ingress.yml**
- Removed nginx.ingress.kubernetes.io/proxy-cookie-path — handled by the sidecar now.
- Service port changed from 8080 to 80 — routes to the sidecar.

**semoss-service.yml**
- port and targetPort changed from 8080 to 80.

**semoss-deployment.yml**
- Added nginx-cookie-proxy sidecar container (nginx:1.31-alpine, port 80).
- Added volumeMounts on the sidecar pointing to the nginx config.
- Added volumes block referencing the semoss-nginx-sidecar-config ConfigMap.

**semoss-nginx-config.yml** (new file)
- New ConfigMap (semoss-nginx-sidecar-config) with the sidecar nginx config:
  - `proxy_pass http://localhost:8080` — forwards to Tomcat.
  - `proxy_cookie_path /Monolith /;` — rewrites the session cookie path.
  - All `*_temp_path` directives use `/tmp` so nginx runs without write access to `/var/cache/nginx` (the pod runs as UID 1001).
