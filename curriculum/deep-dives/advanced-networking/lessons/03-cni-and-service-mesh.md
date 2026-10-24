# Lesson 03: CNI and Service Mesh

> "Kubernetes doesn't implement networking itself — it delegates to plugins. Understanding this delegation model explains why there are so many networking options and why they behave differently."
> — Sarah

---

## Why Kubernetes Delegates Networking

Kubernetes has a clear networking model — every pod gets its own IP, every pod can reach every other pod without NAT — but it deliberately does NOT implement how this works. Instead, it defines an interface (**CNI — Container Network Interface**) and lets plugins handle the implementation.

Why? Because networking requirements vary dramatically:
- A small dev cluster doesn't need the same solution as a 5,000-node production cluster
- Some environments need network policies; others need eBPF acceleration
- Cloud providers have their own VPC networking that CNI plugins can integrate with

---

## What CNI Actually Does

CNI is a specification. A CNI plugin is an executable that the container runtime calls when a pod starts or stops. The runtime passes the network namespace as an argument, and the plugin:

1. **On pod creation (ADD):**
   - Creates a veth pair
   - Places one end in the pod's network namespace
   - Connects the other end to the node's network
   - Assigns an IP address to the pod
   - Sets up routes so other pods can reach this one

2. **On pod deletion (DEL):**
   - Removes the veth pair
   - Releases the IP address
   - Cleans up routes

The configuration lives at `/etc/cni/net.d/` on each node.

```bash
# On a kind node:
docker exec <kind-node> ls /etc/cni/net.d/
docker exec <kind-node> cat /etc/cni/net.d/10-kindnet.conflist
```

---

## Common CNI Plugins

### Flannel — Simple Overlay

**What it does:** Creates a flat, overlay network across all nodes using VXLAN encapsulation.

```
Node A                          Node B
┌────────────┐                  ┌────────────┐
│ Pod 1      │                  │ Pod 2      │
│ 10.244.0.5 │                  │ 10.244.1.3 │
│     │      │                  │     │      │
│  cni0 bridge                  │  cni0 bridge
│     │      │                  │     │      │
│  flannel.1 │─── VXLAN ───────│  flannel.1 │
│  (VTEP)    │   tunnel         │  (VTEP)    │
└────────────┘                  └────────────┘
```

- Each node gets a subnet (e.g., Node A = `10.244.0.0/24`, Node B = `10.244.1.0/24`)
- Cross-node traffic is encapsulated in VXLAN packets
- **Pros:** Simple, works everywhere, easy to debug
- **Cons:** No network policies, VXLAN adds overhead (~50 bytes per packet)

**Best for:** Small clusters, dev environments, learning

### Calico — Policy-Rich Networking

**What it does:** Uses BGP (Border Gateway Protocol) to route pod traffic without overlay encapsulation. Includes a powerful network policy engine.

```
Node A                          Node B
┌────────────┐                  ┌────────────┐
│ Pod 1      │                  │ Pod 2      │
│ 10.244.0.5 │                  │ 10.244.1.3 │
│     │      │                  │     │      │
│  veth pair │                  │  veth pair │
│     │      │                  │     │      │
│  routing   │─── BGP ─────────│  routing   │
│  table     │   (L3 routes)   │  table     │
└────────────┘                  └────────────┘
```

- Routes pod IPs directly using the node's routing table (no encapsulation)
- Can fall back to VXLAN/IPIP overlay when direct routing isn't possible
- Implements Kubernetes NetworkPolicy and its own richer policy model (GlobalNetworkPolicy)
- **Pros:** No overhead from encapsulation, rich policy support, scales well
- **Cons:** More complex setup, BGP may not work in all environments

**Best for:** Production clusters that need network policies

### Cilium — eBPF-Powered Networking

**What it does:** Uses eBPF programs attached to the Linux kernel to handle networking, replacing iptables entirely.

```
Node A
┌──────────────────────────┐
│ Pod 1                    │
│ 10.244.0.5               │
│     │                    │
│  eBPF program            │  ← Packet processing in kernel
│  (attached to TC hook)   │     No iptables rules needed
│     │                    │
│  Node routing            │
└──────────────────────────┘
```

- eBPF programs run in the kernel with near-native performance
- Replaces kube-proxy entirely (no iptables rules for Services)
- Provides L7 visibility (HTTP methods, gRPC status codes, DNS queries)
- Built-in service mesh capabilities (Cilium Service Mesh)
- **Pros:** Best performance, deep observability, no iptables scaling issues
- **Cons:** Requires newer kernels (5.10+), more complex to operate

