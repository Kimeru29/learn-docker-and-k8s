# Lesson 3: DNS and Discovery

## CoreDNS: The Cluster's Phone Book

Every Kubernetes cluster runs **CoreDNS** — a DNS server deployed as a Deployment in the `kube-system` namespace. It's responsible for resolving Service names to their ClusterIPs.

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get service kube-dns -n kube-system
```

When a Pod starts, Kubernetes injects DNS configuration into `/etc/resolv.conf` inside the Pod:

```
nameserver 10.96.0.10     # CoreDNS ClusterIP
search learn-ch11.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

This configuration does two things:
1. Points all DNS queries to CoreDNS (`nameserver`)
2. Sets up **search domains** so short names resolve automatically

---

## Service DNS Names

Every Service gets a DNS record. The full format is:

```
<service-name>.<namespace>.svc.cluster.local
```

But thanks to search domains, you can use shorter versions:

| DNS Name | Works From | Example |
|----------|-----------|---------|
| `learn-backend-svc` | Same namespace only | `curl http://learn-backend-svc` |
| `learn-backend-svc.learn-ch11` | Any namespace | `curl http://learn-backend-svc.learn-ch11` |
| `learn-backend-svc.learn-ch11.svc.cluster.local` | Anywhere in cluster | Full FQDN |

**How search domains work:** When a Pod looks up `learn-backend-svc`, the DNS resolver appends each search domain in order:
1. `learn-backend-svc.learn-ch11.svc.cluster.local` → found! Use this.
2. (If not found: `learn-backend-svc.svc.cluster.local` → not found)
3. (If not found: `learn-backend-svc.cluster.local` → not found)
4. (If not found: try as external domain → not found)

This is why `curl http://learn-backend-svc` works from the same namespace — DNS automatically resolves it.

### Cross-Namespace Communication

To call a Service in a different namespace, you must include the namespace:

```bash
# From a Pod in learn-ch11, calling a Service in learn-ch10:
curl http://learn-cache-headless.learn-ch10

# Using the full FQDN:
curl http://learn-cache-headless.learn-ch10.svc.cluster.local
```

The short form (`learn-cache-headless` alone) only works within the same namespace.

---

## Headless Services and Pod DNS

A **headless Service** (`clusterIP: None`) doesn't allocate a ClusterIP. Instead, DNS queries return the **individual Pod IPs** directly.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-db-headless
  namespace: learn-ch11
spec:
  clusterIP: None
  selector:
    app: database
  ports:
    - port: 5432
```

**Regular Service DNS:** `nslookup learn-backend-svc` → returns ClusterIP (e.g., `10.96.0.50`)

**Headless Service DNS:** `nslookup learn-db-headless` → returns Pod IPs directly (e.g., `10.244.0.8`, `10.244.0.9`)

### StatefulSet Pod DNS

When combined with a StatefulSet, headless Services provide DNS for each individual Pod:

```
learn-db-0.learn-db-headless.learn-ch11.svc.cluster.local → 10.244.0.8
learn-db-1.learn-db-headless.learn-ch11.svc.cluster.local → 10.244.0.9
learn-db-2.learn-db-headless.learn-ch11.svc.cluster.local → 10.244.0.10
```

This is how distributed systems discover specific members. A replica can connect to the primary at `learn-db-0.learn-db-headless` regardless of its IP.

---

## Debugging DNS

DNS problems are among the most common networking issues in Kubernetes. Here's your diagnostic toolkit:

### Step 1: Spin Up a Debug Pod

```bash
kubectl run learn-dns-debug --rm -it \
  --restart=Never \
  --image=busybox:1.36 \
  -n learn-ch11 \
  -- /bin/sh
```

This gives you a shell inside the cluster. From here you can test DNS.

### Step 2: Check DNS Resolution

```bash
# Inside the debug Pod:
nslookup learn-backend-svc
nslookup learn-backend-svc.learn-ch11.svc.cluster.local

# Check what nameserver is configured
cat /etc/resolv.conf
```

Expected output for a working Service:
```
Server:    10.96.0.10
Address:   10.96.0.10:53

Name:      learn-backend-svc.learn-ch11.svc.cluster.local
Address:   10.96.0.50
```

If DNS fails:
```
** server can't find learn-backend-svc: NXDOMAIN
```

### Step 3: Diagnose

| Symptom | Likely Cause |
|---------|-------------|
| `NXDOMAIN` | Service doesn't exist, wrong name, or wrong namespace |
| Resolves but connection refused | Service exists but no endpoints (selector mismatch) |
| Timeout | CoreDNS not running or network issue |
| Wrong IP | Stale DNS cache (rare in K8s) |

### Step 4: Check CoreDNS Health

```bash
# Is CoreDNS running?
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Is the kube-dns Service healthy?
kubectl get endpoints kube-dns -n kube-system
```

---

## The `ndots:5` Setting

You might notice `ndots:5` in `/etc/resolv.conf`. This tells the DNS resolver: "If a name has fewer than 5 dots, try appending search domains first."

This means:
- `learn-backend-svc` (0 dots) → searches all domains first → works ✓
- `api.example.com` (2 dots) → searches all domains first → adds latency
- `some.deep.nested.name.com` (4 dots) → searches all domains first → more latency

For internal Service names, this is great. For external domains, it means extra DNS queries. In high-performance production setups, teams sometimes lower `ndots` or use FQDNs with a trailing dot (`api.example.com.`) to skip the search.

---

## ExternalName Services

A special Service type that maps a cluster-internal name to an external DNS name:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-external-api
  namespace: learn-ch11
spec:
  type: ExternalName
  externalName: api.nocappuccino.com
```

Now Pods can call `http://learn-external-api` and it resolves to `api.nocappuccino.com`. Useful for:
- Migrating services out of the cluster
- Abstracting external dependencies behind a cluster-internal name
- Switching between internal and external implementations without changing app code

---

## Summary

| Concept | What it is |
|---------|-----------|
| CoreDNS | DNS server running in kube-system; resolves Service names |
| Search domains | Automatically appended to short names for resolution |
| FQDN | `<svc>.<ns>.svc.cluster.local` — the fully qualified name |
| Headless Service | `clusterIP: None`; DNS returns Pod IPs directly |
| Pod DNS | StatefulSet Pods get individual DNS: `<pod>.<svc>.<ns>.svc.cluster.local` |
| `nslookup` | Tool to test DNS resolution from inside a Pod |
| `ndots:5` | Resolver tries search domains for names with fewer than 5 dots |
| ExternalName | Service type that aliases a cluster name to an external DNS name |

---

Up next: [Lesson 4 — Ingress and Network Policies](04-ingress-and-network-policies.md)

You can resolve Services by name. But how do external users reach your app? And how do you prevent Pods from talking to Pods they shouldn't?
