# Lesson 4: Network Security

> **Sarah:** "Right now, every pod can talk to every other pod. The frontend can reach the database directly — it shouldn't, it should only talk to the API. The worker can reach the internet with no restrictions. A compromised pod could exfiltrate data to any external address. NetworkPolicies are Kubernetes firewalls."

---

## The Default: No Isolation

By default, Kubernetes networking is completely flat:
- Every pod can reach every other pod across all namespaces
- Every pod can reach external addresses
- There are no firewall rules

This is convenient for development but dangerous in production. A single compromised pod can scan the entire cluster, access databases directly, and exfiltrate data to the internet.

---

## NetworkPolicy Basics

A NetworkPolicy controls traffic **to** and **from** pods in a namespace. It acts like a firewall rule.

### Default deny all ingress

The most important NetworkPolicy you can create:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: learn-ch15
spec:
  podSelector: {}        # Applies to ALL pods in the namespace
  policyTypes:
    - Ingress            # Controls incoming traffic
  # No ingress rules = deny all incoming traffic
```

Once this exists, **no pod in `learn-ch15` can receive traffic** unless explicitly allowed by another NetworkPolicy.

### Default deny all egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: learn-ch15
spec:
  podSelector: {}
  policyTypes:
    - Egress
  # No egress rules = deny all outgoing traffic
```

**Caution:** Denying all egress blocks DNS resolution too (DNS is egress traffic to port 53). You almost always need to allow DNS:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: learn-ch15
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to: []
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

---

## Allow Specific Traffic

After denying everything, whitelist what's needed.

### Allow frontend to reach API

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: learn-ch15
spec:
  podSelector:
    matchLabels:
      app: learn-api         # This policy applies to API pods
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: learn-frontend   # Only frontend pods can reach the API
      ports:
        - protocol: TCP
          port: 8080
```

### Allow API to reach database

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: learn-ch15
spec:
  podSelector:
    matchLabels:
      app: learn-db          # Applies to database pods
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: learn-api  # Only API pods can reach the DB
      ports:
        - protocol: TCP
          port: 5432
```

### Block frontend from reaching database directly

With default deny + the two policies above, the frontend can only reach the API, and the API can reach the database. The frontend cannot reach the database — there's no NetworkPolicy allowing it.

```
  Frontend ──→ API ──→ Database
  Frontend ──✗──→ Database (blocked by default deny)
```

---

## Namespace Isolation

Allow traffic from pods in a specific namespace:

```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            purpose: monitoring    # Only pods in namespaces with this label
        podSelector:
          matchLabels:
            app: prometheus        # AND only prometheus pods
```

The `namespaceSelector` and `podSelector` within the same `from` entry are **ANDed**: the source must be in a matching namespace AND match the pod selector.

If they're in separate `from` entries, they're **ORed**:

```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            purpose: monitoring    # Any pod in matching namespaces
      - podSelector:
          matchLabels:
            app: internal-tool     # OR any pod with this label (same namespace)
```

This distinction trips up many people.

---

## Egress Policies

Control where pods can send traffic to.

### Allow API to reach external HTTPS endpoints

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: learn-ch15
spec:
  podSelector:
    matchLabels:
      app: learn-api
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: learn-db      # Allow reaching the database
      ports:
        - protocol: TCP
          port: 5432
    - ports:                      # Allow DNS
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - ports:                      # Allow external HTTPS
        - protocol: TCP
          port: 443
```

### Restrict egress to specific CIDR ranges

```yaml
egress:
  - to:
      - ipBlock:
          cidr: 10.0.0.0/8       # Internal network
      - ipBlock:
          cidr: 0.0.0.0/0        # All external
          except:
            - 169.254.169.254/32  # Block metadata service (cloud security)
```

Blocking the cloud metadata service (`169.254.169.254`) is a critical security measure. This endpoint exposes IAM credentials and instance metadata in AWS, GCP, and Azure. A compromised pod with access to the metadata service can potentially access cloud resources.

---

## CNI Requirements

NetworkPolicies are enforced by the **CNI plugin**, not by Kubernetes itself. Your CNI must support NetworkPolicy:

| CNI Plugin | NetworkPolicy support |
|-----------|----------------------|
| Calico | Full support (most common) |
| Cilium | Full support + extended features |
| Weave Net | Full support |
| Flannel | **No support** — policies are silently ignored |

In a kind cluster, the default CNI is kindnet (a simple CNI). To use NetworkPolicies with kind, install Calico:

```bash
# Disable the default CNI and install Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

**Important:** If your CNI doesn't support NetworkPolicy, creating NetworkPolicy objects does nothing — the YAML is accepted but no rules are enforced. Always verify your CNI.

---

## Admission Controllers and Policy Engines (Concepts)

NetworkPolicies control network traffic. For broader policy enforcement (what images can be deployed, what capabilities are allowed, what labels are required), Kubernetes uses admission controllers.

### OPA Gatekeeper

An open-source policy engine for Kubernetes:
- Write policies in Rego (a policy language)
- Enforce rules like "all Deployments must have resource limits" or "no images from untrusted registries"
- Audit existing resources against policies

### Kyverno

A Kubernetes-native policy engine:
- Policies are written in YAML (no Rego)
- Can validate, mutate, and generate resources
- Easier learning curve than Gatekeeper

### Examples of policies you'd enforce

- All pods must have resource requests and limits
- No container can run as root
- Images must come from an approved registry
- All Deployments must have at least 2 replicas
- Secrets must not contain keys matching `*PASSWORD*` in their `data` section of ConfigMaps

These tools turn security best practices into automated guardrails.

---

## Quick Reference

```bash
# List NetworkPolicies
kubectl get networkpolicy -n <namespace>

# Describe a NetworkPolicy
kubectl describe networkpolicy <name> -n <namespace>

# Test connectivity from one pod to another
kubectl exec <source-pod> -n <namespace> -- wget -qO- --timeout=3 http://<target-service>:<port>

# Test connectivity (with curl)
kubectl exec <source-pod> -n <namespace> -- curl -s --max-time 3 http://<target-service>:<port>

# Verify default deny is working (should timeout)
kubectl exec <frontend-pod> -n <namespace> -- wget -qO- --timeout=3 http://learn-db:5432
```

---

> **Sarah:** "The pattern is always the same: deny everything, then allow exactly what's needed. Default deny ingress, default deny egress, then whitelist. If you start from 'allow everything and restrict later,' you'll never get around to restricting."

**Now let's apply everything: [Challenge 01 — RBAC Lockdown](../challenges/01-rbac-lockdown.md)**
