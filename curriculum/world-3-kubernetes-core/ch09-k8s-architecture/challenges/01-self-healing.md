# Challenge 1: Self-Healing

## Briefing

It's 3:15 AM. You've explained to Dave that Kubernetes automatically restarts crashed containers. His response: "Prove it."

Fair enough.

In this challenge, you'll deploy nginx with 3 replicas to your kind cluster, then deliberately delete one of the Pods. Your goal is to prove that Kubernetes brings it back without you doing anything.

This is the reconciliation loop in action — Kubernetes constantly comparing desired state (3 replicas) against actual state (2 replicas after deletion) and closing the gap.

---

## Objective

Create a Kubernetes Deployment that keeps 3 nginx Pods running in the `learn-ch09` namespace. The Deployment and its Pods must use correct labels. Manually delete one Pod and verify that Kubernetes automatically recreates it to maintain the desired count of 3.

---

## Prerequisites

Your kind cluster must be running and `kubectl` must be pointing to it:

```bash
kubectl cluster-info --context kind-learn-k8s
```

Create the namespace if it doesn't exist yet:

```bash
kubectl create namespace learn-ch09
```

---

## Requirements

1. Create a Deployment named `learn-nginx` in the `learn-ch09` namespace
2. The Deployment must run **3 replicas** of `nginx:1.25`
3. Pods must have these labels:
   - `app: nginx`
   - `world: w03`
   - `chapter: ch09`
4. All 3 Pods must be in `Running` status
5. Delete one Pod and watch Kubernetes recreate it
6. End state: 3 Pods running again

---

## Starting Point

Use this Deployment manifest as your starting point:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-nginx
  namespace: learn-ch09
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch09
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        world: w03
        chapter: ch09
    spec:
      containers:
        - name: nginx
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

---

## Your Tasks

1. Apply the Deployment manifest to your cluster
2. Verify all 3 Pods are running
3. Delete one Pod by name
4. Without running any additional commands, watch Kubernetes recreate it
5. Confirm you end up with 3 running Pods again

The entire challenge can be completed with `kubectl` commands — no need to modify the YAML.

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] A kind cluster named `learn-k8s` exists
- [ ] The namespace `learn-ch09` exists
- [ ] The Deployment `learn-nginx` is present in `learn-ch09`
- [ ] Exactly 3 Pods with label `app=nginx` are in `Running` status in `learn-ch09`
- [ ] Pods have the label `chapter=ch09`

---

## Hints

Stuck? Reveal hints one at a time — try to solve it yourself before reading the next one.

<details>
<summary>Hint 1 — General direction</summary>

The challenge has two phases: deploying, and then observing self-healing. For the deployment phase, think about how you apply a YAML manifest to a cluster. For the self-healing phase, you need to know the exact name of a running Pod before you can delete it.
</details>

<details>
<summary>Hint 2 — Getting the Pod name</summary>

Pod names are auto-generated and follow the pattern `<deployment-name>-<hash>-<hash>`. You can't predict them. There's a `kubectl` command that lists all Pods in a namespace and shows their names. Once you have a name, you can target that specific Pod for deletion.
</details>

<details>
<summary>Hint 3 — Watching the recreation happen</summary>

After deleting a Pod, you want to see K8s bring a new one up. There's a flag for `kubectl get pods` that streams live updates to the terminal — like `docker logs -f` but for resource state changes. Watch for a Pod to briefly appear as `Terminating`, then see a new one enter `ContainerCreating`, then `Running`. The total count should return to 3.
</details>

---

## After You Finish

Once all 3 Pods are running after deletion, verify with:

```bash
bash curriculum/world-3-kubernetes-core/ch09-k8s-architecture/challenges/verify.sh
```

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Deployed a Deployment with `replicas: 3`. Kubernetes created a ReplicaSet that maintains exactly 3 running Pod instances. When you deleted a Pod, the ReplicaSet controller noticed the count dropped to 2 and immediately created a replacement.

**Why it works:** The Deployment controller runs a continuous reconciliation loop. Desired state: 3 replicas. Actual state: 2. Gap: 1. Action: create 1 Pod. This loop runs in the background at all times.

**Real-world connection:** This is why Kubernetes can survive node failures. If a worker node goes offline, all Pods on that node stop reporting healthy. The controllers detect the gap and reschedule those Pods on remaining healthy nodes — usually within 5 minutes for node failures, or seconds for individual Pod failures.

**Interview angle:** "What happens when a Pod crashes in Kubernetes?" — The expected answer involves ReplicaSets, the reconciliation loop, and the difference between a Pod dying (ReplicaSet recreates it) vs. a node dying (Scheduler reschedules to other nodes).

**Pro tip:** Set `kubectl get pods -n learn-ch09 --watch` in a separate terminal before deleting the Pod, so you see the Terminating → ContainerCreating → Running transition happen live. This is how you'd monitor a rolling update in production.
