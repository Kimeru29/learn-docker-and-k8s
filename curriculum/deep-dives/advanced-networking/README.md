  _____ _          __      ___
 |_   _| |_  ___  \ \    / (_)_ _ ___
   | | | ' \/ -_)  \ \/\/ /| | '_/ -_)
   |_| |_||_\___|   \_/\_/ |_|_| \___|

 🔌 Deep Dive: "The Wire"

    Browser
      │
      ▼
    ┌─────────┐   iptables    ┌──────────┐
    │  Host   │──── DNAT ────▶│  docker0 │
    │  :8080  │               │  bridge  │
    └─────────┘               └────┬─────┘
                                   │ veth pair
                              ┌────▼─────┐
                              │Container │
                              │  :80     │
                              └──────────┘

    (•‿•) Sarah: "Let me show you what happens
           between the browser and the pod."

# Deep Dive: The Wire — Advanced Container Networking

## Why This Deep Dive Exists

You've set up Docker networks and Kubernetes Services. You know that port mapping works and DNS resolves container names. But *how*? What actually happens when a packet hits port 8080 on your host and ends up inside a container? What iptables rules did Docker create? What's a veth pair, really?

This deep dive traces the full network path — from your browser through iptables NAT rules, across virtual bridges, through veth pairs, and into the container's network namespace. Then we do it again at the Kubernetes level: kube-proxy, CNI plugins, and service mesh concepts.

> *Sarah speaking:* "Networking is the topic that separates 'I can use Docker' from 'I can debug Docker.' When someone says 'the container can't reach the internet' and you can trace the packet hop by hop, you become the person everyone calls."

---

## Prerequisites

- **Required:** Chapter 04 — Networking (completed)
- **Required:** Chapter 11 — Kubernetes Networking (completed)
- You should be comfortable with Docker networks and Kubernetes Services

---

## What You'll Learn

- How Docker creates veth pairs and connects them to bridges
- How iptables DNAT rules implement port mapping
- How kube-proxy creates iptables rules for Kubernetes Services
- What CNI plugins do and how they differ
- What problem service meshes solve and how they work at a high level

---

## Topics

| Topic | Description |
|-------|-------------|
| veth pairs | Virtual ethernet cables — one end in the container, one on the host |
| Linux bridges | Virtual switches that connect containers |
| iptables / NAT | How Docker and kube-proxy rewrite packet destinations |
| CNI | Container Network Interface — Kubernetes' pluggable networking model |
| kube-proxy | How Kubernetes routes Service traffic to pods |
| Service mesh | Sidecar proxies for observability, security, and traffic control |

---

## Lessons

| # | Lesson | Topics |
|---|--------|--------|
| 01 | [veth Pairs and Bridges](lessons/01-veth-pairs-and-bridges.md) | Virtual cables, docker0 bridge, container-to-host traffic flow |
| 02 | [iptables and NAT](lessons/02-iptables-and-nat.md) | DNAT for port mapping, SNAT for outbound, kube-proxy rules |
| 03 | [CNI and Service Mesh](lessons/03-cni-and-service-mesh.md) | CNI plugin model, flannel/calico/cilium, service mesh concepts |

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Trace the Packet](challenges/01-trace-the-packet.md) | Trace the full network path from host to container |
| 02 | [K8s Service Routing](challenges/02-k8s-service-routing.md) | Find and explain iptables rules for a Kubernetes Service |

To verify your work: `bash curriculum/deep-dives/advanced-networking/challenges/verify.sh`

---

## Estimated Time

- Lessons: ~45 minutes
- Challenges: ~30–45 minutes
- Total: ~1.5 hours

---

## Platform Notes

⚠️ **macOS / Docker Desktop users:** Docker Desktop runs a Linux VM, so host-level network inspection (iptables, ip link, bridges) operates inside that VM. The lessons provide workarounds using `nsenter` or privileged containers to access the VM's network stack.

⚠️ **Kind cluster:** The K8s challenge uses a kind cluster. Kind nodes are Docker containers, so you can `docker exec` into them to inspect iptables rules.

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **veth pair** | Virtual ethernet cable with two ends — one in a namespace, one on a bridge |
| **Linux bridge** | Virtual network switch that connects interfaces at Layer 2 |
| **docker0** | Docker's default bridge interface on the host |
| **iptables** | Linux kernel packet filtering and NAT framework |
| **DNAT** | Destination NAT — rewrite the destination IP/port of incoming packets |
| **SNAT** | Source NAT — rewrite the source IP of outgoing packets (masquerading) |
| **CNI** | Container Network Interface — standardized plugin API for K8s networking |
| **kube-proxy** | K8s component that programs iptables rules for Service routing |
| **Service mesh** | Infrastructure layer for service-to-service communication (observability, mTLS, traffic control) |
