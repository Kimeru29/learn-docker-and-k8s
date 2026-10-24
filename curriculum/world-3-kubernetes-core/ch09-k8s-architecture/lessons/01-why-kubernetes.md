# Lesson 1: Why Kubernetes

## The 3 AM Problem

You just saw what happens when a single Docker host tries to serve 50,000 concurrent users. It doesn't. It melts.

But the failure wasn't just about CPU. Even if we had a bigger machine, we still had:

- **A single point of failure.** One host dies, the entire app goes down.
- **No self-healing.** A crashed container stays down until someone notices and manually restarts it.
- **No scaling.** Traffic doubles? The only option is "buy a bigger box" (vertical scaling), and there's a ceiling on that.
- **No zero-downtime deployments.** Deploying a new version means stopping the old container and starting a new one — there's a gap.

Docker Compose is great for managing a multi-container app on *one machine*. But one machine is not a production-grade infrastructure. We need something that can manage containers across *many machines* simultaneously.

That something is Kubernetes.

---

## Cattle vs. Pets

Before we talk about K8s architecture, there's an analogy worth having in your toolkit — you'll hear it constantly in DevOps conversations.

### Pets
You give them names. You care about them individually. When a pet gets sick, you nurse it back to health. You know which server is "web-01" and you SSH into it directly when something goes wrong.

This is how most teams run servers before containers. Each machine is special. Losing one is a crisis.

### Cattle
You don't name individual cattle. You manage the herd. If one gets sick, you replace it. What matters is that the herd as a whole stays at the right size and health.

This is how Kubernetes thinks about containers. A Pod is not precious. If it crashes, Kubernetes doesn't try to fix it — it discards it and schedules a fresh one. What matters is that the *desired count* of healthy Pods stays satisfied.

The shift from pets to cattle is the mental model shift required to work with Kubernetes effectively. Your app needs to be stateless (or handle state externally) and accept that any individual instance can be killed at any time.

---

## What Kubernetes Actually Does

Kubernetes is a **container orchestrator**. It manages the full lifecycle of containerized workloads across a cluster of machines:

- **Scheduling:** Deciding which node runs which container, based on available resources
- **Self-healing:** Restarting failed containers, replacing unhealthy Pods, rescheduling when a node goes down
- **Scaling:** Adding or removing replicas based on demand (manually or automatically)
- **Rolling updates:** Deploying new versions without downtime by replacing Pods gradually
- **Service discovery:** Giving stable network names to ephemeral Pods
- **Configuration and secrets management:** Injecting config and credentials into containers without baking them into images

All of this is driven by a single principle: **declarative desired state**.

---

## The K8s Philosophy: Declarative, Not Imperative

This is the single most important concept in Kubernetes. It changes how you think about infrastructure.

### Imperative: telling the system *what to do*

```bash
# "Run 3 copies of nginx"
docker run -d nginx
docker run -d nginx
docker run -d nginx
# One crashes? Manually restart it.
docker run -d nginx
```

You're giving step-by-step instructions. If something breaks, you fix it manually. The system has no memory of what "should" be running.

### Declarative: telling the system *what you want*

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3
  template:
    spec:
      containers:
        - image: nginx:1.25
```

You're describing the desired end state. Kubernetes figures out how to make it true — and keeps making it true, forever. If a Pod crashes, the system notices the gap between desired (3) and actual (2) and creates a new one.

This is the fundamental shift. You stop managing processes. You start managing *desired state*.

---

## The Reconciliation Loop

The reconciliation loop is the engine that powers everything in Kubernetes. Every controller follows the same pattern:

```
     ┌──────────────────────────────┐
     │                              │
     │   1. Observe actual state    │
     │      (What's really running) │
     │              │               │
     │              ▼               │
     │   2. Compare to desired      │
     │      state (What YAML says)  │
     │              │               │
     │              ▼               │
     │   3. Take action to close    │
     │      the gap                 │
     │              │               │
     └──────────────┘               │
              │                     │
              └─────────────────────┘
                   (repeat forever)
```

This loop runs continuously — not just at startup, not on a schedule, but as a constant background process. When something changes (a Pod dies, a node goes offline, you update a YAML file), the relevant controller detects the drift and acts.

**Real examples:**

| Desired State | Actual State | Controller Action |
|--------------|-------------|-------------------|
| 3 replicas running | 2 replicas running (one crashed) | Create 1 new Pod |
| Image `nginx:1.26` | Pods running `nginx:1.25` | Rolling update: new ReplicaSet with 1.26, scale down old |
| Node "worker-2" healthy | Node "worker-2" not responding | Reschedule its Pods to other nodes |
| Service points to app=nginx Pods | New Pod with app=nginx label appears | Add Pod to Service endpoints |

You don't tell Kubernetes "restart that Pod." You tell it "I want 3 replicas." It figures out the rest. This is what makes K8s resilient — the system constantly self-corrects.

---

## Desired State vs. Actual State

Everything in Kubernetes is a comparison between two things:

**Desired state** — what you declared in your YAML manifests and applied to the cluster. This is stored in etcd (the cluster database). It's the "truth" you defined.

**Actual state** — what's actually running on the nodes right now. Pods, containers, processes. This is reported by kubelet on each node.

The control plane's entire job is to make actual state converge on desired state. When they match, the system is healthy. When they don't, controllers take action.

This is why `kubectl apply` is idempotent. You can run it 100 times — if desired state already matches actual state, nothing happens. If there's drift, only the differences are applied.

---

## What We Didn't Cover (And Why)

A few things you might wonder about:

**Managed Kubernetes (EKS, GKE, AKS):** Cloud providers run the Control Plane for you. You only manage the worker nodes. The concepts are identical — only the setup differs.

**Container Runtime:** Kubernetes no longer directly uses Docker as its container runtime (as of K8s 1.24, dockershim was removed). kind uses `containerd` under the hood. When you specify a Docker image in a K8s manifest, containerd pulls and runs it. You don't need to know this yet, but it explains why you might see `containerd` mentioned in logs.

**Helm, Kustomize, GitOps:** These are deployment tools that sit on top of kubectl. They're important in production but not needed to learn K8s fundamentals. We'll encounter them in World 5.

---

## Summary

| Concept | What it is |
|---------|-----------|
| Orchestrator | Software that manages containers across multiple machines |
| Declarative state | Describing *what you want*, not *how to get there* |
| Reconciliation loop | Constant cycle: observe actual → compare to desired → close the gap |
| Desired state | What you declared in YAML, stored in etcd |
| Actual state | What's actually running, reported by kubelets |
| Cattle vs. Pets | Treat instances as disposable, manage the herd |
| Self-healing | Automatic replacement of failed Pods to match desired state |

---

Up next: [Lesson 2 — K8s Architecture Deep Dive](02-k8s-architecture.md)

You know *why* we need Kubernetes. Now let's look inside the machine — what components make up a cluster and how they work together.
