# Lesson 2: Scheduler Decisions

> **Sarah:** "All three API replicas ended up on the same node. Node 1 was at 95% CPU. Nodes 2 and 3 were empty. When Node 1 went down for maintenance, the entire API went with it. Nobody told the scheduler to spread things out."

---

## How the Scheduler Picks a Node

When you create a pod, the kube-scheduler decides which node to place it on. The process has two phases:

### Phase 1: Filtering

The scheduler eliminates nodes that **cannot** run the pod:
- Not enough CPU or memory to satisfy the pod's requests
- Node is cordoned (`kubectl cordon`)
- Node doesn't match the pod's node selector or affinity rules
- Node has taints the pod doesn't tolerate

After filtering, you have a list of **feasible** nodes.

### Phase 2: Scoring

The scheduler ranks feasible nodes by preference:
- How much free capacity does the node have? (spread vs bin-pack)
- Does the node match preferred affinity rules?
- Is the pod image already cached on the node? (faster startup)
- Does the node satisfy topology spread constraints?

The highest-scoring node wins.

**If no node passes filtering,** the pod stays in `Pending` state until a node becomes available.

```bash
# See why a pod is Pending
kubectl describe pod <name> -n <namespace>
# Events: "0/3 nodes are available: 3 Insufficient memory"
```

---

## Node Selector

The simplest placement constraint. A map of labels the target node must have.

```yaml
spec:
  nodeSelector:
    disktype: ssd
```

This pod will only be scheduled on nodes labeled `disktype=ssd`. If no nodes have that label, the pod stays Pending.

```bash
# Label a node
kubectl label node learn-k8s-worker disktype=ssd

# Check node labels
kubectl get nodes --show-labels
```

**Use node selectors when:** You have a simple, hard requirement (e.g., GPU nodes, SSD storage, specific zone).

---

## Node Affinity

More expressive than node selectors. Supports "prefer" (soft) and "require" (hard) rules.

### requiredDuringSchedulingIgnoredDuringExecution (hard)

The pod **must** be placed on a matching node. If no node matches, the pod stays Pending.

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: topology.kubernetes.io/zone
              operator: In
              values:
                - us-east-1a
                - us-east-1b
```

This pod must land in zone `us-east-1a` or `us-east-1b`.

### preferredDuringSchedulingIgnoredDuringExecution (soft)

The scheduler **prefers** matching nodes but will use non-matching nodes if necessary.

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
            - key: disktype
              operator: In
              values:
                - ssd
```

The `weight` (1–100) determines how strongly this preference affects scoring. Higher weight = stronger preference.

### Operators

| Operator | Meaning |
|----------|---------|
| `In` | Label value is in the list |
| `NotIn` | Label value is not in the list |
| `Exists` | Label key exists (any value) |
| `DoesNotExist` | Label key does not exist |
| `Gt` | Label value is greater than (numeric) |
| `Lt` | Label value is less than (numeric) |

---

## Pod Affinity and Anti-Affinity

Node affinity controls which **node** a pod prefers. Pod affinity/anti-affinity controls which **other pods** a pod wants to be near or far from.

### Pod Anti-Affinity (spread pods apart)

The most common use case: prevent replicas of the same Deployment from landing on the same node.

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values:
                - learn-api
        topologyKey: kubernetes.io/hostname
```

This says: "Do not schedule this pod on a node that already has a pod with `app=learn-api`."

`topologyKey` defines the "failure domain":
- `kubernetes.io/hostname` → one pod per node
- `topology.kubernetes.io/zone` → one pod per zone
- `topology.kubernetes.io/region` → one pod per region

**Hard vs soft anti-affinity:**

Hard (`required`): If there's no node without an existing `learn-api` pod, the new pod stays Pending. With 3 replicas and 3 nodes, this works. With 4 replicas and 3 nodes, one pod will be Pending forever.

Soft (`preferred`): The scheduler tries to spread but will co-locate if necessary.

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - learn-api
          topologyKey: kubernetes.io/hostname
```

### Pod Affinity (co-locate pods)

