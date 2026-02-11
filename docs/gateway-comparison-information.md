# Ingress and Gateway API

Kubernetes offers two resource models for achieving exposing an application outside of the cluster:

**Traditional Ingress Resource:**

- Mature, widely adopted standard (since Kubernetes v1.1)
- Simple, declarative model
- Implementation varies by controller (Ingress-NGINX)
- Limited advanced routing capabilities

**Kubernetes Gateway API:**

- Next-generation standard (GA in Kubernetes v1.31)
- Role-oriented design (infrastructure vs. application concerns)
- Expressive routing with HTTPRoute, TCPRoute, etc.

## Comparison Matrix

The following diagram compares Ingress-NGINX annotations with Envoy Gateway and Istio Gateway resources.

| Nginx-Ingress Annotation | Envoy Gateway | Istio (with Gateway API) | Complexity |
|---------------------------|---------------|--------------------------|------------|
| **Session Affinity** | | | |
| `affinity: cookie` | ✅ BackendTrafficPolicy<br>(`consistentHash.cookie`) | ✅ DestinationRule<br>(`consistentHash.httpCookie`) | **Envoy**: Medium<br>**Istio**: Medium |
| `session-cookie-name` | ✅ In BackendTrafficPolicy<br>(`cookie.name`) | ✅ In DestinationRule<br>(`httpCookie.name`) | **Both**: Easy |
| `session-cookie-expires`<br>`session-cookie-max-age` | ✅ In BackendTrafficPolicy<br>(`cookie.ttl`) - Single value | ✅ In DestinationRule<br>(`httpCookie.ttl`) - Single value | **Both**: Easy |
| `session-cookie-path` | ✅ In BackendTrafficPolicy<br>(`cookie.attributes.Path`) | ✅ In DestinationRule<br>(`httpCookie.path`) | **Both**: Easy |
| `session-cookie-secure` | ✅ In BackendTrafficPolicy<br>(`cookie.attributes.Secure`) | ⚠️ Requires EnvoyFilter<br>(Lua script to add attribute) | **Envoy**: Easy<br>**Istio**: Medium |
| **SSL/TLS Configuration** | | | |
| `ssl-redirect: "true"`<br>`force-ssl-redirect: "true"` | ✅ HTTPRoute<br>(RequestRedirect filter, separate route) | ✅ HTTPRoute<br>(RequestRedirect filter, separate route) | **Both**: Easy |
| **HSTS Headers** | | | |
| `hsts: "true"`<br>`hsts-include-subdomains`<br>`hsts-max-age`<br>`hsts-preload` | ✅ ClientTrafficPolicy<br>(`headers.lateResponseHeaders.set`) - Native support | ⚠️ Requires EnvoyFilter<br>(Lua script on response) | **Envoy**: Easy<br>**Istio**: Hard |
| **Request/Response Limits** | | | |
| `proxy-body-size: 500m`<br>`client-max-body-size: 500m` | ✅ ClientTrafficPolicy<br>(`connection.bufferLimit`) - Native support | ⚠️ Requires EnvoyFilter<br>(buffer filter configuration) | **Envoy**: Easy<br>**Istio**: Hard |
| **Timeouts** | | | |
| `proxy-read-timeout: "350"`<br>`proxy-send-timeout: "350"` | ✅ BackendTrafficPolicy<br>(`timeout.http.connectionIdleTimeout`) | ✅ HTTPRoute<br>(`timeouts.request`, `timeouts.backendRequest`) | **Envoy**: Medium<br>**Istio**: Easy |
| **URL Rewrites** | | | |
| `app-root: /SemossWeb` | ✅ HTTPRoute<br>(RequestRedirect with ReplaceFullPath) | ✅ HTTPRoute<br>(RequestRedirect with ReplaceFullPath) | **Both**: Easy |
| `proxy-cookie-path: ~*^/.* /` | ✅ EnvoyExtensionPolicy<br>(Lua script for cookie rewrite) | ⚠️ Requires EnvoyFilter<br>(Lua script for cookie rewrite) | **Envoy**: Medium<br>**Istio**: Medium |

---

**Features with Better Support in Envoy Gateway:**

- ✅ HSTS headers (native vs Lua script)
- ✅ Body size limits (native vs complex EnvoyFilter)
- ✅ Session cookie "Secure" attribute (native vs Lua script)
- ✅ Cleaner resource model overall

**Features with Better Support in Istio:**

- ✅ Timeouts (simpler, in HTTPRoute)
- ✅ Observability and metrics
- ✅ Advanced traffic management
- ✅ Service mesh integration (if needed later)

