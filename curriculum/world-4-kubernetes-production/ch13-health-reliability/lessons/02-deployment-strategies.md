# Lesson 2: Deployment Strategies

> **Sarah:** "Last week's deploy caused a 30-second outage because we replaced all three pods at once. Nobody configured a strategy. Nobody added a readiness probe. Thirty seconds doesn't sound like much — but it was thirty seconds during the morning rush, and Marcus noticed. Let's make sure that never happens again."

---

## Why Strategy Matters

A Deployment update changes something about your pods — usually the container image. How those pods get replaced determines whether your users notice.

Without a strategy, Kubernetes defaults to `RollingUpdate` with `maxSurge: 25%` and `maxUnavailable: 25%`. That's reasonable for many workloads, but it is not zero-downtime unless you also have readiness probes configured. And for critical services, you want explicit control.

---

## Rolling Update Strategy

A rolling update replaces pods gradually: start new ones, wait for them to be ready, terminate old ones, repeat. At every point during the update, some version of your application is serving traffic.

### The two levers

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**maxSurge:** How many extra pods can exist above the desired replica count during the update.

- `maxSurge: 1` with `replicas: 3` → up to 4 pods running during the update
- `maxSurge: "25%"` with `replicas: 4` → up to 5 pods (25% of 4 = 1, rounded up)

**maxUnavailable:** How many pods can be below Ready state during the update.

- `maxUnavailable: 0` → zero pods can go down. New pods must be Ready before old ones are removed. This is the zero-downtime configuration, but it requires `maxSurge > 0`
- `maxUnavailable: 1` → one pod can be unavailable at a time. Faster but briefly reduces capacity

### Common configurations

**Zero downtime (recommended for production):**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

With `replicas: 3`: start 1 new pod (total 4) → wait for Ready → remove 1 old pod (total 3) → repeat. At least 3 ready pods always.

**Fast update (accept brief capacity reduction):**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1
```

Removes one old pod and adds one new pod simultaneously. Finishes in half the time but you briefly have fewer pods.

**Full replacement (avoid unless necessary):**
```yaml
strategy:
  type: Recreate
```

Terminates all old pods first, then starts all new pods. Causes downtime. Only use this for workloads that cannot tolerate two versions running simultaneously (e.g., a database with migration constraints).

---

## Triggering a Rolling Update

Any change to the pod template triggers a rollout:

```bash
# Change the image tag
kubectl set image deployment/learn-api api=learn-api:v2.0 -n learn-ch13

# Or edit the YAML and apply
kubectl apply -f deployment.yaml

# Force re-pull of the same image (for mutable tags — avoid in production)
kubectl rollout restart deployment/learn-api -n learn-ch13
```

---

## Monitoring a Rollout

```bash
# Watch the rollout in real time (blocks until complete)
kubectl rollout status deployment/learn-api -n learn-ch13

# See the rollout history
kubectl rollout history deployment/learn-api -n learn-ch13

# See details about a specific revision
kubectl rollout history deployment/learn-api --revision=2 -n learn-ch13

# Watch pods transition in real time
kubectl get pods -n learn-ch13 -w
```

During a rollout, `kubectl get pods` shows both old and new pods. New pods appear with new names, reach `Running`, pass their readiness probe, and only then do old pods terminate.

---

## Rolling Back

Kubernetes keeps a history of Deployments as ReplicaSets. Rollback scales the previous ReplicaSet back up.

```bash
# Undo the last rollout
kubectl rollout undo deployment/learn-api -n learn-ch13

# Undo to a specific revision
kubectl rollout history deployment/learn-api -n learn-ch13
kubectl rollout undo deployment/learn-api --to-revision=2 -n learn-ch13

# Watch the rollback
kubectl rollout status deployment/learn-api -n learn-ch13
```

A rollback is itself a rolling update — the same `maxSurge` and `maxUnavailable` rules apply.

### Revision history limit

```yaml
spec:
  revisionHistoryLimit: 10  # default
