# Lesson 3: StatefulSets and DaemonSets

## StatefulSets: When Identity Matters

A **Deployment** treats all Pods as identical and interchangeable. They get random names, start in any order, and can be replaced by any other Pod. This works perfectly for stateless web servers.

But some workloads need more:
- **Databases** need stable storage that follows a specific Pod
- **Distributed systems** (Kafka, Elasticsearch, etcd) need stable network identity for cluster membership
- **Primary/replica patterns** need ordered startup (primary first, then replicas)

A **StatefulSet** provides three guarantees that Deployments don't:

### 1. Stable, Predictable Pod Names

```
Deployment Pods:    learn-nginx-7d5f4c9b6b-abc12    (random)
                    learn-nginx-7d5f4c9b6b-def34    (random)
                    learn-nginx-7d5f4c9b6b-ghi56    (random)

StatefulSet Pods:   learn-db-0                       (ordinal 0)
                    learn-db-1                       (ordinal 1)
                    learn-db-2                       (ordinal 2)
```

Each Pod gets a stable name: `<statefulset-name>-<ordinal>`. If `learn-db-1` dies, the replacement is also named `learn-db-1`. This matters because other systems can rely on this name for discovery.

### 2. Ordered Creation and Deletion

Pods are created sequentially: `pod-0` must be Running and Ready before `pod-1` starts. `pod-1` before `pod-2`. This ensures the primary database is up before replicas try to connect to it.

Deletion is reversed: `pod-2` is terminated first, then `pod-1`, then `pod-0`.

```
Startup:   pod-0 → Running ✓ → pod-1 → Running ✓ → pod-2 → Running ✓
Shutdown:  pod-2 → Terminated ✓ → pod-1 → Terminated ✓ → pod-0 → Terminated ✓
```

### 3. Stable Storage

Each Pod in a StatefulSet can have its own PersistentVolumeClaim (PVC). The PVC stays bound to the same Pod identity even after restarts. If `learn-db-1` is deleted and recreated, it gets the **same** PVC — and therefore the same data.

(We'll cover PVCs in detail in Chapter 12. For now, know that StatefulSets solve the "database lost its data on restart" problem.)

### StatefulSet YAML

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: learn-web
  namespace: learn-ch10
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch10
spec:
  serviceName: learn-web-headless   # Required: headless Service for DNS
  replicas: 3
  selector:
    matchLabels:
      app: web-stateful
  template:
    metadata:
      labels:
        app: web-stateful
        world: w03
        chapter: ch10
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
```

#### Key Fields

**`spec.serviceName: learn-web-headless`**
StatefulSets require a **headless Service** (a Service with `clusterIP: None`). This Service provides DNS entries for each individual Pod:

```
learn-web-0.learn-web-headless.learn-ch10.svc.cluster.local
learn-web-1.learn-web-headless.learn-ch10.svc.cluster.local
learn-web-2.learn-web-headless.learn-ch10.svc.cluster.local
```

This is how other Pods find specific StatefulSet members by name. You must create this headless Service separately.

**The headless Service:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-web-headless
  namespace: learn-ch10
spec:
  clusterIP: None          # This makes it "headless"
  selector:
    app: web-stateful
  ports:
    - port: 80
      targetPort: 80
```

### When to Use StatefulSet vs. Deployment

| Question | Deployment | StatefulSet |
|----------|-----------|-------------|
| Do Pods need stable names? | No | Yes |
| Do Pods need ordered startup? | No | Yes |
| Does each Pod need its own storage? | No (shared or none) | Yes |
| Are Pods interchangeable? | Yes | No |
| Example workloads | Web servers, APIs, workers | Databases, Kafka, Elasticsearch, Redis Cluster |

**Rule of thumb:** If your app is truly stateless and doesn't care about Pod identity, use a Deployment. If any of the StatefulSet guarantees matter, use a StatefulSet.

### StatefulSet Gotchas

1. **Deleting a StatefulSet does NOT delete its PVCs.** This is by design — you don't want to accidentally delete data. Clean up PVCs manually if you want to remove the storage.

2. **Scaling down deletes Pods but not PVCs.** If you scale from 3 to 2, `pod-2` is deleted but its PVC remains. Scaling back to 3 creates a new `pod-2` that reattaches to the existing PVC.

3. **Updates are more cautious.** By default, StatefulSets use `RollingUpdate` but update one Pod at a time in reverse order (pod-2 first, then pod-1, then pod-0). This minimizes disruption to stateful workloads.

---

## DaemonSets: One Per Node

A **DaemonSet** ensures that **one copy of a Pod runs on every node** (or a subset of nodes). When a new node joins the cluster, the DaemonSet controller automatically schedules a Pod on it. When a node is removed, the Pod is garbage collected.

Use cases:
- **Log collection:** Fluentd, Filebeat — collect logs from every node
- **Monitoring agents:** Node Exporter, Datadog agent — report node-level metrics
- **Network plugins:** CNI plugins, kube-proxy — infrastructure that must run on every node
- **Storage drivers:** CSI plugins — enable specific storage backends on each node

### DaemonSet YAML

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: learn-log-collector
  namespace: learn-ch10
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch10
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
        world: w03
        chapter: ch10
    spec:
      containers:
        - name: log-collector
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo \"[$(date)] Collecting logs from $(hostname)\"; sleep 30; done"]
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

