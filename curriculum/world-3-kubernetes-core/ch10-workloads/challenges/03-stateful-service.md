# Challenge 3: Stateful Service

## Briefing

The recommendation engine needs a cache layer. Dave wants to use a Deployment with 3 replicas for the cache. But the cache nodes need to know each other's identities — they form a cluster where `cache-0` is the primary and `cache-1`, `cache-2` are replicas.

"If a Pod dies and comes back with a different name, the cluster membership breaks," you explain. "We need stable identity. We need a StatefulSet."

---

## Objective

Deploy a StatefulSet with 3 replicas. Verify that Pods are created in order, have stable hostnames, and each Pod has a unique, predictable identity.

---

## Requirements

1. Create a **headless Service** named `learn-cache-headless` in `learn-ch10`:
   - `clusterIP: None`
   - Selector: `app: cache-stateful`
   - Port: 80, targetPort: 80

2. Create a **StatefulSet** named `learn-cache` in `learn-ch10`:
   - `serviceName: learn-cache-headless`
   - `replicas: 3`
   - Image: `nginx:1.25`
   - Selector and Pod labels must include: `app: cache-stateful`
   - Pod labels must also include: `world: w03`, `chapter: ch10`

3. After applying, verify:
   - Pods are named `learn-cache-0`, `learn-cache-1`, `learn-cache-2`
   - All 3 Pods are Running
   - Each Pod has a unique hostname (exec into one and run `hostname`)

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] Headless Service `learn-cache-headless` exists in `learn-ch10` with `clusterIP: None`
- [ ] StatefulSet `learn-cache` exists in `learn-ch10`
- [ ] StatefulSet has 3 ready replicas
- [ ] Pods `learn-cache-0`, `learn-cache-1`, `learn-cache-2` all exist and are Running

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

A StatefulSet requires two resources: the StatefulSet itself and a headless Service. The headless Service has `clusterIP: None` in its spec. The StatefulSet references the Service by name in `spec.serviceName`. Without the headless Service, DNS for individual Pods won't work.
</details>

<details>
<summary>Hint 2 — Watching ordered creation</summary>

Set up a watch before applying: `kubectl get pods -n learn-ch10 -l app=cache-stateful --watch`. You'll see `learn-cache-0` go through `Pending → ContainerCreating → Running` before `learn-cache-1` starts. This is the ordered creation guarantee of StatefulSets.
</details>

<details>
<summary>Hint 3 — Verifying stable identity</summary>

Once all Pods are Running, exec into one and check its hostname: `kubectl exec learn-cache-0 -n learn-ch10 -- hostname`. It should output `learn-cache-0`. If you delete this Pod, the replacement will also be named `learn-cache-0` — that's the stable identity guarantee.
</details>

---

## After You Finish

```bash
bash curriculum/world-3-kubernetes-core/ch10-workloads/challenges/verify.sh
```

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Created a headless Service and a StatefulSet with 3 replicas. The StatefulSet controller created Pods in order (`learn-cache-0` first, then `learn-cache-1`, then `learn-cache-2`). Each Pod got a stable hostname matching its ordinal name.

**Why it works:** The StatefulSet controller enforces ordering: it watches the Pod status and only creates the next Pod when the current one is Running and Ready. The headless Service provides DNS entries for each individual Pod (`learn-cache-0.learn-cache-headless.learn-ch10.svc.cluster.local`), enabling direct Pod-to-Pod communication by name.

**Real-world connection:** This is exactly how you'd deploy a Redis Cluster, Kafka, Elasticsearch, or PostgreSQL with streaming replication. The primary (pod-0) starts first, replicas join by connecting to the primary's DNS name. If a replica dies and comes back, it rejoins with the same identity and reattaches to its storage.

**Interview angle:** "When would you use a StatefulSet instead of a Deployment?" — When you need stable Pod names, ordered startup/shutdown, or per-Pod persistent storage. Examples: databases, distributed caches, message brokers. If the workload is truly stateless and Pods are interchangeable, use a Deployment.

**Pro tip:** Try deleting `learn-cache-1` and watching what happens. The StatefulSet recreates it with the same name. But notice: while the replacement is being created, `learn-cache-2` stays Running. The ordering guarantee only applies during initial creation and scale-up, not during replacement of individual Pods.