```

Kubernetes keeps this many old ReplicaSets (with 0 replicas) so you can roll back to them. Set this to a reasonable number. Too high wastes API server resources. Too low and you lose rollback targets.

### When rollback does NOT help

Rollback swaps the image tag. It does not:
- Restore data deleted by the buggy version
- Reverse a database migration
- Undo changes to external systems (message queues, third-party APIs)

This is why database migrations should be backward-compatible: old code should work with the new schema, so you can roll back the application without rolling back the database.

---

## Blue-Green Deployments

Blue-green maintains two complete environments. Only one is live at a time.

```
   ┌─────────────┐
   │   Service    │
   │ selector:    │
   │  slot: blue ─┼──→  Blue Deployment (v1, 3 replicas) ← LIVE
   └─────────────┘
                         Green Deployment (v2, 3 replicas) ← STANDBY
```

**How it works in Kubernetes:**

1. Deploy the new version as a separate Deployment with a different label (e.g., `slot: green`)
2. Run smoke tests against the green Deployment directly (via a test Service or port-forward)
3. Update the production Service selector from `slot: blue` to `slot: green`
4. Traffic immediately shifts to the green pods
5. Keep blue around for instant rollback — just flip the selector back

```yaml
# Service — change selector to switch traffic
apiVersion: v1
kind: Service
metadata:
  name: learn-api
spec:
  selector:
    app: learn-api
    slot: blue   # Change to "green" to cut over
```

**Trade-offs:**
- Instant cutover, instant rollback
- Zero downtime (both versions are running simultaneously during switch)
- Requires 2x compute during the transition
- Not built into Kubernetes — you manage two Deployments manually

---

## Canary Deployments

A canary sends a small percentage of traffic to the new version while the majority still goes to the old version.

**Simple canary with replica counts:**

```
   ┌─────────────┐
   │   Service    │
   │ selector:    │
   │  app: api   ─┼──→  v1 Deployment (9 replicas)  ~90% traffic
   └─────────────┘──→  v2 Deployment (1 replica)   ~10% traffic
```

Both Deployments have `app: api`. The Service selects all of them. Traffic distributes roughly by replica count.

**Percentage-based canary** requires an Ingress controller with weighted routing (NGINX Ingress, Istio, Argo Rollouts). This lets you set exact traffic percentages independent of replica counts.

**When to use canary vs. rolling update:**
- **Rolling update:** Standard releases, well-tested code, stateless services
- **Canary:** High-risk changes, new features to validate with real traffic, services where a bad release has significant user impact

---

## The Relationship Between Probes and Strategies

Rolling updates only work safely when readiness probes are configured:

1. K8s creates a new pod
2. The new pod starts the container
3. Without a readiness probe: K8s immediately marks it Ready and removes an old pod
4. With a readiness probe: K8s waits until the probe passes before marking it Ready

**Without readiness probes, `maxUnavailable: 0` is a lie.** K8s thinks zero pods are unavailable because it thinks the new pod is ready — but the app inside hasn't finished loading yet. Traffic hits the new pod and fails.

```yaml
# These two MUST go together for zero-downtime updates
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
  failureThreshold: 3

strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

---

## Quick Reference

```bash
# Trigger update
kubectl set image deployment/<name> <container>=<image>:<tag> -n <namespace>

# Monitor
kubectl rollout status deployment/<name> -n <namespace>
kubectl rollout history deployment/<name> -n <namespace>

# Rollback
kubectl rollout undo deployment/<name> -n <namespace>
kubectl rollout undo deployment/<name> --to-revision=<n> -n <namespace>

# Pause/resume a rollout
kubectl rollout pause deployment/<name> -n <namespace>
kubectl rollout resume deployment/<name> -n <namespace>

# Force restart (same image)
kubectl rollout restart deployment/<name> -n <namespace>
```

---

> **Sarah:** "The difference between 'we deployed' and 'we deployed safely' is two things: a readiness probe and `maxUnavailable: 0`. Everything else is optimization."

**Next:** [Pod Disruption](03-pod-disruption.md)