Less common. Place pods near each other for low-latency communication.

```yaml
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values:
                - learn-cache
        topologyKey: kubernetes.io/hostname
```

This says: "Schedule this pod on a node that already has a `learn-cache` pod." Useful when an app and its cache should be on the same node for performance.

---

## Topology Spread Constraints

A more flexible way to distribute pods evenly across failure domains.

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: learn-api
```

**Parameters:**

| Parameter | What it controls |
|-----------|-----------------|
| `maxSkew` | Maximum difference in pod count between any two topology domains. `1` means "as even as possible." |
| `topologyKey` | The failure domain (hostname, zone, region) |
| `whenUnsatisfiable` | `DoNotSchedule` (hard) or `ScheduleAnyway` (soft) |
| `labelSelector` | Which pods to consider when calculating distribution |

### Example with 3 nodes and 6 replicas

With `maxSkew: 1` and `topologyKey: kubernetes.io/hostname`:

```
Node 1: 2 pods  ✓
Node 2: 2 pods  ✓  (skew = 0, within maxSkew of 1)
Node 3: 2 pods  ✓
```

If one node goes down and pods are rescheduled:

```
Node 1: 3 pods  ✓
Node 2: 3 pods  ✓  (skew = 0)
```

Without topology spread, Kubernetes might put all 6 on one node.

### Topology spread vs pod anti-affinity

| Feature | Pod anti-affinity | Topology spread |
|---------|-------------------|-----------------|
| Goal | Keep pods apart | Distribute evenly |
| Granularity | Binary: same node or not | Numeric: maxSkew |
| Multiple replicas per domain | Hard anti-affinity says no | Topology spread says "balance" |
| Best for | "One per node" | "Spread evenly across zones" |

**Use pod anti-affinity** when you want at most one replica per node.  
**Use topology spread** when you have more replicas than nodes and want even distribution.

---

## Taints and Tolerations

Taints are the inverse of affinity — they **repel** pods from a node.

```bash
# Taint a node
kubectl taint nodes learn-k8s-worker dedicated=database:NoSchedule
```

No pod will be scheduled on this node unless it has a matching toleration:

```yaml
tolerations:
  - key: dedicated
    operator: Equal
    value: database
    effect: NoSchedule
```

### Taint effects

| Effect | Behavior |
|--------|----------|
| `NoSchedule` | New pods without the toleration are not scheduled. Existing pods stay. |
| `PreferNoSchedule` | Scheduler tries to avoid the node but will use it if necessary. |
| `NoExecute` | New pods are not scheduled AND existing pods without the toleration are evicted. |

### Common uses

- **Dedicated nodes:** Taint GPU nodes so only ML workloads get scheduled there
- **Node problems:** Kubernetes automatically taints nodes with `node.kubernetes.io/not-ready`
- **Maintenance:** Taint a node before draining to prevent new pods from arriving

---

## Practical Patterns

### High-availability API: spread across nodes

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: learn-api
```

### Database: dedicated node with SSD

```yaml
nodeSelector:
  disktype: ssd
tolerations:
  - key: dedicated
    value: database
    effect: NoSchedule
```

### Cache: co-locate with API

```yaml
affinity:
  podAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: learn-api
          topologyKey: kubernetes.io/hostname
```

---

## Quick Reference

```bash
# Check node labels
kubectl get nodes --show-labels

# Label a node
kubectl label node <name> <key>=<value>

# Taint a node
kubectl taint nodes <name> <key>=<value>:<effect>

# Remove a taint
kubectl taint nodes <name> <key>-

# See why a pod is Pending
kubectl describe pod <name> -n <namespace>

# See scheduler events
kubectl get events -n <namespace> --field-selector reason=FailedScheduling
```

---

> **Sarah:** "The scheduler is smart, but it only knows what you tell it. Without affinity rules, it optimizes for bin-packing — filling up one node before starting the next. That's efficient for the cloud bill but terrible for reliability. Tell the scheduler what you want."

**Next:** [Autoscaling](03-autoscaling.md)
