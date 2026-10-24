# Lesson 1: Pod Networking

## Every Pod Gets an IP

In Docker, you had to explicitly attach containers to networks and map ports. In Kubernetes, the networking model is simpler — and more powerful.

**The Kubernetes networking contract:**

1. **Every Pod gets its own IP address** — unique within the cluster
2. **All Pods can communicate with each other** by IP, without NAT
3. **Agents on a node (kubelet, kube-proxy) can talk to all Pods** on that node
4. **All nodes can communicate with all Pods** and vice versa

This means: if Pod A has IP `10.244.1.5` and Pod B has IP `10.244.2.8`, Pod A can reach Pod B at `10.244.2.8` directly, even if they're on different nodes.

No port mapping. No NAT. No explicit network attachments. Just flat networking.

---

## The Flat Network Model

Kubernetes requires a **flat network** — every Pod can reach every other Pod by IP, regardless of which node they're on. This is a cluster-wide requirement.

```
Node 1 (192.168.0.10)              Node 2 (192.168.0.11)
┌──────────────────────┐           ┌──────────────────────┐
│  Pod A: 10.244.1.5   │ ────────► │  Pod C: 10.244.2.8   │
│  Pod B: 10.244.1.6   │           │  Pod D: 10.244.2.9   │
│                      │ ◄──────── │                      │
│  Pod CIDR: 10.244.1/24│          │  Pod CIDR: 10.244.2/24│
└──────────────────────┘           └──────────────────────┘
```

Each node gets a **Pod CIDR** — a subnet range for Pod IPs on that node. The CNI plugin handles routing between these subnets.

### Why Flat?

This design decision has consequences:

- **No port conflicts:** Each Pod has its own IP, so multiple Pods can listen on port 80 without conflicting
- **No NAT complexity:** The source and destination IPs in packets are always Pod IPs — no translation needed
- **Simpler application code:** Apps don't need to know about port mapping or host networking — they just bind to a port

Compare this to Docker's default bridge network, where containers share the host's IP and need explicit port mapping (`-p 8080:80`). Kubernetes eliminated that complexity.

---

## CNI: The Network Plugin

Kubernetes doesn't implement networking itself. It delegates to a **CNI (Container Network Interface)** plugin. The CNI plugin is responsible for:

1. Assigning IP addresses to Pods
2. Setting up network routes between nodes
3. Ensuring Pod-to-Pod connectivity across the cluster

### Common CNI Plugins

| Plugin | How it Works | Used In |
|--------|-------------|---------|
| **kindnet** | Simple, VXLAN-based | kind clusters (default) |
| **Calico** | BGP routing or VXLAN, supports NetworkPolicies | Production clusters |
| **Cilium** | eBPF-based, advanced observability | Modern production clusters |
| **Flannel** | VXLAN overlay | Simpler production setups |
| **Weave Net** | Mesh networking | Smaller clusters |

In your kind cluster, **kindnet** is the CNI plugin. You can see it running:

```bash
kubectl get pods -n kube-system -l app=kindnet
```

### How Pod Networking Works (Under the Hood)

When a Pod is created on a node:

1. kubelet calls the CNI plugin
2. CNI creates a **veth pair** — a virtual network cable connecting the Pod's network namespace to the node's network
3. CNI assigns an IP from the node's Pod CIDR
4. CNI sets up routing rules so the Pod can reach other Pods

For cross-node communication, the CNI plugin typically uses one of:
- **VXLAN:** Encapsulates Pod traffic in UDP packets between nodes (overlay network)
- **BGP:** Advertises Pod CIDR routes to the physical network (no encapsulation, faster)
- **eBPF:** Cilium's approach — programs the kernel directly for routing decisions

You don't configure this directly — it's set up when the cluster is created. But understanding it helps when packets aren't reaching their destination.

---

## Pod Networking in Practice

### Finding Pod IPs

```bash
# See Pod IPs
kubectl get pods -n learn-ch11 -o wide

# Output:
# NAME                    READY   STATUS    IP            NODE
# learn-backend-abc12     1/1     Running   10.244.0.8    learn-k8s-control-plane
# learn-frontend-def34    1/1     Running   10.244.0.9    learn-k8s-control-plane
```

### Communicating by IP (Don't Do This)

You *can* reach a Pod by its IP:

```bash
kubectl exec learn-frontend-def34 -n learn-ch11 -- curl 10.244.0.8:5678
```

But you **should never** rely on Pod IPs because:

1. **They change on every restart.** Delete a Pod, get a new one with a different IP.
2. **They change on rolling updates.** New ReplicaSet, new Pods, new IPs.
3. **They change on rescheduling.** Node failure → Pod rescheduled → new IP.

This is why Services exist — and that's the topic of Lesson 2.

---

## Containers Within a Pod: Shared Network

Containers in the same Pod share a network namespace. They:
- Share the same IP address
- Can reach each other on `localhost`
- Must use different ports (port 80 can only be bound by one container)

```
Pod (IP: 10.244.0.8)
┌────────────────────────────────┐
│  Container A (port 80)         │
│       ↕ localhost:8080         │
│  Container B (port 8080)       │
└────────────────────────────────┘
```

This is useful for sidecar patterns — a web server container and a log shipper container in the same Pod, where the log shipper reads logs from a shared volume and the web server handles requests.

---

## Summary

| Concept | What it is |
|---------|-----------|
| Pod IP | Unique IP assigned to each Pod; ephemeral (changes on restart) |
| Flat network | Every Pod can reach every other Pod by IP, no NAT |
| CNI | Container Network Interface; plugin that implements Pod networking |
| Pod CIDR | Subnet range assigned to a node for its Pods |
| veth pair | Virtual network cable connecting Pod network namespace to node |
| Shared network | Containers in the same Pod share IP and can use localhost |
| Don't hardcode IPs | Pod IPs are ephemeral; use Services instead |

---

Up next: [Lesson 2 — Services](02-services.md)

Pod IPs change. You need stable endpoints. That's what Services are for.
