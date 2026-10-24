# Lesson 1: Beyond Deployments

## The Deployment Hierarchy, Revisited

In Chapter 9, you learned that Deployments create ReplicaSets, which create Pods. Now let's look deeper at this hierarchy — understanding it precisely will help you debug problems and choose the right workload type.

```
Deployment
  │
  │  "I want nginx:1.25 with 3 replicas"
  │
  ├── ReplicaSet (v1: nginx:1.25)
  │     ├── Pod-abc   ← Running
  │     ├── Pod-def   ← Running
  │     └── Pod-ghi   ← Running
  │
  └── ReplicaSet (v2: nginx:1.26)   ← created during rolling update
        ├── Pod-xyz   ← scaling up
        └── ...
```

### ReplicaSets: The Mechanism

A **ReplicaSet** has one job: ensure that a specific number of Pods with matching labels are running at all times. It's the reconciliation engine.

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: learn-nginx-7d5f4c9b6b
  namespace: learn-ch10
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
      pod-template-hash: 7d5f4c9b6b   # auto-generated
  template:
    metadata:
      labels:
        app: nginx
        pod-template-hash: 7d5f4c9b6b
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
```

**You rarely create ReplicaSets directly.** The Deployment controller creates them for you. But understanding them is crucial because:

1. When you debug a stuck Deployment, the issue is often at the ReplicaSet level
2. During rolling updates, you'll see *two* ReplicaSets — old and new
3. `kubectl get replicasets` shows you the update history

```bash
# See ReplicaSets managed by a Deployment
kubectl get replicasets -n learn-ch10 -l app=nginx

# See the relationship
kubectl describe deployment learn-nginx -n learn-ch10
# Look for "NewReplicaSet" and "OldReplicaSets" in the output
```

### Why Deployments Exist on Top

If ReplicaSets handle Pod count, why do we need Deployments? Because ReplicaSets don't handle **updates**.

A ReplicaSet is tied to a specific Pod template. If you change the image from `nginx:1.25` to `nginx:1.26`, a ReplicaSet can't update its running Pods — it would need to be replaced entirely.

The Deployment controller handles this:

1. Create a new ReplicaSet with the new template
2. Scale the new one up, one Pod at a time
3. Scale the old one down, one Pod at a time
4. Keep both around for rollback history

This is the **rolling update** strategy. The Deployment ensures zero downtime by never having all Pods unavailable at once.

```bash
# Watch a rolling update
kubectl rollout status deployment/learn-nginx -n learn-ch10

# Rollback if the new version has issues
kubectl rollout undo deployment/learn-nginx -n learn-ch10

# See history
kubectl rollout history deployment/learn-nginx -n learn-ch10
```

---

## Labels and Selectors: The Glue That Holds Everything Together

Labels are **the** mechanism that connects Kubernetes resources. Without them, nothing works. Services don't find Pods. Deployments don't manage ReplicaSets. ReplicaSets don't know which Pods they own.

### How Labels Flow

```
Deployment
  metadata.labels:          ← labels on the Deployment itself
    app: learn-docker-k8s
    world: w03
  spec.selector.matchLabels: ← which Pods belong to this Deployment
    app: nginx
  spec.template.metadata.labels: ← labels stamped onto every Pod
    app: nginx
    world: w03
    chapter: ch10

Service
  spec.selector:             ← which Pods this Service routes to
    app: nginx
```

**Critical rule:** The Deployment's `spec.selector.matchLabels` MUST be a subset of `spec.template.metadata.labels`. If they don't match, the Deployment can't find its own Pods.

### Label Best Practices

```yaml
labels:
  app: nocappuccino-backend     # Application name
  component: api                 # Role within the app
  version: "2.1.0"              # Version (useful for canary deploys)
  environment: staging           # Environment
  team: backend                  # Owning team
```

Use labels for:
- **Selection:** Services, Deployments, and other controllers finding their targets
- **Organization:** Filtering with `kubectl get pods -l team=backend`
- **Monitoring:** Prometheus scraping metrics from Pods with specific labels

### Selector Operators

Simple selectors use equality:

```bash
kubectl get pods -l app=nginx              # app equals nginx
kubectl get pods -l app=nginx,version=1.25 # AND (both must match)
```

Set-based selectors use operators:

```yaml
selector:
  matchExpressions:
    - key: environment
      operator: In
      values: ["staging", "production"]
    - key: team
      operator: NotIn
      values: ["deprecated"]
```

```bash
kubectl get pods -l 'environment in (staging,production)'
kubectl get pods -l 'team notin (deprecated)'
kubectl get pods -l 'app'      # has the label, any value
kubectl get pods -l '!canary'  # does NOT have the label
```

---

## The Workload Landscape

Now that you understand how Deployments work internally, let's zoom out. Not every workload is a long-running web server. Kubernetes provides specialized workload types:

| Workload Type | Use Case | Lifecycle | Identity |
|--------------|----------|-----------|----------|
| **Deployment** | Stateless services (web, API) | Runs forever, Pods are interchangeable | Random names, no order |
| **Job** | One-shot tasks (migrations, exports) | Runs to completion, then stops | Random names |
| **CronJob** | Scheduled tasks (cleanup, reports) | Creates Jobs on a schedule | Random names |
| **StatefulSet** | Stateful services (databases, caches) | Runs forever, ordered lifecycle | Stable names (pod-0, pod-1, pod-2) |
| **DaemonSet** | Per-node agents (log collectors, monitors) | One Pod per node, always | One per node |

Each type has a controller that runs its own reconciliation loop:
- Deployment controller → manages ReplicaSets
- Job controller → creates Pods and tracks completion
- CronJob controller → creates Jobs on schedule
- StatefulSet controller → manages Pods with ordering guarantees
- DaemonSet controller → ensures one Pod per matching node

---

## Why This Matters

Choosing the wrong workload type creates real problems:

- **Database in a Deployment:** Pods get random names. Scaling up creates a new independent database instead of a replica. No stable storage binding. Data loss risk.
- **Migration script in a Deployment:** It runs forever (restartPolicy: Always). The migration runs, completes, container exits, Kubernetes restarts it. Infinite migration loop.
- **Log collector in a Deployment:** You'd need to set replicas equal to node count manually. If nodes scale, you'd have to update the count. If a node has no collector, you miss logs.

The right workload type:
- **Database:** StatefulSet (stable names, ordered creation, stable storage)
- **Migration script:** Job (run once, track completion, stop)
- **Log collector:** DaemonSet (automatically one per node, no manual counting)

---

## Summary

| Concept | What it is |
|---------|-----------|
| ReplicaSet | The mechanism behind Deployments; ensures Pod count matches desired state |
| Rolling update | Deployment strategy: new ReplicaSet scales up while old scales down |
| Labels | Key-value pairs on resources; the primary selection mechanism in K8s |
| Selectors | Filter expressions that match resources by labels |
| `pod-template-hash` | Auto-generated label linking ReplicaSets to their specific Pod template |
| Workload types | Deployment, Job, CronJob, StatefulSet, DaemonSet — each for a different lifecycle |

---

Up next: [Lesson 2 — Jobs and CronJobs](02-jobs-and-cronjobs.md)

You know why Deployments aren't enough. Let's start with the simplest non-Deployment workload: running something once and stopping.
