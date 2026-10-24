# Lesson 02: iptables and NAT

> "Port mapping isn't magic — it's iptables. And once you can read iptables rules, you can debug almost any networking mystery in Docker or Kubernetes."
> — Sarah

---

## What iptables Does

**iptables** is the Linux kernel's packet filtering and NAT framework. When Docker maps port 8080 on the host to port 80 in a container, it creates iptables rules that rewrite packet destinations. When kube-proxy routes traffic to pods, it does the same thing.

Understanding iptables rules is the key to debugging "port mapping doesn't work" and "Service can't reach pods" problems.

---

## iptables Basics

iptables organizes rules into **tables** and **chains**:

| Table | Purpose |
|-------|---------|
| **nat** | Network Address Translation — rewrite source/destination IP and port |
| **filter** | Accept, drop, or reject packets — the firewall |
| **mangle** | Modify packet headers (TTL, TOS, etc.) |
| **raw** | Low-level packet handling before connection tracking |

Docker primarily uses the **nat** table (for port mapping) and the **filter** table (for inter-container isolation).

Each table has **chains** — ordered lists of rules that packets traverse:

```
Incoming packet → PREROUTING (nat) → routing decision
    ├── for this host → INPUT (filter) → local process
    └── forwarded → FORWARD (filter) → POSTROUTING (nat) → outgoing

Local process → OUTPUT (nat) → routing decision → POSTROUTING (nat) → outgoing
```

---

## Docker's Port Mapping: DNAT

Start a container with port mapping:

```bash
docker run -d --name learn-dd-net-iptables \
  --label app=learn-docker-k8s --label track=deep-dive \
  -p 9090:80 \
  nginx:alpine
```

Now let's find the iptables rule Docker created.

### On Linux

```bash
sudo iptables -t nat -L -n --line-numbers
```

### On Docker Desktop (inside the VM)

```bash
docker run --rm --privileged --network=host \
  alpine sh -c 'apk add --no-cache iptables > /dev/null 2>&1 && iptables -t nat -L -n --line-numbers'
```

### What you'll find

Look for the `DOCKER` chain in the `PREROUTING` and `OUTPUT` sections:

```
Chain PREROUTING (policy ACCEPT)
num  target     prot opt source     destination
1    DOCKER     all  --  0.0.0.0/0  0.0.0.0/0    ADDRTYPE match dst-type LOCAL

Chain DOCKER (2 references)
num  target     prot opt source     destination
1    RETURN     all  --  0.0.0.0/0  0.0.0.0/0
2    DNAT       tcp  --  0.0.0.0/0  0.0.0.0/0    tcp dpt:9090 to:172.17.0.2:80
```

That last line is the critical one:

```
DNAT  tcp  --  0.0.0.0/0  0.0.0.0/0  tcp dpt:9090 to:172.17.0.2:80
```

Translation:
- **DNAT** — Destination NAT (rewrite the destination)
- **tcp dpt:9090** — Match TCP packets with destination port 9090
- **to:172.17.0.2:80** — Rewrite the destination to the container's IP (172.17.0.2) port 80

When a packet arrives at host:9090, iptables rewrites its destination to 172.17.0.2:80 before it enters the bridge. The container receives a packet addressed to port 80 — it has no idea the host was involved.

---

## The Full Packet Path for Port Mapping

```
Client → host:9090

    1. PREROUTING chain (nat table)
       ↓ jumps to DOCKER chain
    2. DOCKER chain: DNAT tcp dpt:9090 → 172.17.0.2:80
       ↓ destination rewritten
    3. Routing decision: destination is 172.17.0.0/16 → forward to docker0
       ↓
    4. FORWARD chain (filter table): ACCEPT if on docker0
       ↓
    5. docker0 bridge → veth pair → container eth0
       ↓
    6. Container receives packet addressed to :80
       ↓
    7. Response: container → veth → docker0 → POSTROUTING (MASQUERADE) → client
```

---

## Outbound Traffic: SNAT / Masquerade

When a container sends traffic to the internet, iptables masquerades it:

```bash
# Look at the POSTROUTING chain:
sudo iptables -t nat -L POSTROUTING -n
```

```
Chain POSTROUTING (policy ACCEPT)
target     prot opt source           destination
MASQUERADE  all  --  172.17.0.0/16    0.0.0.0/0
```

This means: any packet from the docker subnet (`172.17.0.0/16`) going to the outside gets its source IP rewritten to the host's IP. Without this, the response packets would try to route back to `172.17.0.2` and never arrive — the internet doesn't know how to reach a private docker IP.

---

## Docker's FORWARD Chain Rules

Docker also controls inter-container communication through the filter table:

```bash
sudo iptables -L FORWARD -n
```

