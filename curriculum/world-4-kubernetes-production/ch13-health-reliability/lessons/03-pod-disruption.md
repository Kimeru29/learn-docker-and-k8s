# Lesson 3: Pod Disruption and Graceful Termination

> **Sarah:** "Last Friday, IT drained a node for a kernel upgrade. No warning. Six pods evicted at once. Two of them were in the middle of processing payment webhooks. Those webhooks were lost. The customer never got their order confirmation. That's what happens when you don't plan for disruption."

---

## Two Kinds of Disruption

Pods can be evicted for two categories of reasons:

### Involuntary Disruptions

Things that happen without anyone choosing them:
- Node hardware failure
- Kernel panic
- Node runs out of memory (OOM)
- Network partition isolates the node

You cannot prevent these. You can only survive them through replicas and proper scheduling (covered in ch14).

### Voluntary Disruptions

Things that someone or something deliberately triggers:
- `kubectl drain` (node maintenance)
- Cluster autoscaler removing an underutilized node
- A Deployment rolling update replacing pods
- `kubectl delete pod`
- Node OS upgrades

You **can** control how these happen. That's where PodDisruptionBudgets come in.

---

## PodDisruptionBudget (PDB)

A PDB tells Kubernetes: "During voluntary disruptions, you must keep at least this many pods available."

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
  namespace: learn-ch13
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: learn-api
```

With this PDB and 3 replicas:
- `kubectl drain` will evict pods **one at a time**, waiting for replacements to be Ready before evicting the next
- At no point will fewer than 2 pods be available
- If only 2 pods are running and both are healthy, the drain will **block** until a third pod is scheduled elsewhere

### minAvailable vs maxUnavailable

You can specify either:

```yaml
# Option A: At least 2 must always be available
spec:
  minAvailable: 2

# Option B: At most 1 can be unavailable at a time
spec:
  maxUnavailable: 1
```

With 3 replicas, these are equivalent. But they behave differently when replica count changes:
- `minAvailable: 2` with 2 replicas → the PDB blocks all evictions (can't go below 2)
- `maxUnavailable: 1` with 2 replicas → allows 1 eviction (1 pod can be down)

**Percentage values work too:**

```yaml
spec:
  minAvailable: "50%"   # At least half the pods must stay up
```

### When PDBs block

If a PDB cannot be satisfied, the drain operation blocks. The node stays in `SchedulingDisabled` state but pods are not evicted. This is by design — it's better to block a maintenance operation than to take down a service.

```bash
# This might block if PDB prevents eviction
kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data

# To check why a drain is stuck
kubectl get pdb -n learn-ch13
kubectl describe pdb api-pdb -n learn-ch13
```

### PDB only applies to voluntary disruptions

A PDB does not help when:
- The node crashes (involuntary)
- A pod is OOMKilled (involuntary)
- You `kubectl delete pod --force` (force bypasses PDB)

---

## Graceful Termination

When Kubernetes decides to terminate a pod (rolling update, drain, scale-down), it follows a specific sequence:

```
1. Pod is marked for termination
2. Pod is removed from Service endpoints (no new traffic)
3. preStop hook runs (if configured)
4. SIGTERM is sent to PID 1 in the container
5. Grace period countdown begins (default: 30 seconds)
6. If the process hasn't exited by the deadline: SIGKILL
```

### terminationGracePeriodSeconds

```yaml
spec:
  terminationGracePeriodSeconds: 60  # default is 30
```

This is the **total** time Kubernetes waits from step 3 to step 6. If your preStop hook takes 10 seconds and your app needs 40 seconds to drain connections, you need at least 50 seconds.

**If the process exits before the deadline,** Kubernetes proceeds immediately. The grace period is a maximum, not a fixed wait.

### The Race Condition Problem

There's a subtle timing issue between steps 2 and 4. The endpoint removal (step 2) and the SIGTERM (step 4) happen **asynchronously**. The kube-proxy and Ingress controllers need time to propagate the endpoint change. During that propagation window, new requests may still arrive at a pod that's already shutting down.

**The fix:** Add a preStop hook that sleeps briefly, giving the network time to catch up:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 5"]
```

This 5-second sleep happens before SIGTERM is sent. By the time SIGTERM arrives, kube-proxy and Ingress controllers have already removed the pod from their routing tables.

---

## preStop Hooks

A preStop hook runs a command inside the container before SIGTERM is sent.

### Common uses

**Connection draining:**
```yaml
lifecycle:
  preStop:
    exec:
      command:
        - /bin/sh
        - -c
        - |
          # Tell the app to stop accepting new connections
          curl -s -X POST http://localhost:8080/admin/drain
          # Wait for in-flight requests to complete
          sleep 15
```

**Deregistering from a service registry:**
```yaml
lifecycle:
  preStop:
    exec:
      command:
        - /bin/sh
        - -c
        - |
          curl -s -X DELETE http://consul:8500/v1/agent/service/deregister/myapp
          sleep 5
```

**Graceful nginx shutdown:**
```yaml
lifecycle:
  preStop:
    exec:
      command: ["/usr/sbin/nginx", "-s", "quit"]
```

`nginx -s quit` waits for in-flight requests to complete before exiting, unlike the default SIGTERM behavior which may not drain connections depending on the nginx version.

### preStop counts against the grace period

If `terminationGracePeriodSeconds: 30` and your preStop hook sleeps for 25 seconds, your app only has 5 seconds to handle SIGTERM and exit. Plan accordingly.

---

## What Happens During Node Drain

```bash
kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data
```

Step by step:

1. The node is **cordoned** (`kubectl cordon`): no new pods will be scheduled on it
2. Kubernetes checks PDBs for all pods on the node
3. For each pod (respecting PDBs), Kubernetes evicts it:
   - The pod is removed from endpoints
   - preStop hook runs
   - SIGTERM is sent
   - Grace period countdown
4. If a PDB blocks eviction, the drain pauses and retries
5. Once all pods are evicted (or force timeout is reached), the node is empty

**Common flags:**
```bash
--ignore-daemonsets     # Skip DaemonSet pods (they're supposed to be on every node)
--delete-emptydir-data  # Allow evicting pods with emptyDir volumes (data will be lost)
--force                 # Evict pods not managed by a controller (standalone pods)
--timeout=300s          # How long to wait before giving up
```

---

## Putting It All Together

For a production API service with 3 replicas:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-ch13
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      terminationGracePeriodSeconds: 60
      containers:
        - name: api
          image: learn-api:v1.0
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            periodSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /livez
              port: 8080
            periodSeconds: 10
            failureThreshold: 5
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
  namespace: learn-ch13
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: learn-api
```

This gives you:
- Readiness probe: traffic only goes to healthy pods
- Liveness probe: stuck pods get restarted
- Rolling update with zero downtime
- 5-second preStop sleep for endpoint propagation
- 60-second termination window for connection draining
- PDB ensuring at least 2 pods survive any voluntary disruption

---

## Quick Reference

```bash
# Create a PDB
kubectl apply -f pdb.yaml

# Check PDB status
kubectl get pdb -n <namespace>
kubectl describe pdb <name> -n <namespace>

# Drain a node (with safety)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# Cordon a node (prevent scheduling, don't evict)
kubectl cordon <node>

# Uncordon (allow scheduling again)
kubectl uncordon <node>
```

---

> **Sarah:** "The PDB is your safety net during maintenance. The preStop hook is your safety net during shutdown. Together they mean: nobody gets evicted until a replacement is ready, and nobody gets killed mid-request. That's what production-grade looks like."

**Next:** [Reliability Patterns](04-reliability-patterns.md)
