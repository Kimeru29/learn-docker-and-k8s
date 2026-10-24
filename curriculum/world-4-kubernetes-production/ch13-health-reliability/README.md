```
  ___ _   _ _____   _____ _           ___          _ _ _         _     ___
 / __| |_/ |__ / | |_   _| |_  ___   | _ \___ ___ (_) (_)___ _ _| |_  | _ )_ _ _____ __ __
| (__| ' \| |_ \ |   | | | ' \/ -_)  |   / -_|_-< | | | / -_) ' \  _| | _ \ '_/ -_) V  V /
 \___|_||_|_|___/_|   |_| |_||_\___|  |_|_\___/__/ |_|_|_\___|_||_\__| |___/_| \___|\_/\_/

    "Pods say Running. The app says otherwise."

    .----------------------------------------------.
    |  Deployment: api          Replicas: 3/3       |
    |  Status: Running  Running  Running            |
    |                                               |
    |  HTTP responses:  500  500  503  500  200  500|
    |                                               |
    |  Sarah: "Running is not the same as ready."   |
    '----------------------------------------------'
```

# Chapter 13: The Resilient Brew

## The Story

The NoCappuccino API deployment shows `Running` for all three replicas. The dashboard is green. Marcus just said "everything looks great" in the morning standup.

Except the customers disagree. Orders are failing. The app inside two of those "Running" pods crashed ten minutes ago — it's stuck in an infinite loop, returning 500 errors on every request. But Kubernetes has no idea, because there are no health probes. As far as the scheduler is concerned, those pods are perfectly healthy.

And last week, a rolling update caused a 30-second outage. The new pods replaced the old ones before they were ready. There was no readiness probe, no deployment strategy, and no graceful shutdown. Customers saw errors mid-checkout.

Sarah pulls up the monitoring dashboard. "See these three green dots? Two of them are lying. Let's teach Kubernetes how to tell the difference."

---

## What You'll Learn

By the end of this chapter, you will be able to:

- Configure startup, readiness, and liveness probes — and understand which to use when
- Design rolling update strategies with zero downtime
- Roll back a bad deployment safely using revision history
- Set up PodDisruptionBudgets for voluntary disruptions
- Configure graceful termination with `terminationGracePeriodSeconds` and preStop hooks
- Use init containers, sidecars, and lifecycle hooks for reliability patterns

---

## Prerequisites

- World 3: Kubernetes Core (ch09–ch12 completed)
- `learn-k8s` kind cluster running
- Comfort with Deployments, Services, and `kubectl`

---

## Estimated Time

- Lessons: ~90 minutes
- Challenges: ~120 minutes
- Total: ~4 hours

---

## Lessons

| # | Lesson | What you'll learn |
|---|--------|-------------------|
| 01 | [Health Probes](lessons/01-health-probes.md) | The three probe types, when each fires, common mistakes |
| 02 | [Deployment Strategies](lessons/02-deployment-strategies.md) | Rolling updates, rollback, blue-green, canary concepts |
| 03 | [Pod Disruption](lessons/03-pod-disruption.md) | PDB, voluntary vs involuntary disruptions, graceful termination |
| 04 | [Reliability Patterns](lessons/04-reliability-patterns.md) | Init containers, sidecars, lifecycle hooks, multi-container pods |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Probe Diagnosis](challenges/01-probe-diagnosis.md) | Add probes to stop traffic to broken pods |
| 02 | [Zero-Downtime Update](challenges/02-zero-downtime-update.md) | Roll out a new version with zero failed requests |
| 03 | [Graceful Shutdown](challenges/03-graceful-shutdown.md) | Configure termination so pods drain connections properly |

To verify your work: `bash curriculum/world-4-kubernetes-production/ch13-health-reliability/challenges/verify.sh`

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Startup probe** | Delays liveness/readiness checks until the app has started. Protects slow starters. |
| **Readiness probe** | Removes the pod from Service endpoints when it fails. Traffic stops flowing. |
| **Liveness probe** | Restarts the pod when it fails. For stuck or deadlocked processes. |
| **Rolling update** | Gradual pod replacement. Controlled by maxSurge and maxUnavailable. |
| **maxSurge** | Extra pods allowed above replica count during update |
| **maxUnavailable** | Pods allowed to be unavailable during update |
| **PodDisruptionBudget** | Minimum pods that must stay available during voluntary disruptions |
| **terminationGracePeriodSeconds** | Time K8s waits for a pod to shut down before sending SIGKILL |
| **preStop hook** | Command that runs before SIGTERM is sent to the container |
| **Init container** | Runs to completion before main containers start |
| **Sidecar** | Container that runs alongside the main container in the same pod |

---

> **Sarah:** "The most dangerous state in Kubernetes is a pod that shows 'Running' while the application inside is dead. Probes are how you close that gap. Everything else in this chapter builds on that foundation."

**Start with:** [Lesson 01 — Health Probes](lessons/01-health-probes.md)
