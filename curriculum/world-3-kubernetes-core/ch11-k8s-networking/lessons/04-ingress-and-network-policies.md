# Lesson 4: Ingress and Network Policies

## Ingress: HTTP Routing Into the Cluster

NodePort works for getting traffic into the cluster, but it has limitations:
- Only ports 30000-32767
- One port per Service
- No TLS termination
- No host-based or path-based routing

**Ingress** solves all of these. It's a Kubernetes resource that defines HTTP routing rules — which hostname or URL path maps to which Service.

### Two Parts: Controller + Resource

Ingress requires two things:

1. **Ingress Controller:** A reverse proxy that runs inside the cluster (nginx, Traefik, HAProxy, etc.) and implements the routing rules
2. **Ingress Resource:** A YAML manifest that defines the routing rules themselves

```
Internet
    │
    ▼
[Ingress Controller (nginx)]  ← runs as a Deployment + Service
    │
    ├── Host: app.nocappuccino.com → frontend-svc:80
    ├── Path: /api/*               → backend-svc:80
    └── Path: /metrics/*           → monitoring-svc:80
```

The Ingress Controller watches the API Server for Ingress resources and configures its reverse proxy accordingly.

### Ingress Resource YAML

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: learn-nocappuccino-ingress
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: nocappuccino.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: learn-frontend-svc
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: learn-backend-svc
                port:
                  number: 80
```

#### Key Fields

**`spec.rules[].host`** — hostname to match (requires DNS or /etc/hosts configuration)

**`spec.rules[].http.paths[].path`** — URL path to match

**`spec.rules[].http.paths[].pathType`:**
- `Prefix`: Matches the path prefix (`/api` matches `/api`, `/api/v1`, `/api/users`)
- `Exact`: Matches only the exact path (`/api` matches only `/api`, not `/api/v1`)

**`spec.rules[].http.paths[].backend`** — which Service to route to

### When to Use Ingress vs. NodePort vs. LoadBalancer

| Scenario | Use |
|----------|-----|
| Multiple Services, one external IP, host/path routing | Ingress |
| Simple external access, one Service | NodePort or LoadBalancer |
| Internal services only | ClusterIP |
| TLS termination needed | Ingress (handles TLS) |

### Ingress in kind

kind doesn't come with an Ingress Controller by default. You can install one:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

For this chapter's challenges, we'll use NodePort and port-forward instead of Ingress. Ingress is covered conceptually here because it's essential knowledge for production K8s.

---

## Network Policies: Controlling Traffic

By default, Kubernetes allows **all traffic between all Pods**. Every Pod can talk to every other Pod, in any namespace. This is convenient for development but dangerous for production.

**NetworkPolicies** let you control which Pods can communicate with each other. They work like firewall rules.

### Default Behavior

```
Without NetworkPolicies:
  Pod A ──► Pod B    ✓ (allowed)
  Pod A ──► Pod C    ✓ (allowed)
  Pod B ──► Pod C    ✓ (allowed)
  Any   ──► Any     ✓ (everything open)
```

### Default Deny All

The first step in securing a namespace: deny all traffic by default, then allow specific communication.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: learn-default-deny
  namespace: learn-ch11
spec:
  podSelector: {}          # Empty = applies to ALL Pods in the namespace
  policyTypes:
    - Ingress              # Block all incoming traffic
    - Egress               # Block all outgoing traffic
```

After applying this, **no Pod in learn-ch11 can send or receive any traffic** — not even DNS queries. You'll need to add specific allow rules.

### Allow Specific Traffic

Allow frontend Pods to talk to backend Pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: learn-allow-frontend-to-backend
  namespace: learn-ch11
spec:
  podSelector:
    matchLabels:
      app: backend          # This policy applies to backend Pods
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend   # Allow traffic FROM frontend Pods
      ports:
        - protocol: TCP
          port: 5678          # Only on this port
```

### Allow DNS (Critical)

If you have a default-deny policy, Pods can't resolve DNS names. You need to explicitly allow DNS egress:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: learn-allow-dns
  namespace: learn-ch11
spec:
  podSelector: {}          # All Pods
  policyTypes:
    - Egress
  egress:
    - to: []               # Any destination
      ports:
        - protocol: UDP
          port: 53          # DNS
        - protocol: TCP
          port: 53          # DNS over TCP
```

### NetworkPolicy Behavior Rules

1. **If no NetworkPolicy selects a Pod, all traffic is allowed** (default open)
2. **If any NetworkPolicy selects a Pod, traffic is denied unless explicitly allowed** (default deny for that Pod)
3. **NetworkPolicies are additive** — multiple policies on the same Pod combine with OR (if any policy allows it, it's allowed)
4. **NetworkPolicies are namespace-scoped** — they apply only to Pods in their namespace

### Cross-Namespace Policies

Allow backend Pods to talk to a database in a different namespace:

```yaml
spec:
  podSelector:
    matchLabels:
      app: database
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: learn-ch11    # From Pods in this namespace
          podSelector:
            matchLabels:
              app: backend        # AND with this label
```

### CNI Support

**Important:** NetworkPolicies require a CNI plugin that supports them. kindnet (the default in kind) has **limited** NetworkPolicy support. Calico and Cilium fully support NetworkPolicies.

For kind, you can install Calico for full NetworkPolicy support:

```bash
# Remove kindnet and install Calico (if needed for network policy challenges)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

---

## Putting It Together: A Secured Stack

```
Internet
    │
    ▼
[Ingress / NodePort]
    │
    ▼
[Frontend Pods]     NetworkPolicy: allow ingress from Ingress
    │                              allow egress to backend
    ▼
[Backend Pods]      NetworkPolicy: allow ingress from frontend only
    │                              allow egress to database
    ▼
[Database Pods]     NetworkPolicy: allow ingress from backend only
                                   deny all other traffic
```

Each tier only accepts traffic from the tier above it. No lateral movement. If the frontend is compromised, the attacker can reach the backend but not the database directly.

---

## Summary

| Concept | What it is |
|---------|-----------|
| Ingress Controller | Reverse proxy (nginx, Traefik) that implements routing rules |
| Ingress Resource | YAML defining host/path → Service routing |
| `pathType: Prefix` | Match URL path prefix |
| NetworkPolicy | Firewall rules for Pod-to-Pod traffic |
| Default deny | Block all traffic, then allow specific flows |
| `podSelector` | Which Pods a NetworkPolicy applies to |
| `ingress` / `egress` | Incoming / outgoing traffic rules |
| `namespaceSelector` | Allow traffic from/to specific namespaces |

---

Time to put networking into practice. Head to the challenges.

**Challenges:**
- [Challenge 1: Service Discovery](../challenges/01-service-discovery.md) — Connect frontend to backend via ClusterIP
- [Challenge 2: Expose Externally](../challenges/02-expose-externally.md) — NodePort access
- [Challenge 3: Network Segmentation](../challenges/03-network-segmentation.md) — NetworkPolicies
- [Challenge 4: Debug DNS](../challenges/04-debug-dns.md) — Fix broken DNS resolution
