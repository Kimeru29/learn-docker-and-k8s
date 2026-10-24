# Lesson 1: Requests and Limits

> **Sarah:** "The worker pod got OOMKilled again this morning. Exit Code 137. No memory limit, no request, no QoS class. It was running as BestEffort — which means Kubernetes treated it as the first thing to sacrifice when the node ran low on memory. Let me walk you through the system."

---

## Why Resource Management Matters

A Kubernetes node has a fixed amount of CPU and memory. Pods share that node. Without resource constraints:

- One misbehaving pod can consume all available memory and starve every other pod
- A pod with a memory leak grows until the node's OOM killer fires
- The scheduler can't make good placement decisions — it doesn't know how much each pod needs
- You can't guarantee performance for any service

Resource requests and limits are how you tell Kubernetes what each pod needs and what it's allowed to use.

---

## Requests

**The guaranteed minimum.** The scheduler reserves this amount on the node.

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "250m"
```

- A pod is only scheduled on a node that has enough **unreserved** capacity to satisfy the request
- The pod might use less — that's fine
- The pod might use more (up to the limit) if the node has spare capacity
- Requests affect **scheduling**, not runtime behavior

### What the scheduler sees

When placing a pod with `requests.memory: 128Mi`:

```
Node capacity:  4Gi
Already reserved: 3Gi (by other pods' requests)
Available:      1Gi
Pod needs:      128Mi
→ Fits. Schedule here.
```

The scheduler doesn't look at actual usage — it looks at **requested** amounts. A node can be 10% utilized but "full" if all its capacity is reserved by requests.

---

## Limits

**The hard ceiling.** If a pod tries to exceed its limit:

```yaml
resources:
  limits:
    memory: "256Mi"
    cpu: "500m"
```

### CPU: Throttled, not killed

When a container hits its CPU limit, the Linux kernel's CFS (Completely Fair Scheduler) throttles it. The container gets fewer CPU cycles. It slows down. It is **never killed** for exceeding a CPU limit.

```
CPU usage at 500m limit:
├── Normal: using 300m of 500m    → runs at full speed
├── Busy:   wants 800m, capped    → throttled to 500m, runs slower
└── Spike:  wants 2000m, capped   → heavily throttled, noticeable latency
```

**CPU throttling is invisible to Kubernetes.** No event is emitted, no status changes. Your pod just gets slower. You'll only notice it through response latency or `kubectl top`.

### Memory: OOMKilled

When a container exceeds its memory limit, the Linux kernel's OOM killer terminates it immediately.

```
Memory usage at 256Mi limit:
├── Normal: using 180Mi of 256Mi  → fine
├── Growing: using 250Mi          → fine, but close
├── Over:    tries to allocate     → OOMKilled (Exit Code 137)
└── After:   Kubernetes restarts   → if it keeps leaking, CrashLoopBackOff
```

**Exit Code 137** = 128 + 9 (SIGKILL). The process is not given a chance to clean up. It's just dead.

---

## Reading OOMKilled

```bash
kubectl get pods -n learn-ch14
# NAME                      READY   STATUS      RESTARTS   AGE
# worker-7d9b6f4d8-x4r2p    0/1     OOMKilled   4          12m

kubectl describe pod worker-7d9b6f4d8-x4r2p -n learn-ch14
# Last State:     Terminated
#   Reason:       OOMKilled
#   Exit Code:    137
#   Started:      Thu, 26 Mar 2026 06:33:12 +0000
#   Finished:     Thu, 26 Mar 2026 06:34:47 +0000
```

The diagnostic picture:
- `Reason: OOMKilled` → memory limit exceeded
- `Exit Code: 137` → SIGKILL (128 + 9)
- Check `limits.memory` in the pod spec → is it too low, or is the app leaking?

### Two root causes, two fixes

**The limit is too low for the workload:**
Increase `limits.memory`. Check actual usage with `kubectl top pod` or metrics. Set the limit to at least 1.5–2x the normal working set with headroom for spikes.

**The app has a memory leak:**
The limit is correct, but the app is broken. Increasing the limit delays the problem. You need to fix the code. As a temporary measure, the restarts from OOMKill act as an imperfect safety valve.

---

## Resource Units

### CPU

- `1` = 1 vCPU core
- `500m` = 500 millicores = 0.5 vCPU
- `100m` = 100 millicores = 0.1 vCPU
- Fractional cores are normal and expected

### Memory

- `256Mi` = 256 mebibytes (2^28 bytes) — use this notation
- `256M` = 256 megabytes (10^8 bytes) — similar but not identical
- `1Gi` = 1 gibibyte
- Always use `Mi` and `Gi` to avoid confusion

---

## Quality of Service Classes

When a node runs out of memory and the OOM killer must choose what to terminate, Kubernetes uses **QoS classes** to determine eviction priority.

### Guaranteed

**Condition:** Every container has `requests == limits` for both CPU and memory.

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

Last to be evicted. Use for your most critical services (databases, payment processors).

### Burstable

**Condition:** At least one container has requests or limits set, but not all have `requests == limits`.

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

The pod can burst above its requests up to its limits. Evicted after BestEffort pods. Most production workloads should be here.

### BestEffort

**Condition:** No resources set at all.

```yaml
# No resources section
```

Gets whatever is free. **First to be evicted** under memory pressure. Never use for anything you care about.

### Eviction order

```
Node memory pressure detected:
1. Evict BestEffort pods first
2. Evict Burstable pods (highest usage relative to request first)
3. Evict Guaranteed pods last (only in extreme cases)
```

### Practical guidance

```
Critical service (database, payment):    Guaranteed  (requests == limits)
Standard application pod:                Burstable   (requests < limits)
Batch job that can tolerate eviction:    Burstable   (low requests)
Test/dev pods:                           BestEffort  (but understand the risk)
```

Setting `requests == limits` (Guaranteed) is safe but wastes capacity — the scheduler reserves the full amount even if the pod uses less. Setting `requests < limits` (Burstable) is more efficient: you reserve only what you typically need, and the pod can burst when spare capacity is available.

---

## LimitRange and ResourceQuota

Two namespace-level objects enforce resource policies:

**LimitRange:** Sets defaults for pods that don't specify resources. Prevents accidental BestEffort.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: learn-ch14
spec:
  limits:
    - type: Container
      default:          # Default limits
        memory: "128Mi"
        cpu: "250m"
      defaultRequest:   # Default requests
        memory: "64Mi"
        cpu: "100m"
      max:              # Maximum allowed
        memory: "1Gi"
        cpu: "2"
      min:              # Minimum allowed
        memory: "16Mi"
        cpu: "10m"
```

**ResourceQuota:** Caps total resources for the namespace.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: learn-ch14
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
```

---

## Practical Sizing Guidelines

Start with these, then measure actual usage and adjust:

| Service type | Suggested requests | Suggested limits |
|---|---|---|
| Node.js web API | 100m CPU, 128Mi | 500m CPU, 256Mi |
| Python worker | 200m CPU, 256Mi | 1000m CPU, 512Mi |
| Go microservice | 50m CPU, 64Mi | 200m CPU, 128Mi |
| Java API (Spring Boot) | 500m CPU, 512Mi | 1000m CPU, 1Gi |
| PostgreSQL (small) | 250m CPU, 256Mi | 1000m CPU, 1Gi |
| nginx (reverse proxy) | 50m CPU, 32Mi | 200m CPU, 64Mi |

**When in doubt:** Start with requests lower than you think and limits higher. Watch actual usage with `kubectl top pod`. Tighten over time.

---

## Quick Reference

```bash
# Check pod resource usage
kubectl top pod -n <namespace>
kubectl top node

# Check pod QoS class
kubectl get pod <name> -n <namespace> -o jsonpath='{.status.qosClass}'

# Check why a pod was killed
kubectl describe pod <name> -n <namespace>
# Look for: Last State, Reason (OOMKilled), Exit Code (137)

# See resource requests/limits on a deployment
kubectl get deployment <name> -n <namespace> -o yaml | grep -A 8 resources

# Check namespace resource usage vs quota
kubectl describe resourcequota -n <namespace>
```

---

> **Sarah:** "Exit Code 137 used to terrify me. Now it's just a signal: either the limit is wrong, or the app is leaking. The fix is always to measure, understand, and then set the right numbers."

**Next:** [Scheduler Decisions](02-scheduler-decisions.md)
