```
  ____                  _____ _       _     _
 | __ )  ___  ___ ___  |  ___(_) __ _| |__ | |_
 |  _ \ / _ \/ __/ __| | |_  | |/ _` | '_ \| __|
 | |_) | (_) \__ \__ \ |  _| | | (_| | | | | |_
 |____/ \___/|___/___/ |_|   |_|\__, |_| |_|\__|
                                 |___/

 ⎈ "The Cluster Crisis"

    .─────────────────────────────────────────────.
    │ ALERT  ALERT  ALERT  ALERT  ALERT  ALERT    │
    │                                             │
    │  🔴 CrashLoopBackOff — order-service        │
    │  🔴 0 Endpoints    — payment-svc            │
    │  🔴 PVC Pending    — analytics-data         │
    │  🔴 Wrong config   — db-connection          │
    │  🔴 DNS failure    — recommendation-svc     │
    │                                             │
    │  Saturday 7:12 AM                           │
    │  Dave: unreachable (camping trip)            │
    │  Marcus: "FIX IT NOW"                       │
    '─────────────────────────────────────────────'

    (◎_◎;) This is not a drill.
    (•‿•)  Sarah: "You've trained for this. Triage first."
```

# Boss Fight: The Cluster Crisis

## Story

Saturday morning. 7:12 AM. Your phone explodes with notifications.

Five alerts. Simultaneously.

Dave is on a camping trip. No cell service. Marcus is on a flight to a coffee conference. His last message before boarding: "FIX IT NOW."

You open your laptop and stare at the cluster dashboard. Everything that could break, did.

This is the moment. Everything you learned in World 3 — architecture, workloads, networking, storage — comes together. Five independent problems. Five different root causes. No one to help.

Sarah's voice echoes in your head: *"Triage first. Not everything is equally urgent. Fix what matters most, then work down the list."*

---

## The Five Failures

You don't know which is which. The alerts are:

1. **A Deployment stuck in CrashLoopBackOff** — Pods keep restarting and crashing. The service is completely down.

2. **A Service that routes to zero endpoints** — Traffic hits the Service but goes nowhere. Customers see "connection refused."

3. **A PVC stuck in Pending** — A new analytics service can't start because its storage isn't binding. The Pod is Pending.

4. **A ConfigMap with wrong data** — A database connection string is incorrect. The app starts but immediately fails to connect.

5. **DNS resolution failing for one service** — One specific Service can't be reached by name from other Pods, though the Service exists.

Each failure is independent — fixing one won't fix the others. But the impact varies. Part of the challenge is deciding what to fix first.

---

## Rules of Engagement

- **Namespace:** All resources are in `learn-boss`
- **You must deploy the broken state first** — apply the challenge manifest
- **Diagnose before fixing** — use `kubectl get`, `describe`, `logs`, `exec`
- **Fix all five issues** — partial credit is given
- **No order is prescribed** — you choose the triage priority
- **The verify script checks each fix independently**

---

## Prerequisites

- Chapters 9-12 completed
- kind cluster `learn-k8s` running

```bash
kubectl cluster-info --context kind-learn-k8s
kubectl create namespace learn-boss
```

---

## Challenge

| # | Challenge | What's broken |
|---|-----------|--------------|
| 01 | [The Cluster Crisis](challenges/01-cluster-crisis.md) | Five simultaneous K8s failures |

---

## Verification

```bash
bash curriculum/world-3-kubernetes-core/boss-k8s-incident/challenges/verify.sh
```

---

## Estimated Time

**60-90 minutes** for all five fixes.

---

## After You Win

When the verify script goes all green, World 3 is complete.

You just handled a multi-issue production incident solo. Five problems. Five root causes. Five fixes.

Dave will surface on Monday morning, check the cluster, see everything green, and say: "See? I told you Kubernetes would be reliable."

Typical Dave.

You earned this:
- **World 4: Kubernetes Production** is unlocked
- **Architecture Interview Mode** is unlocked
- **Deep Dive: Advanced Networking** is available

Welcome to the next level.
