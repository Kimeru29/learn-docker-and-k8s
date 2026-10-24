# Challenge 2: Spread Pods

> **Sarah:** "All three API replicas are on the same node. If that node goes down — maintenance, hardware failure, kernel panic — the entire API goes down with it. We have three nodes. Let's use them."

---

## The Situation

The `learn-api` Deployment in namespace `learn-ch14` has 3 replicas. All three have been scheduled on the same node because the scheduler had no instructions to spread them.

Your job: modify the Deployment so replicas are distributed across available nodes.

---

## Setup

```bash
kubectl create namespace learn-ch14 2>/dev/null || true
```

First, verify your kind cluster has multiple nodes:

```bash
kubectl get nodes
```

If your `learn-k8s` cluster has only one node (a control-plane-only setup), you may need to recreate it with workers. For this challenge, we'll work with whatever nodes are available and use topology spread constraints.

Apply the starting Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-ch14
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch14
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-api
  template:
    metadata:
      labels:
        app: learn-api
        world: w04
        chapter: ch14
    spec:
      containers:
        - name: api
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

```bash
kubectl apply -f api-deployment.yaml
```

Check where the pods landed:

```bash
kubectl get pods -n learn-ch14 -l app=learn-api -o wide
```

Note the `NODE` column. All three pods may be on the same node.

---

## Your Mission

Modify the `learn-api` Deployment so that replicas are distributed across nodes. Use **one** of these approaches:

**Option A: Pod Anti-Affinity** — Prevent multiple replicas from landing on the same node.

**Option B: Topology Spread Constraints** — Distribute replicas evenly across available nodes.

**Success criteria:**
- The Deployment has either `podAntiAffinity` or `topologySpreadConstraints` configured
- After applying, pods are distributed across nodes (verify with `kubectl get pods -o wide`)
- If your cluster has only one node, the constraint should use `whenUnsatisfiable: ScheduleAnyway` (soft) or `preferredDuringSchedulingIgnoredDuringExecution` to avoid pods being stuck in Pending

---

## Investigation

```bash
# Where are pods currently scheduled?
kubectl get pods -n learn-ch14 -l app=learn-api -o wide

# How many nodes do you have?
kubectl get nodes

# What labels do nodes have? (topology keys)
kubectl get nodes --show-labels
```

---

## Hints

<details>
<summary>Hint 1: Using topology spread constraints</summary>

Add a `topologySpreadConstraints` section to the pod template:

```yaml
spec:
  template:
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: learn-api
```

`maxSkew: 1` means the difference in pod count between any two nodes should be at most 1. `ScheduleAnyway` makes it a soft constraint — if even distribution isn't possible (e.g., single-node cluster), pods still get scheduled.

</details>

<details>
<summary>Hint 2: Using pod anti-affinity</summary>

Add a `podAntiAffinity` section to the pod template:

```yaml
spec:
  template:
    spec:
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

This tells the scheduler: "Prefer to put this pod on a node that doesn't already have a `learn-api` pod." Using `preferred` (soft) ensures pods aren't stuck Pending if there aren't enough nodes.

</details>

<details>
<summary>Hint 3: Forcing redistribution</summary>

After updating the Deployment spec, Kubernetes performs a rolling update that recreates the pods. However, the new pods might end up on the same node again depending on timing.

To force a full restart with the new scheduling rules:

```bash
kubectl rollout restart deployment/learn-api -n learn-ch14
```

Then check distribution:

```bash
kubectl get pods -n learn-ch14 -l app=learn-api -o wide
```

If your cluster only has one node, all pods will still be on that node — but the constraint is configured, and it will take effect when more nodes are available.

</details>

---

## Verification

```bash
bash curriculum/world-4-kubernetes-production/ch14-scheduling/challenges/verify.sh
```

Or check manually:

```bash
# Check for topology spread or anti-affinity configuration
kubectl get deployment learn-api -n learn-ch14 -o yaml | grep -A 10 -E "topologySpread|podAntiAffinity"

# Check pod distribution across nodes
kubectl get pods -n learn-ch14 -l app=learn-api -o wide
```

---

> **Sarah:** "Three nodes, three replicas, one line of YAML to spread them. Now a single node failure takes out one replica, not all three. That's the difference between a minor incident and a full outage."

**Next:** [Challenge 03 — Autoscaling](03-autoscaling.md)
