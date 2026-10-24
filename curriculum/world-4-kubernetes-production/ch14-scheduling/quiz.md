# Chapter 14 Quiz: Scheduling & Resources

> **Sarah:** "Five questions. These are the resource and scheduling mistakes that cost companies money and uptime."

---

## Question 1

A pod has these resource settings:

```yaml
resources:
  requests:
    memory: "64Mi"
  limits:
    memory: "128Mi"
```

The pod is currently using 130Mi of memory. **What happens?**

A) The pod is throttled to 128Mi and continues running at reduced capacity.

B) The pod is killed by the OOM killer (Exit Code 137) because it exceeded its memory limit.

C) The scheduler evicts the pod and reschedules it on a node with more memory.

D) Nothing happens — the limit is advisory and the pod can use as much memory as the node has available.

<details>
<summary>Answer</summary>

**B.**

When a container exceeds its `limits.memory`, the Linux kernel's OOM killer terminates it with SIGKILL. The container exits with code 137 (128 + 9). Kubernetes records the reason as `OOMKilled`.

Important distinction: CPU limits cause **throttling** (the pod slows down). Memory limits cause **killing** (the pod dies). There is no "memory throttling" — the kernel can't slow down memory usage, only terminate the process.

</details>

---

## Question 2

A node has 4 GiB of memory. Three pods are running:
- Pod A: requests 1 GiB, limits 2 GiB
- Pod B: requests 1 GiB, limits 2 GiB
- Pod C: requests 1 GiB, limits 2 GiB

A new pod D requests 1.5 GiB of memory. **Can the scheduler place Pod D on this node?**

A) Yes — there's still 1 GiB of unused memory on the node, and the pod only needs 1.5 GiB.

B) No — the scheduler looks at **requests**, not actual usage. 3 GiB is already reserved (3 × 1 GiB), leaving only 1 GiB available, which is less than the 1.5 GiB requested.

C) Yes — the scheduler looks at **limits**, and since no pod is at its limit, there's room.

D) It depends on the QoS class of the existing pods.

<details>
<summary>Answer</summary>

**B.**

The scheduler reserves resources based on **requests**, not actual usage or limits. With 3 pods each requesting 1 GiB, 3 GiB of the node's 4 GiB is reserved. Only 1 GiB is available for new pod requests. Pod D needs 1.5 GiB — it won't fit and remains `Pending`.

This is true even if the existing pods are actually using only 500 MiB each (1.5 GiB total actual usage). The scheduler doesn't consider actual usage — it considers reserved capacity.

</details>

---

## Question 3

A Deployment has 3 replicas and all three pods are on Node 1. Nodes 2 and 3 are empty.

**Which of the following would distribute the pods across all three nodes?**

A) Setting `resources.requests` to a higher value so each node can only fit one pod.

B) Adding `topologySpreadConstraints` with `maxSkew: 1` and `topologyKey: kubernetes.io/hostname`.

C) Increasing the Deployment's `replicas` to 9 so the scheduler is forced to use all nodes.

D) Adding a `nodeSelector` that matches all three nodes.

<details>
<summary>Answer</summary>

**B.**

`topologySpreadConstraints` with `maxSkew: 1` tells the scheduler to distribute pods evenly across the specified topology domain (in this case, individual nodes via `kubernetes.io/hostname`). With 3 replicas and 3 nodes, this results in 1 pod per node.

Option A is a hack, not a solution — it depends on exact resource calculations and breaks when node sizes change. Option C wastes resources (you need 3 pods, not 9). Option D selects which nodes are eligible but doesn't control distribution across them.

Pod anti-affinity (`preferredDuringSchedulingIgnoredDuringExecution` with `topologyKey: kubernetes.io/hostname`) would also work, but it wasn't listed as an option.

</details>

---

## Question 4

You run `kubectl get hpa -n production` and see:

```
NAME       REFERENCE            TARGETS        MINPODS  MAXPODS  REPLICAS
api-hpa    Deployment/api       <unknown>/50%  2        10       2
```

**What are the two most likely causes of the `<unknown>` target?**

A) The HPA API version is wrong and the Deployment has too many replicas.

B) The Metrics Server is not installed (or not ready), or the Deployment's containers have no `requests.cpu` set.

C) The HPA target of 50% is too low, causing the metrics to be unreportable.

D) The Deployment name is misspelled in the HPA's `scaleTargetRef`.

<details>
<summary>Answer</summary>

**B.**

`<unknown>` in the TARGETS column means the HPA cannot read the current metric. Two causes cover almost every case:

1. **Metrics Server not installed or not ready.** The HPA reads CPU utilization from the Metrics API. Without it, no data. Diagnose: `kubectl top pods -n production`.

2. **`requests.cpu` not set.** The HPA calculates utilization as `current / requested`. If there's no request, the percentage is undefined. Diagnose: `kubectl get deployment api -n production -o yaml | grep -A 3 requests`.

To confirm: `kubectl describe hpa api-hpa -n production` — the Conditions section will state exactly which condition is failing.

</details>

---

## Question 5

A pod has the following configuration:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

Another pod has:

```yaml
# No resources section
```

The node runs out of memory. **Which pod is evicted first, and why?**

A) The first pod is evicted first because it has the highest resource reservation.

B) The second pod is evicted first because it has QoS class `BestEffort`, which is the lowest priority for eviction.

C) Both pods have equal eviction priority because Kubernetes doesn't consider QoS during eviction.

D) The second pod is never evicted because it has no limits to violate.

<details>
<summary>Answer</summary>

**B.**

The first pod has `requests == limits` for both CPU and memory, giving it QoS class **Guaranteed** — the highest eviction priority (last to be evicted).

The second pod has no resources set at all, giving it QoS class **BestEffort** — the lowest eviction priority (first to be evicted).

When a node is under memory pressure, the kubelet evicts pods in this order:
1. BestEffort (first — no guarantees, no protection)
2. Burstable (middle — has some resources set)
3. Guaranteed (last — only in extreme cases)

This is why you should always set resource requests and limits on production workloads. A BestEffort pod is the first sacrifice when things go wrong.

</details>

---

> **Sarah:** "Five for five? Good. You understand how Kubernetes schedules, resources, and scales. Exit Code 137 is no longer a mystery, and your pods don't all live on the same node anymore."
