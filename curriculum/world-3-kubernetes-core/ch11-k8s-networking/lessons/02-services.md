# Lesson 2: Services

## The Problem With Pod IPs

Pod IPs are ephemeral. They change on every restart, scaling event, and rolling update. You can't build a reliable system on addresses that vanish and reappear.

In Docker, we solved this with user-defined bridge networks and built-in DNS. In Kubernetes, we solve it with **Services**.

A Service is a stable, virtual endpoint that sits in front of a group of Pods. It has:
- A **fixed ClusterIP** that never changes
- A **DNS name** that always resolves
- **Load balancing** across all healthy Pods matching its selector

Think of it this way: instead of calling individual baristas by their direct line (which changes every shift), you call the coffee bar's main number (the Service). The same number always works, regardless of who's on shift.

---

## How Services Find Pods: Labels and Selectors

Services don't reference Pods by name. They use **label selectors** — they claim ownership of any Pod that has certain labels.

```yaml
# Service selector:
selector:
  app: backend          # "Route traffic to Pods with app=backend"

# Pod labels:
labels:
  app: backend          # This Pod is included in the Service
  version: "2.0"
```

Any Pod with matching labels in the same namespace becomes a backend for this Service. Add a new Pod with the same labels → it automatically joins. Remove or crash a Pod → the Service stops routing to it.

This decoupling is intentional. Services and Pods are managed independently. You can scale Pods without touching the Service. You can change which Pods a Service targets by changing labels.

---

## Service Types

### ClusterIP (Default)

The most common type. Creates a virtual IP that's only reachable **inside the cluster**.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-backend-svc
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
spec:
  type: ClusterIP       # Default — you can omit this
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 80           # Port the Service listens on
      targetPort: 5678   # Port the container actually runs on
```

When you create this Service, Kubernetes:
1. Allocates a virtual IP from the cluster's service CIDR (e.g., `10.96.0.50`)
2. Creates a DNS record: `learn-backend-svc.learn-ch11.svc.cluster.local`
3. Programs iptables rules on every node to forward traffic to that VIP → healthy Pods

Any Pod in the cluster can reach the backend at:
- `http://learn-backend-svc` (same namespace)
- `http://learn-backend-svc.learn-ch11` (from another namespace)
- `http://learn-backend-svc.learn-ch11.svc.cluster.local` (fully qualified)

**Use for:** Internal service-to-service communication — APIs, databases, caches.

### NodePort

Exposes the Service on a port on **every node** in the cluster. External traffic reaches the Service at `<any-node-IP>:<nodePort>`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-frontend-svc
  namespace: learn-ch11
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80            # Internal ClusterIP port
      targetPort: 8080    # Container port
      nodePort: 30080     # External port (range: 30000-32767)
```

NodePort builds on ClusterIP — you get both a ClusterIP (internal) and a nodePort (external).

**Use for:** Dev/test external access, bare-metal clusters, kind clusters.

**Limitation:** NodePort exposes a port on *every* node. Port range is limited to 30000-32767.

### LoadBalancer

The cloud-native way to expose a Service externally. Kubernetes asks your cloud provider to provision an actual load balancer (AWS ALB, GCP NLB, Azure LB).

```yaml
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 8080
```

In kind (local), LoadBalancer Services stay in `<pending>` for the external IP — there's no cloud provider. Use NodePort or `kubectl port-forward` for local access.

**Use for:** Production external access on cloud.

### Service Type Summary

| Type | Reachable From | Use Case |
|------|---------------|----------|
| ClusterIP | Inside cluster only | Internal APIs, databases, caches |
| NodePort | Any node IP + port | Dev/test external access |
| LoadBalancer | Cloud-provisioned IP | Production external access |
| ExternalName | DNS alias | Pointing cluster DNS at external services |

---

## How kube-proxy Routes Traffic

When you create a Service, kube-proxy on every node watches for the change and updates **iptables rules** (or IPVS tables):

```
Traffic to 10.96.0.50:80 (ClusterIP)
  └─► iptables DNAT rule: forward to one of:
        10.244.1.5:5678 (Pod 1)
        10.244.2.8:5678 (Pod 2)
        10.244.1.9:5678 (Pod 3)
```

The DNAT (Destination NAT) rules replace the destination IP before the packet is forwarded. The client never knows which Pod it hit — it just sent to the Service IP and got a response.

kube-proxy supports two modes:
- **iptables mode** (default): Programs iptables rules directly. Good for most clusters.
- **IPVS mode**: Uses Linux IPVS for load balancing. Better for large clusters (10,000+ Services).

---

## EndpointSlices: The Pod Registry

When you create a Service, Kubernetes automatically creates an **EndpointSlice** that tracks the actual Pod IPs backing the Service.

```bash
# See endpoints for a Service
kubectl get endpointslices -n learn-ch11 -l kubernetes.io/service-name=learn-backend-svc

# Or the legacy Endpoints resource
kubectl get endpoints learn-backend-svc -n learn-ch11
```

If the endpoint list is empty (`<none>`), the Service's selector isn't matching any Pods. Check:
1. Do the Pods have the right labels? (`kubectl get pods --show-labels -n learn-ch11`)
2. Are the Pods `Running`? (Only healthy Pods are included)
3. Does the selector match the labels exactly? (Case-sensitive!)

**This is the #1 debugging step for "my Service isn't working."**

---

## `port` vs `targetPort`

This confuses everyone at first:

```yaml
ports:
  - port: 80          # What callers use: http://service:80
    targetPort: 5678  # Where traffic actually goes: container port 5678
```

- `port`: The Service's external-facing port (what other Pods call)
- `targetPort`: The container's listening port (where the app actually runs)

This decoupling lets you change the app's listening port without changing the port that all callers use.

---

## kubectl port-forward: Local Testing

For local development with kind, `port-forward` creates a tunnel from your laptop to a Pod or Service:

```bash
# Forward localhost:8080 to port 80 on the Service
kubectl port-forward service/learn-backend-svc 8080:80 -n learn-ch11

# Forward to a specific Pod
kubectl port-forward pod/<pod-name> 8080:80 -n learn-ch11
```

Access the app at `http://localhost:8080` while the command runs. `port-forward` bypasses kube-proxy — it connects directly to the Pod. Good for debugging, not for production traffic.

---

## Summary

| Concept | What it is |
|---------|-----------|
| Service | Stable virtual endpoint (IP + DNS name) in front of a group of Pods |
| ClusterIP | Service type reachable only inside the cluster (default) |
| NodePort | Service type reachable at `<node-ip>:<port>` from outside |
| LoadBalancer | Service type that provisions a cloud load balancer |
| Selector | How a Service finds its backing Pods (by labels) |
| EndpointSlice | Tracks the actual Pod IPs backing a Service |
| kube-proxy | Programs iptables rules on each node for Service routing |
| `port` vs `targetPort` | Service port vs container port |
| `port-forward` | Tunnel from localhost to a Pod/Service (dev/debug only) |

---

Up next: [Lesson 3 — DNS and Discovery](03-dns-and-discovery.md)

Services give you a stable IP. But typing `10.96.0.50` isn't much better than typing a Pod IP. You need names. That's where CoreDNS comes in.