```
Chain FORWARD (policy DROP)
target          prot opt source        destination
DOCKER-USER     all  --  0.0.0.0/0     0.0.0.0/0
DOCKER-ISOLATION-STAGE-1  all  --  0.0.0.0/0  0.0.0.0/0
ACCEPT          all  --  0.0.0.0/0     0.0.0.0/0  ctstate RELATED,ESTABLISHED
DOCKER          all  --  0.0.0.0/0     0.0.0.0/0
ACCEPT          all  --  0.0.0.0/0     0.0.0.0/0
```

Key chains:
- **DOCKER-ISOLATION-STAGE-1/2** — Prevents cross-bridge traffic (containers on different user-defined networks can't reach each other)
- **DOCKER-USER** — Custom rules you can add that survive Docker restarts
- Default policy is **DROP** — everything not explicitly allowed is blocked

---

## kube-proxy and Kubernetes Service Routing

In Kubernetes, **kube-proxy** creates iptables rules (or IPVS rules) to implement Services. When you create a Service with a ClusterIP, kube-proxy programs rules that intercept traffic to that ClusterIP and rewrite the destination to one of the Service's backend pods.

### How it works

```
Pod A → ClusterIP:80

    1. OUTPUT chain (nat table): match dst = ClusterIP
       ↓ jumps to KUBE-SERVICES chain
    2. KUBE-SERVICES: match ClusterIP → jump to KUBE-SVC-XXXXX
       ↓
    3. KUBE-SVC-XXXXX: probabilistic routing to endpoints
       ↓ statistic mode random probability 0.5
    4. KUBE-SEP-AAAAA: DNAT to 10.244.1.5:80 (pod 1)
       or
    4. KUBE-SEP-BBBBB: DNAT to 10.244.2.3:80 (pod 2)
       ↓
    5. Packet arrives at the selected pod
```

### Examining kube-proxy rules (in a kind cluster)

```bash
# Enter a kind node:
docker exec -it <kind-node-name> bash

# List all KUBE-SERVICES rules:
iptables -t nat -L KUBE-SERVICES -n

# Find rules for a specific service:
iptables-save -t nat | grep <service-cluster-ip>
```

You'll see chains like:
- `KUBE-SERVICES` — Entry point, matches ClusterIP addresses
- `KUBE-SVC-XXXXX` — Per-service chain with load balancing
- `KUBE-SEP-XXXXX` — Per-endpoint (pod) chain with DNAT

The load balancing uses iptables' `statistic` module with random probability. For 3 pods: first rule matches with probability 1/3, second with 1/2 (of remaining), third always matches.

---

## NodePort Rules

For NodePort Services, kube-proxy adds additional rules:

```bash
iptables-save -t nat | grep KUBE-NODEPORTS
```

```
-A KUBE-NODEPORTS -p tcp --dport 30080 -j KUBE-SVC-XXXXX
```

Any traffic to port 30080 on any node jumps to the same service chain — same DNAT to pods.

---

## Debugging Tips

### "Port mapping doesn't work"

```bash
# 1. Check if the iptables rule exists:
iptables -t nat -L DOCKER -n | grep <port>

# 2. Check if the container is actually listening:
docker exec <container> ss -tlnp

# 3. Check if the bridge is up:
ip link show docker0

# 4. Check FORWARD chain allows traffic:
iptables -L FORWARD -n -v
```

### "Service can't reach pods"

```bash
# 1. Check if kube-proxy is running:
kubectl get pods -n kube-system | grep kube-proxy

# 2. Check if iptables rules exist for the Service:
iptables-save -t nat | grep <cluster-ip>

# 3. Check if endpoints exist:
kubectl get endpoints <service-name>

# 4. Check if the pod is actually listening:
kubectl exec <pod> -- ss -tlnp
```

---

## iptables vs nftables vs IPVS

| Technology | Used by | Notes |
|-----------|---------|-------|
| **iptables** | Docker, kube-proxy (default mode) | Widely supported, can be slow with thousands of rules |
| **nftables** | Newer Linux distros (iptables compatibility layer) | Modern replacement for iptables, Docker supports it |
| **IPVS** | kube-proxy (ipvs mode) | Better performance for large clusters (thousands of Services) |
| **eBPF** | Cilium CNI | Bypasses iptables entirely, best performance |

---

## Cleanup

```bash
docker rm -f learn-dd-net-iptables 2>/dev/null
```

---

## Summary

- Docker uses iptables DNAT rules to implement port mapping — rewriting destination IP:port to the container
- SNAT/MASQUERADE rewrites the source IP for outbound container traffic
- kube-proxy creates chains of iptables rules for each Kubernetes Service
- Service load balancing uses probabilistic matching across endpoint chains
- `iptables -t nat -L -n` and `iptables-save` are your primary debugging tools
- IPVS and eBPF (Cilium) are higher-performance alternatives to iptables for large clusters

---

**Next:** [CNI and Service Mesh](03-cni-and-service-mesh.md) — How Kubernetes delegates networking and what service meshes add
