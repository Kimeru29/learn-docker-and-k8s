# Challenge 2: Explore Architecture

## Briefing

Sarah's teaching moment: "Before you deploy anything to a cluster, you should be able to read what's already there. Every K8s engineer I respect can look at a cluster and tell me what's running, what's healthy, and what's suspicious — without any dashboards."

In this challenge, you'll use kubectl to explore your kind cluster's architecture. You'll find the control plane components, inspect nodes, read events, and answer questions about what you discover.

This isn't about deploying anything — it's about observation and understanding.

---

## Objective

Use kubectl to explore the `learn-k8s` kind cluster. Identify the control plane components, understand the node structure, and answer architecture questions by examining real cluster state.

---

## Prerequisites

Your kind cluster must be running:

```bash
kubectl cluster-info --context kind-learn-k8s
```

---

## Your Tasks

### Part 1: Find the Control Plane

1. List all Pods running in the `kube-system` namespace
2. Identify which Pods correspond to these control plane components:
   - API Server
   - etcd
   - Scheduler
   - Controller Manager
3. Find the CNI plugin (networking) and DNS service

### Part 2: Inspect the Node

4. Describe the control plane node
5. Find how much CPU and memory is **allocatable** (available for workloads)
6. List all Pods currently running on this node (look in the describe output)
7. Check if the node has any **taints** (restrictions on what can be scheduled)

### Part 3: Read the Cluster

8. List all namespaces in the cluster
9. Get recent events from `kube-system` sorted by timestamp
10. Find the Kubernetes version the cluster is running

### Part 4: Verify Your Understanding

Create a file called `learn-architecture-answers.txt` in your working directory with answers to these questions (one per line):

```
1. How many control plane Pods run in kube-system? (count them)
2. What is the name of the CNI plugin used by this kind cluster?
3. How many CoreDNS replicas are running?
4. What role does the node have? (from kubectl get nodes output)
5. What container runtime is this cluster using? (from kubectl describe node)
```

Then create a ConfigMap from this file in the `learn-ch09` namespace:

```bash
kubectl create configmap learn-architecture-answers \
  --from-file=learn-architecture-answers.txt \
  -n learn-ch09
```

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] The ConfigMap `learn-architecture-answers` exists in `learn-ch09`
- [ ] The ConfigMap contains a key `learn-architecture-answers.txt`
- [ ] The ConfigMap has content (not empty)

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

All the information you need is accessible through `kubectl get` and `kubectl describe`. The kube-system namespace is where the system components live. Look at the Pod names — they follow a naming convention that tells you which component each Pod runs.
</details>

<details>
<summary>Hint 2 — Finding specific information</summary>

For allocatable resources: `kubectl describe node` has a section called "Allocatable" with CPU and memory values. For the container runtime: the same describe output has a "Container Runtime Version" field. For taints: look for a "Taints" section in the describe output.
</details>

<details>
<summary>Hint 3 — Creating the ConfigMap</summary>

Write your answers to a text file first, then use `kubectl create configmap --from-file=`. The `--from-file` flag creates a key in the ConfigMap with the filename as the key and the file content as the value. Make sure the file isn't empty and contains your answers.
</details>

---

## After You Finish

Run the verification script:

```bash
bash curriculum/world-3-kubernetes-core/ch09-k8s-architecture/challenges/verify.sh
```

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Explored a live Kubernetes cluster using kubectl, identified control plane components, inspected node capacity and status, and demonstrated understanding of the architecture by answering questions.

**Why it works:** Kubernetes runs its own infrastructure as Pods. The control plane components (API server, etcd, scheduler, controller manager) run as static Pods on the control plane node. Understanding what's in `kube-system` gives you visibility into the cluster's internals.

**Real-world connection:** In production, the first thing you do when joining a team is explore the cluster. `kubectl get pods -A`, `kubectl describe node`, and `kubectl get events` are your starting commands. Understanding what's "normal" helps you spot what's abnormal when things break at 3 AM.

**Interview angle:** "Walk me through how you'd assess the health of a Kubernetes cluster." — Start with nodes (Ready?), then check kube-system Pods (all Running?), then look at events for warnings. Mention resource pressure conditions (MemoryPressure, DiskPressure) and node taints.

**Pro tip:** The `kubectl get events --sort-by='.lastTimestamp'` command is underrated. In production, events are often the fastest way to understand what happened, especially when combined with `--field-selector reason=Failed` or `--field-selector involvedObject.kind=Pod` to filter noise.
