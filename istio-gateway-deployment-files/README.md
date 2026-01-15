# Istio

Istio with sidecar deployment provides complete coverage for all nginx-ingress annotations that need to be migrated. This is especially true for Cookie-based session affinity using `DestinationRules`.

✅ Why is Istio recommended:

- 100% Open Source - No paid subscription needed
- Cloud Agnostic - Works on any Kubernetes cluster
- Cookie-based Session Affinity - Supported via consistentHash in DestinationRule
- No Application Changes - Handles session cookies at the proxy level
- All currently used ingress-nginx annotations Supported - Can replicate all the annotations mentioned in the semoss-ingress.yaml file
- Mature & Battle-tested - Production-ready with large community

⚠️ Considerations:

- Higher resource overhead (sidecar proxies)
- Each sidecar requires an additional IP address
- Steeper learning curve
- More complex operational model

## Why use Kubernetes Gateway API instead of only Istio?

Using [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) instead of traditional Istio resources provides the following benefits:

- Vendor Neutrality - Same API works with Istio, Envoy Gateway, Kong, etc.
- Simplified Configuration - HTTPRoute is more intuitive than VirtualService
- Fair Comparison - Makes it easier to compare Istio vs other Gateway vendors
- Future-Proof - Gateway API is the Kubernetes standard for ingress
- Automatic Gateway Deployment - No need to manually deploy ingress gateways

```
+------------------------------------------------------------------------+
|                     TRADITIONAL ISTIO APPROACH                         |
+------------------------------------------------------------------------+
|                                                                        |
|  +---------------------+         +----------------------+              |
|  | Istio Gateway       |         | Istio VirtualService |              |
|  | (Istio-specific)    |-------> | (Istio-specific)     |              |
|  +---------------------+         +----------------------+              |
|           |                                   |                        |
|           |         Requires manual           |                        |
|           |         deployment of             |                        |
|           v         istio-ingressgateway      v                        |
|  +-------------------------------------------------+                   |
|  |   Pre-deployed Istio Ingress Gateway Pod        |                   |
|  |   (istio-ingressgateway)                        |                   |
|  +-------------------------------------------------+                   |
|                          |                                             |
|                          v                                             |
|                  +---------------+                                     |
|                  |  Application  |                                     |
|                  +---------------+                                     |
|                                                                        |
|  [X] Vendor lock-in to Istio                                           |
|  [X] Complex configuration (Gateway + VirtualService)                  |
|  [X] Manual gateway deployment                                         |
|  [X] Different for each vendor (Istio, Envoy Gateway, etc.)            |
+------------------------------------------------------------------------+
```

Using Istio with Gateway API:
```
+------------------------------------------------------------------------+
|              KUBERNETES GATEWAY API APPROACH                           |
+------------------------------------------------------------------------+
|                                                                        |
|  +---------------------+         +----------------------+              |
|  | Gateway             |         | HTTPRoute            |              |
|  | (K8s Standard)      |-------->| (K8s Standard)       |              |
|  | gatewayClassName:   |         |                      |              |
|  |   - istio           |         |  Same for both!      |              |
|  |   - envoy-gateway   |         |                      |              |
|  +---------------------+         +----------------------+              |
|           |                                   |                        |
|           |    Istio/Envoy Gateway            |                        |
|           |    automatically deploys          |                        |
|           v    gateway pods                   v                        |
|  +-------------------------------------------------+                   |
|  |   Auto-deployed Gateway Pod                     |                   |
|  |   (Created by controller when needed)           |                   |
|  +-------------------------------------------------+                   |
|                          |                                             |
|                          v                                             |
|                  +---------------+                                     |
|                  |  Application  |                                     |
|                  +---------------+                                     |
|                                                                        |
|  [✓] Vendor neutral (works with multiple implementations)              |
|  [✓] Simplified configuration (Gateway + HTTPRoute)                    |
|  [✓] Automatic gateway deployment                                      |
|  [✓] Easy to switch vendors (change gatewayClassName only)             |
|  [✓] Future-proof (Kubernetes standard)                                |
+------------------------------------------------------------------------+
```

## Installing Istio

The Kubernetes Gateway API CRDs do not come installed by default on most Kubernetes clusters. They can be installed if they are not present with the following command:
```bash
$ kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.4.0" | kubectl apply -f -; }
```