**Features Equal in Both:**

- 🏆 SSL redirect
- 🏆 App root redirect
- 🏆 Cookie path rewriting (both need Lua)
- 🏆 Basic routing functionality

---

## Pro and Cons list

### Envoy Gateway

**Pros ✅**

Native Gateway API Support

- Built specifically for Kubernetes Gateway API
- Clean, purpose-built abstractions
- Better alignment with Gateway API evolution

Simpler Configuration Model

- Fewer resource types needed
- More features available declaratively without scripting
- ClientTrafficPolicy and BackendTrafficPolicy provide clear separation

Modern Architecture

- Focused on gateway use case (not full service mesh)
- Lighter weight, faster startup
- Less resource overhead compared to full Istio

Better Defaults

- Sensible out-of-box configuration
- Less tuning required for common use cases

Easier Troubleshooting

- Simpler architecture means fewer moving parts
- More straightforward debugging
- Clear resource boundaries

Progressive Enhancement

- Start simple with Gateway API
- Add EnvoyExtensionPolicy only when needed
- Gradual learning curve

**Cons ❌**

Newer Technology

- Less mature than Istio (first stable release: late 2023)
- Smaller community
- Fewer production deployments

Limited Ecosystem

- Fewer integrations with other tools
- Less third-party tooling support
- Fewer examples and patterns

Feature Gaps

- Some advanced features require EnvoyExtensionPolicy
- Less comprehensive than Istio for edge cases
- Limited observability compared to Istio

Documentation

- Less comprehensive documentation
- Fewer real-world examples
- Smaller knowledge base

Migration Uncertainty

- Less clear migration paths from other solutions
- Fewer documented case studies

### Istio (with Gateway API)

**Pros ✅**

Production-Proven

- Battle-tested in large-scale deployments
- Mature codebase (5+ years)
- Known stability characteristics

Rich Feature Set

- Comprehensive traffic management
- Advanced security features
- Full service mesh capabilities available

Extensive Ecosystem

- Large community
- Many integrations (monitoring, tracing, etc.)
- Rich third-party tool support

Enterprise Support

- Multiple vendors offer commercial support
- Extensive documentation
- Professional services available

Observability

- Built-in metrics and tracing
- Integration with Prometheus, Jaeger, Zipkin
- Kiali for visualization

Flexibility

- EnvoyFilter provides unlimited customization
- Can handle complex edge cases
- Extensible architecture

Migration Path

- Clear upgrade paths from older versions
- Well-documented breaking changes
- Backward compatibility focus

**Cons ❌**

Complexity

- Steeper learning curve
- More resources to manage (Istiod, sidecars optionally)
- Harder to troubleshoot issues

Resource Overhead

- Control plane (Istiod) resource usage
- More memory and CPU compared to Envoy Gateway
- Larger container images

Configuration Verbosity

- Many features require EnvoyFilter with Lua
- More boilerplate code
- Multiple resources for simple tasks

Gateway API Support

- Gateway API support is "on top of" existing Istio APIs
- Some impedance mismatch between Gateway API and Istio concepts
- Not as clean as purpose-built Gateway API implementation

Maintenance Burden

- More components to update
- Complex upgrade process
- More potential failure points

Overkill for Simple Use Cases

- Full service mesh capabilities not always needed
- Gateway-only use case doesn't leverage full value

---

## Migration Complexity Matrix

| Feature | Nginx Effort | Envoy Gateway Effort | Istio Effort | Winner |
|---------|--------------|---------------------|--------------|---------|
| **Session Affinity** | 1 annotation | 1 resource (native) | 2 resources (DestinationRule + EnvoyFilter) | 🥇 Envoy Gateway |
| **SSL Redirect** | 1 annotation | 1 HTTPRoute | 1 HTTPRoute | 🏆 Tie |
| **HSTS Headers** | 4 annotations | 1 resource (native) | 1 EnvoyFilter (Lua) | 🥇 Envoy Gateway |
| **Body Size Limit** | 2 annotations | 1 resource (native) | 1 EnvoyFilter (complex) | 🥇 Envoy Gateway |
| **Timeouts** | 2 annotations | 2 resources | 1 HTTPRoute | 🥇 Istio |
| **Cookie Path Rewrite** | 1 annotation | 1 resource (Lua) | 1 EnvoyFilter (Lua) | 🏆 Tie |
| **App Root Redirect** | 1 annotation | 1 HTTPRoute | 1 HTTPRoute | 🏆 Tie |

---
**← Back to [Main Guide](../README.md)**
