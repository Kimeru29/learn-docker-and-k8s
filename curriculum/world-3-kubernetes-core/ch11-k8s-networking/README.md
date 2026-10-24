```
  ___ _     _ _    _  __    _                _                    _    _
 / __| |_  / / |  | |/ /  _| |__  ___  _ __ | |___ __ _____ _ __| | _(_)_ __   __ _
| (__| ' \ | | |  | ' < | | '_ \/ -_)| '  \| / -_)\ V  V / '_| |/ / | '  \ / _` |
 \___|_||_||_|_|  |_|\_\_,_|_.__/\___||_|_|_|_\___| \_/\_/|_| |_|\_\_|_|_|_|\__, |
                                                                              |___/
 ⎈ "The Service Mesh"

    Pod A (10.244.1.5)         Pod B (10.244.2.8)
         │                          │
         │  "http://backend-svc"    │
         │  ───────────────────►    │
         │                          │
    ┌────┴────────────────────────┴─────┐
    │        ClusterIP Service          │
    │   Stable DNS + Virtual IP         │
    │   kube-proxy iptables rules       │
    │   CoreDNS name resolution         │
    └───────────────────────────────────┘

    Pod IPs are ephemeral.
    Services are forever.

    (•_•) Sarah: "Never hardcode a Pod IP.
                  That's the first rule."
```

# Chapter 11: The Service Mesh

## Story

The workloads are deployed. Deployments, Jobs, StatefulSets — the full fleet is running.

Then Marcus sends a screenshot of an error page: "Connection refused."

> **Marcus 2:30 PM:** The frontend can't reach the backend. It was working yesterday.
>
> **Dave 2:31 PM:** I restarted the backend pods. Maybe the IP changed?
>
> **Sarah (you):** That's exactly the problem. Pod IPs change on every restart. You can't hardcode them. That's what Services are for.

You open your laptop and find three networking problems stacked on top of each other:

1. The backend Service selector doesn't match the backend Pod labels
2. The recommendation service DNS name isn't resolving from the frontend
3. Security wants to know why every Pod can talk to every other Pod — there's no segmentation

Time to fix NoCappuccino's cluster networking.

---

## What You'll Learn

By the end of this chapter, you'll be able to:

- Explain Pod networking: every Pod gets an IP, flat network model, CNI
- Create ClusterIP, NodePort, and headless Services
- Understand how kube-proxy routes traffic using iptables rules
- Use CoreDNS for Service name resolution
- Debug DNS issues from inside the cluster using debug Pods
- Understand Ingress controllers and Ingress resources
- Create NetworkPolicies for traffic segmentation
- Diagnose Service endpoint mismatches and DNS failures

---

## Prerequisites

- Chapter 9 completed (kubectl, cluster fundamentals)
- kind cluster `learn-k8s` running

```bash
kubectl cluster-info --context kind-learn-k8s
kubectl create namespace learn-ch11
```

---

## Lessons

| # | Lesson | What You'll Learn |
|---|--------|-------------------|
| 01 | [Pod Networking](lessons/01-pod-networking.md) | Pod IPs, CNI, the flat network model |
| 02 | [Services](lessons/02-services.md) | ClusterIP, NodePort, LoadBalancer, EndpointSlices, kube-proxy |
| 03 | [DNS and Discovery](lessons/03-dns-and-discovery.md) | CoreDNS, service DNS names, headless Services, debugging DNS |
| 04 | [Ingress and Network Policies](lessons/04-ingress-and-network-policies.md) | Ingress controllers, routing rules, NetworkPolicies |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Service Discovery](challenges/01-service-discovery.md) | Connect frontend to backend via ClusterIP Service |
| 02 | [Expose Externally](challenges/02-expose-externally.md) | Expose a Service via NodePort |
| 03 | [Network Segmentation](challenges/03-network-segmentation.md) | Create NetworkPolicies to restrict traffic |
| 04 | [Debug DNS](challenges/04-debug-dns.md) | Diagnose and fix broken DNS resolution |

---

## Verification

```bash
bash curriculum/world-3-kubernetes-core/ch11-k8s-networking/challenges/verify.sh
```

---

## Post-Chapter Cliffhanger

Once all four challenges pass, come back here.

The networking is solid. Services route correctly. DNS resolves. NetworkPolicies enforce segmentation. Dave can no longer accidentally expose the database to the frontend.

Marcus is impressed for the first time in weeks. "So the networking just... works now?"

"As long as nobody deletes the Services," you say, staring pointedly at Dave.

Then a support ticket comes in. A customer's order history is gone. The database Pod restarted during a deployment and the data wasn't persisted.

"Wait," Dave says. "I thought Kubernetes handled storage automatically?"

"It does," you reply. "But you have to tell it to."

See you in Chapter 12: **The Persistent Roast**.
