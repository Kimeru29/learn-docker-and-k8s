```
  ___ _     _  ___    __        __         _    _                 _
 / __| |_  / |/ _ \   \ \      / /__  _ __| | _| | ___   __ _  __| |___
| (__| ' \ | | | | |   \ \ /\ / / _ \| '__| |/ / |/ _ \ / _` |/ _` / __|
 \___|_||_||_|_| |_|    \ V  V / (_) | |  |   <| | (_) | (_| | (_| \__ \
                         \_/\_/ \___/|_|  |_|\_\_|\___/ \__,_|\__,_|___/

 ⎈ "The Fleet"

    Deployment  ── long-running services    (web, API, worker)
    Job         ── run once, then done      (migrations, exports)
    CronJob     ── run on a schedule        (cleanup, reports)
    StatefulSet ── ordered, stable identity (databases, caches)
    DaemonSet   ── one per node             (log agents, monitors)

    Not everything is a web server.
    The fleet needs different ship types.

    (•_•) Sarah: "A Deployment is a cargo ship.
                  But you also need tugboats,
                  patrol boats, and tankers."
```

# Chapter 10: The Fleet

## Story

The traffic spike is behind you. NoCappuccino is running on Kubernetes with Deployments and self-healing. Dave is impressed. Marcus is cautiously optimistic.

Then the morning Slack channel lights up:

> **Marcus 9:15 AM:** We need to run the database migration before the next release. Can we just... run it in a Deployment?
>
> **Dave 9:16 AM:** And the log collector should run on every node. That's a Deployment too, right?
>
> **Marcus 9:17 AM:** Also, the recommendation engine needs stable database connections. If pods restart and get new names, it breaks.

You take a long sip of coffee.

*"Not everything is a Deployment,"* you type. *"Kubernetes has different workload types for different patterns. Let me show you."*

---

## What You'll Learn

By the end of this chapter, you'll be able to:

- Explain the relationship between Deployments, ReplicaSets, and Pods
- Use labels and selectors as the primary mechanism for resource relationships
- Create Jobs for one-shot tasks like database migrations
- Create CronJobs for scheduled tasks like cleanup and reporting
- Deploy StatefulSets for workloads that need stable identity and ordered creation
- Deploy DaemonSets for per-node workloads like log collectors
- Choose the right workload type for a given scenario

---

## Prerequisites

- Chapter 9 completed (kind cluster running, kubectl basics, Deployment fundamentals)
- kind cluster `learn-k8s` running

```bash
kubectl cluster-info --context kind-learn-k8s
kubectl create namespace learn-ch10
```

---

## Lessons

| # | Lesson | What You'll Learn |
|---|--------|-------------------|
| 01 | [Beyond Deployments](lessons/01-beyond-deployments.md) | ReplicaSets, labels, selectors — how Deployments really work |
| 02 | [Jobs and CronJobs](lessons/02-jobs-and-cronjobs.md) | One-shot tasks, scheduled tasks, completions, backoff |
| 03 | [StatefulSets and DaemonSets](lessons/03-statefulsets-and-daemonsets.md) | Stable identity, ordered creation, per-node workloads |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Batch Migration](challenges/01-batch-migration.md) | Create a Job that runs a database migration script |
| 02 | [Scheduled Cleanup](challenges/02-scheduled-cleanup.md) | Create a CronJob that runs on a schedule |
| 03 | [Stateful Service](challenges/03-stateful-service.md) | Deploy a StatefulSet with stable identity |

---

## Verification

```bash
bash curriculum/world-3-kubernetes-core/ch10-workloads/challenges/verify.sh
```

---

## Post-Chapter Cliffhanger

Once all three challenges pass, come back here.

The fleet is assembled. NoCappuccino has Deployments for the web tier, a Job for migrations, a CronJob for cleanup, and a StatefulSet for the recommendation engine.

Dave is scrolling through `kubectl get pods -A` like he's reading the Matrix. "I can see everything now," he mutters.

Then the monitoring dashboard goes red. Not the apps — the networking.

> **Marcus 2:30 PM:** The frontend can't reach the backend. Something about "no endpoints."
> **Dave 2:31 PM:** Also, the recommendation service DNS isn't resolving.
> **Marcus 2:32 PM:** AND someone from security wants to know why every pod can talk to every other pod.

You open your laptop. Pod IPs change. Services route to nowhere. DNS breaks. Network policies don't exist.

Time to fix cluster networking.

See you in Chapter 11: **The Service Mesh**.
