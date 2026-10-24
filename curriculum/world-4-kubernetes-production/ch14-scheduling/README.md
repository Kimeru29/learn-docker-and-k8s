```
  ___ _   _ _ _     _____ _            ___                                  ___           _          _
 / __| |_/ | | |   |_   _| |_  ___    | _ \___ ___ ___ _  _ _ _ __ ___    | _ )_  _ __| |__ _ ___| |_
| (__| ' \_  _|     | | | ' \/ -_)   |   / -_|_-< _ \ || | '_/ _/ -_)   | _ \ || / _` / _` / -_)  _|
 \___|_||_| |_|      |_| |_||_\___|   |_|_\___/__/\___/\_,_|_| \__\___|   |___/\_,_\__,_\__, \___|\___|
                                                                                         |___/

    "The scheduler puts everything on one node. The OOM killer takes out the rest."

    .----------------------------------------------.
    |  Node 1:  CPU 95%  MEM 87%                    |
    |    - api (3 replicas)                         |
    |    - worker (2 replicas)                      |
    |    - database (1 replica)                     |
    |                                               |
    |  Node 2:  CPU 3%   MEM 12%                    |
    |    - (empty)                                  |
    |                                               |
    |  Node 3:  CPU 2%   MEM 8%                     |
    |    - (empty)                                  |
    |                                               |
    |  Sarah: "Nobody told the scheduler to spread." |
    '----------------------------------------------'
```

# Chapter 14: The Resource Budget

## The Story

Marcus is looking at the cloud bill. It went up 40% last month even though traffic is flat. Dave provisioned three nodes but all the pods ended up on the same one. The other two nodes sit idle, burning money.

Meanwhile, the worker pod keeps getting OOMKilled — Exit Code 137, every few hours. It has no memory limits, and a slow leak grows until the kernel intervenes. The HPA is configured but it scales up pods that immediately get OOMKilled too, because the underlying resource problem was never addressed.

And yesterday, a burst of traffic hit the API. The HPA tried to scale up, but the scheduler couldn't place new pods because the only node with any pods was already full. The other nodes were empty but the scheduler hadn't been told to spread the load.

Sarah looks at the cluster dashboard. "Resources are the most misunderstood part of Kubernetes. People either set nothing and get OOMKilled, or set everything too high and waste money. Let's find the middle."

---

## What You'll Learn

By the end of this chapter, you will be able to:

- Configure resource requests and limits correctly
- Diagnose and fix OOMKilled pods (Exit Code 137)
- Understand QoS classes and eviction priority
- Control pod placement with node selectors, affinity, and topology spread
- Set up the Horizontal Pod Autoscaler and watch it respond to load
- Know when HPA helps and when it doesn't

---

## Prerequisites

- World 3: Kubernetes Core (ch09–ch12 completed)
- `learn-k8s` kind cluster running
- Basic comfort with `kubectl get`, `kubectl describe`, `kubectl top`

---

## Estimated Time

- Lessons: ~75 minutes
- Challenges: ~120 minutes
- Total: ~4 hours

---

## Lessons

| # | Lesson | What you'll learn |
|---|--------|-------------------|
| 01 | [Requests and Limits](lessons/01-requests-and-limits.md) | Resource guarantees, hard caps, CPU throttling, OOMKill, QoS classes |
| 02 | [Scheduler Decisions](lessons/02-scheduler-decisions.md) | How the scheduler picks a node, affinity, anti-affinity, topology spread |
| 03 | [Autoscaling](lessons/03-autoscaling.md) | HPA, scaling metrics, cooldown, VPA concepts |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Fix OOMKilled](challenges/01-fix-oomkilled.md) | Diagnose and fix a pod getting OOMKilled repeatedly |
| 02 | [Spread Pods](challenges/02-spread-pods.md) | Distribute replicas across nodes instead of stacking on one |
| 03 | [Autoscaling](challenges/03-autoscaling.md) | Set up HPA and watch it scale under load |

To verify your work: `bash curriculum/world-4-kubernetes-production/ch14-scheduling/challenges/verify.sh`

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Requests** | Minimum resources guaranteed to a pod. Used by the scheduler for placement. |
| **Limits** | Maximum resources a pod can use. CPU is throttled; memory triggers OOMKill. |
| **OOMKilled** | Pod exceeded its memory limit. Exit Code 137. |
| **QoS class** | Eviction priority: Guaranteed > Burstable > BestEffort |
| **Node selector** | Simple label match for pod placement |
| **Node affinity** | Flexible rules for attracting pods to specific nodes |
| **Pod anti-affinity** | Rules that spread pods away from each other |
| **Topology spread** | Distribute pods evenly across failure domains (nodes, zones) |
| **HPA** | Scales replica count based on metrics (CPU, memory, custom) |
| **VPA** | Adjusts resource requests automatically based on usage |

---

> **Sarah:** "Resource management is where you stop treating Kubernetes like magic and start treating it like engineering. Every pod needs a budget — what it's guaranteed, what it's allowed, and where it lives."

**Start with:** [Lesson 01 — Requests and Limits](lessons/01-requests-and-limits.md)