**Best for:** Large production clusters, performance-sensitive workloads, teams that want observability

### Kind's Default: kindnet

Kind uses its own minimal CNI plugin called **kindnet**. It's a simple bridge-based plugin designed specifically for kind clusters.

---

## Choosing a CNI Plugin

| Feature | Flannel | Calico | Cilium |
|---------|---------|--------|--------|
| Network policies | ❌ | ✅ (rich) | ✅ (eBPF-based) |
| Encryption | ❌ | ✅ (WireGuard) | ✅ (WireGuard/IPSec) |
| Performance | Good | Good (no overlay) | Best (eBPF) |
| L7 visibility | ❌ | ❌ | ✅ |
| Complexity | Low | Medium | High |
| Replaces kube-proxy | ❌ | ❌ | ✅ |

Other CNI plugins you may encounter: **AWS VPC CNI** (EKS), **Azure CNI** (AKS), **GKE CNI** (GKE), **Weave Net**, **Antrea** (VMware).

---

## Service Mesh: The Next Layer

A **service mesh** is an infrastructure layer that handles service-to-service communication. It solves problems that CNI plugins don't address:

### What Problems Service Meshes Solve

1. **Mutual TLS (mTLS):** Encrypt all pod-to-pod traffic automatically — no code changes
2. **Observability:** Golden signals (latency, traffic, errors, saturation) for every request between services — without instrumenting your code
3. **Traffic management:** Canary deployments, traffic splitting, circuit breaking, retries, timeouts — all configured declaratively
4. **Access control:** Define which services can talk to which, at the L7 level

### The Sidecar Proxy Model

Most service meshes work by injecting a **sidecar proxy** (typically Envoy) into every pod:

```
Pod
┌──────────────────────────────────┐
│                                  │
│  ┌──────────┐    ┌────────────┐  │
│  │ App      │───▶│ Envoy      │──┼──▶ Network
│  │ Container│◀───│ Sidecar    │◀─┼──  (other pods)
│  │          │    │ Proxy      │  │
│  └──────────┘    └────────────┘  │
│                       │          │
│                   iptables       │
│                   redirect       │
│                   (all traffic   │
│                    goes through  │
│                    the proxy)    │
│                                  │
└──────────────────────────────────┘
```

The sidecar intercepts all inbound and outbound traffic using iptables rules (or eBPF). The application doesn't know the proxy exists — it just sends normal HTTP/gRPC requests.

The control plane (e.g., Istio's `istiod`) pushes configuration to all the sidecars — routing rules, mTLS certificates, retry policies.

### Common Service Meshes

| Mesh | Sidecar | Control Plane | Notes |
|------|---------|---------------|-------|
| **Istio** | Envoy | istiod | Most feature-rich, most complex, most widely adopted |
| **Linkerd** | linkerd2-proxy (Rust) | linkerd-control-plane | Simpler, lighter, easier to operate |
| **Cilium Service Mesh** | None (eBPF) | Cilium agent | No sidecar needed — networking handled in kernel |
| **Consul Connect** | Envoy | Consul | HashiCorp ecosystem, multi-platform |

### When You Need a Service Mesh (and When You Don't)

**You probably need one if:**
- You have 20+ microservices and need consistent observability
- Compliance requires mTLS between all services
- You need canary/progressive deployments at the L7 level
- You can't instrument every service for distributed tracing

**You probably don't need one if:**
- You have fewer than 10 services
- NetworkPolicies and Kubernetes-native features cover your needs
- The added complexity and resource overhead isn't justified
- You're just starting with Kubernetes

> *Sarah speaking:* "Service meshes are powerful but heavy. I've seen teams add Istio before they needed it and spend more time debugging the mesh than their actual applications. Start with NetworkPolicies and Kubernetes-native traffic management. Add a mesh when you feel the pain it solves."

---

## Summary

- **CNI** is a plugin interface — Kubernetes delegates pod networking to CNI plugins
- **Flannel** is simple (VXLAN overlay), **Calico** adds policies (BGP routing), **Cilium** uses eBPF (best performance)
- CNI plugins handle pod IP assignment, veth pairs, and inter-node routing
- **Service meshes** add mTLS, observability, and traffic management on top of CNI networking
- Most meshes use sidecar proxies (Envoy) that intercept all traffic transparently
- Don't add a service mesh until you feel the pain it solves — they add real complexity

---

**Next:** Time for the challenges. Head to [Trace the Packet](../challenges/01-trace-the-packet.md).
