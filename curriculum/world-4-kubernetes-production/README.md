```
 __      __        _    _   _  _     _  __     ___               _         _   _
 \ \    / /__ _ _ | |__| | | || |   | |/ /    | _ \_ _ ___  __| |_  _ __| |_(_)___ _ _
  \ \/\/ / _ \ '_|| / _` | |_  _|   | ' <     |  _/ '_/ _ \/ _` | || / _|  _| / _ \ ' \
   \_/\_/\___/_|  |_\__,_|   |_|    |_|\_\    |_| |_| \___/\__,_|\_,_\__|\__|_\___/_||_|

    KUBERNETES PRODUCTION — "Running K8s Like You Mean It"

    .------------------------------------------------------.
    |  STATUS REPORT                                        |
    |                                                       |
    |  Cluster:    Running                                  |
    |  Pods:       "Running" (but are they really?)         |
    |  Resources:  Unmanaged                                |
    |  Security:   Nonexistent                              |
    |  Probes:     Missing                                  |
    |  RBAC:       default ServiceAccount everywhere        |
    |                                                       |
    |  Sarah: "It runs. That's not the same as ready."      |
    '------------------------------------------------------'
```

# World 4: Kubernetes Production

## The Story So Far

You survived World 3. You built a Kubernetes cluster, deployed workloads with Deployments and Services, configured networking with Ingress and NetworkPolicies, and set up persistent storage. The NoCappuccino app is running on Kubernetes.

That was the easy part.

---

## The Problem

The cluster runs. Pods show `Running`. Services route traffic. But underneath the green status lights, the system is held together with duct tape:

- **Pods say "Running" but the app inside is returning 500 errors.** There are no health probes, so Kubernetes doesn't know anything is wrong. Traffic keeps flowing to broken pods.
- **Rolling updates cause brief outages.** No one configured readiness probes or deployment strategies. Updates kill old pods before new ones are ready.
- **The worker pod gets OOMKilled every few hours.** No memory limits. A slow leak grows until the kernel intervenes. Exit Code 137, every time.
- **The scheduler puts all replicas on the same node.** No affinity rules, no topology spread. One node failure takes out the entire service.
- **Anyone can `kubectl exec` into any pod.** The default ServiceAccount has no restrictions. Database credentials sit in plain YAML. NetworkPolicies are wide open.

Sarah looks at the cluster dashboard. Everything is green. She sighs.

"Green doesn't mean healthy. It means nobody's checked."

---

## What You'll Learn

This world transforms a fragile Kubernetes deployment into a production-ready platform. Three chapters, each targeting a critical gap:

| Chapter | Title | Focus |
|---------|-------|-------|
| [ch13](ch13-health-reliability/README.md) | **The Resilient Brew** | Health probes, deployment strategies, graceful shutdown, reliability patterns |
| [ch14](ch14-scheduling/README.md) | **The Resource Budget** | Requests, limits, scheduling, autoscaling, QoS classes |
| [ch15](ch15-k8s-security/README.md) | **The Lockdown** | RBAC, security contexts, Secrets management, NetworkPolicies |

After all three, you face the boss fight:

| Boss | Title | What Breaks |
|------|-------|-------------|
| [Boss](boss-great-latte-leak/README.md) | **The Great Latte Leak** | Five simultaneous production failures across health, resources, security, and configuration |

---

## Competencies

This world develops three core competency areas:

- **k8s-health** — Probes, PodDisruptionBudgets, rolling updates, rollback, deployment strategies, graceful termination
- **k8s-scheduling** — Resource requests and limits, QoS classes, node affinity, topology spread, HPA
- **k8s-security** — RBAC, ServiceAccounts, security contexts, Pod Security Standards, Secrets, NetworkPolicies

---

## Prerequisites

- **World 3: Kubernetes Core** completed
- `learn-k8s` kind cluster running with `kubectl` configured
- Comfort with `kubectl get`, `kubectl describe`, `kubectl logs`, and `kubectl apply`
- Understanding of Deployments, Services, ConfigMaps, and Namespaces

---

## Progression: Semi-Parallel

Chapters 13, 14, and 15 can be completed in **any order**. Each is independent — they share the K8s cluster but not concepts that depend on each other. Choose the chapter that matches your interest or your weakest area:

```
  ch13 (Health & Reliability) ──┐
                                ├──> Boss: The Great Latte Leak
  ch14 (Scheduling & Resources) ┤
                                │
  ch15 (Kubernetes Security) ───┘
```

The boss fight requires all three chapters to be complete. It combines concepts from all of them.

---

## Estimated Time

- **Per chapter:** 4–5 hours (lessons + challenges + quiz)
- **Boss fight:** 2–3 hours
- **Total:** 12–16 hours

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Liveness probe** | Is this pod alive? If it fails, the pod is restarted |
| **Readiness probe** | Is this pod ready for traffic? If it fails, it's removed from Service endpoints |
| **Startup probe** | Has this pod finished starting? Protects slow-starting apps from liveness kills |
| **PodDisruptionBudget** | Guarantees a minimum number of pods stay available during voluntary disruptions |
| **Rolling update** | Replace old pods with new ones gradually, keeping the app available |
| **Requests** | Minimum resources the scheduler guarantees to a pod |
| **Limits** | Maximum resources a pod is allowed to use |
| **QoS class** | Priority tier (Guaranteed, Burstable, BestEffort) that determines eviction order |
| **HPA** | Horizontal Pod Autoscaler — scales replica count based on metrics |
| **Node affinity** | Rules that attract pods to specific nodes |
| **Pod anti-affinity** | Rules that spread pods across nodes |
| **RBAC** | Role-Based Access Control — who can do what on which resources |
| **ServiceAccount** | Identity assigned to pods for API access |
| **Security context** | Pod-level security settings: user, capabilities, filesystem access |
| **Pod Security Standards** | Cluster-wide policies: Privileged, Baseline, Restricted |
| **NetworkPolicy** | Firewall rules for pod-to-pod traffic |

---

## Resource Conventions

All K8s resources in this world use:

- **Namespaces:** `learn-ch13`, `learn-ch14`, `learn-ch15`, `learn-boss-w4`
- **Labels:** `app=learn-docker-k8s`, `world=w04`, `chapter=chXX`
- **kind cluster:** `learn-k8s`

---

> **Sarah:** "World 3 taught you how to run Kubernetes. World 4 teaches you how to keep it running. There's a difference — and you'll feel it the first time a pod says 'Running' while the app inside is on fire."