> **Note:** Latest gateway-api CRD version can be found on the [project's](https://github.com/kubernetes-sigs/gateway-api) repository.

Install Istio using the minimal profile using [istioctl](https://istio.io/latest/docs/ops/diagnostic-tools/istioctl/):
```bash
$ istioctl install --set profile=minimal -y
```

Installation can be verified with:
```bash
$ istioctl verify-install
```

Components installed:

- ✅ Istiod (control plane)
- ✅ Gateway API support (enabled by default)
- ❌ Ingress Gateway (not deployed - we use Gateway API instead)
- ❌ Egress Gateway
- ❌ Telemetry addons (Prometheus, Grafana, Kiali)

Once istio is installed, we can create the resources following resources needed to route traffic to the Semoss service.

- [Gateway](gateway/) - Loadbalancer entry point for external traffic and configures listeners (protocols, ports, TLS)
- [EnvoyFilter](envoyfilters/) - Low-level Envoy proxy customization (HTTP headers, max request body size, and secure session cookies)
- [HTTPRoute](httproutes/) - L7 routing rules (path, header matching) and traffic splitting/mirroring
- [DestinationRule](destinationrules/) - Post-routing traffic policies and load balancing (session affinity)

The following diagram shows the HTTP request flow:
```
+------------------------------------------------------------------------+
|                   HTTP REQUEST FLOW WITH ISTIO GATEWAY                 |
|                    (Using Kubernetes Gateway API)                      |
+------------------------------------------------------------------------+

                            External Client
                                  |
                                  | 1. HTTP Request
                                  |    (e.g., GET /api/users)
                                  v
+------------------------------------------------------------------------+
|                                                                        |
|  +------------------------------------------------------------------+  |
|  |                    Kubernetes Gateway Resource                   |  |
|  |  - Listens on specific ports (80, 443)                           |  |
|  |  - Defines gatewayClassName: istio                               |  |
|  |  - Creates LoadBalancer/NodePort service                         |  |
|  +------------------------------------------------------------------+  |
|                                  |                                     |
|                                  | 2. Request enters cluster           |
|                                  v                                     |
|  +------------------------------------------------------------------+  |
|  |              Istio Gateway Pod (Auto-deployed)                   |  |
|  |  +------------------------------------------------------------+  |  |
|  |  |                    Envoy Proxy                             |  |  |
|  |  |  +-------------------------------------------------+       |  |  |
|  |  |  |              EnvoyFilter Applied                |       |  |  |
|  |  |  |  - Custom filters (auth, rate limiting, etc.)   |       |  |  |
|  |  |  |  - Request/response transformation              |       |  |  |
|  |  |  |  - Header manipulation                          |       |  |  |
|  |  |  +-------------------------------------------------+       |  |  |
|  |  +------------------------------------------------------------+  |  |
|  +------------------------------------------------------------------+  |
|                                  |                                     |
|                                  | 3. Route matching                   |
|                                  v                                     |
|  +------------------------------------------------------------------+  |
|  |                     HTTPRoute Resource                           |  |
|  |  - Matches request based on:                                     |  |
|  |    * Path (e.g., /api/users)                                     |  |
|  |    * Headers                                                     |  |
|  |    * Query parameters                                            |  |
|  |  - Routes to backend service(s)                                  |  |
|  |  - Can split traffic (e.g., 90% v1, 10% v2)                      |  |
|  +------------------------------------------------------------------+  |
|                                  |                                     |
|                                  | 4. Backend service selected         |
|                                  v                                     |
|  +------------------------------------------------------------------+  |
|  |                  DestinationRule Resource                        |  |
|  |  - Defines traffic policies:                                     |  |
|  |    * Load balancing (ROUND_ROBIN, LEAST_CONN, etc.)              |  |
|  |    * Connection pool settings                                    |  |
|  |    * Circuit breaker configuration                               |  |
|  |    * TLS settings for mTLS                                       |  |
|  |  - Defines subsets (e.g., v1, v2, canary)                        |  |
|  +------------------------------------------------------------------+  |
|                                  |                                     |
|                                  | 5. Traffic policies applied         |
|                                  v                                     |
|  +------------------------------------------------------------------+  |
|  |                    Kubernetes Service                            |  |
|  |  - ClusterIP service                                             |  |
|  |  - Provides stable endpoint for pods                             |  |
|  +------------------------------------------------------------------+  |
|                                  |                                     |
|                                  | 6. Load balanced to pod             |
|                                  v                                     |
|  +------------------+  +------------------+  +------------------+      |
|  |  Application Pod |  |  Application Pod |  |  Application Pod |      |
|  |     (v1)         |  |     (v1)         |  |     (v2)         |      |
|  | +-------------+  |  | +-------------+  |  | +-------------+  |      |
|  | | App Container| |  | | App Container| |  | | App Container| |      |
|  | +-------------+  |  | +-------------+  |  | +-------------+  |      |
|  | | Envoy Sidecar| |  | | Envoy Sidecar| |  | | Envoy Sidecar| |      |
|  | | (Data Plane) | |  | | (Data Plane) | |  | | (Data Plane) | |      |
|  | +-------------+  |  | +-------------+  |  | +-------------+  |      |
|  +------------------+  +------------------+  +------------------+      |
|           |                     |                     |                |                
|           |               7. Response                 |                |            
|           v                     v                     v                |
+------------------------------------------------------------------------+
                                  |
                                  | 8. Response flows back
                                  | (Through same path in reverse)
                                  v
                            External Client
                         (Receives HTTP Response)
```

# Injecting the Istio sidecar to the Semoss pod

The Istio sidecar can be enabled at the namespace level with the **istio-injection=enabled** label or it can be done at the deployment's pod template level with the **sidecar.istio.io/inject: "true"** label.

Since we do not explicitly need the zookeper pod to have an Istio side car, we are adding the label to the deployment yaml:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: semoss
  name: semoss
  namespace: semoss
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: semoss
      app.kubernetes.io/name: semoss
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: semoss
        app.kubernetes.io/name: semoss
        sidecar.istio.io/inject: "true" # Enable Istio sidecar injection
```

For reference, the namespace with the Istio sidecar injection label can be created with:
```
apiVersion: v1
kind: Namespace
metadata:
  name: semoss
  labels:
    istio-injection: enabled
```