Notice: **no `replicas` field**. DaemonSets don't use replica counts — the number of Pods equals the number of matching nodes.

### DaemonSet Behavior

```bash
# See the DaemonSet
kubectl get daemonsets -n learn-ch10

# Output:
# NAME                   DESIRED   CURRENT   READY   UP-TO-DATE   AGE
# learn-log-collector    1         1         1       1             5m
```

- `DESIRED`: Number of nodes that should have a Pod (in kind, typically 1)
- `CURRENT`: Number of Pods created
- `READY`: Number of Pods that are Ready

If you add a worker node to the kind cluster, the DaemonSet automatically creates a Pod on it. No manual intervention needed.

### Targeting Specific Nodes

By default, a DaemonSet runs on all nodes. You can restrict it using node selectors or tolerations:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        node-type: worker    # Only run on nodes with this label
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule   # Allow running on control-plane nodes
```

---

## Comparing All Workload Types

```
                        ┌─────────────────────────────────┐
                        │        Workload Decision         │
                        └─────────────────┬───────────────┘
                                          │
                              Run forever or finish?
                                          │
                          ┌───────────────┴───────────────┐
                          │                               │
                     Run forever                     Run to completion
                          │                               │
                  Need stable identity?           On a schedule?
                          │                               │
                   ┌──────┴──────┐                ┌──────┴──────┐
                   │             │                │             │
                  Yes           No              Yes            No
                   │             │                │             │
            StatefulSet    One per node?      CronJob         Job
                                 │
                          ┌──────┴──────┐
                          │             │
                         Yes           No
                          │             │
                      DaemonSet    Deployment
```

| Type | Replicas | Pod Names | Ordering | Storage | Use Case |
|------|----------|-----------|----------|---------|----------|
| Deployment | You set | Random | Any order | Shared/none | Web, API, workers |
| StatefulSet | You set | Ordinal (0,1,2) | Sequential | Per-Pod PVCs | Databases, distributed systems |
| DaemonSet | = nodes | Per-node | N/A | Typically hostPath | Agents, monitors, log collectors |
| Job | completions | Random | Any order | Usually none | Migrations, batch tasks |
| CronJob | Per schedule | Random | Any order | Usually none | Cleanup, reports, backups |

---

## Summary

| Concept | What it is |
|---------|-----------|
| StatefulSet | Workload with stable Pod names, ordered lifecycle, and per-Pod storage |
| Headless Service | Service with `clusterIP: None`; provides DNS for individual StatefulSet Pods |
| Ordinal index | Pods named `<name>-0`, `<name>-1`, etc.; used for identity |
| DaemonSet | One Pod per node; automatically adjusts when nodes join/leave |
| Node selector | Label-based targeting of specific nodes |
| PVC retention | StatefulSet PVCs persist even when Pods are deleted or StatefulSet is scaled down |

---

Time to put these workload types into practice. Head to the challenges.

**Challenges:**
- [Challenge 1: Batch Migration](../challenges/01-batch-migration.md) — Create a Job
- [Challenge 2: Scheduled Cleanup](../challenges/02-scheduled-cleanup.md) — Create a CronJob
- [Challenge 3: Stateful Service](../challenges/03-stateful-service.md) — Deploy a StatefulSet
