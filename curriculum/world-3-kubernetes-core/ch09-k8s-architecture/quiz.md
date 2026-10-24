# Chapter 9 Quiz: The Giant Roaster

Use this quiz to test your understanding before moving to Chapter 10 — or to unlock Chapter 9 if you're skipping ahead. You need 4 out of 5 correct to pass.

---

## Question 1

You have a Deployment with `replicas: 3`. You manually delete one Pod with `kubectl delete pod`. What happens next, and why?

**A)** The Pod stays deleted. Deployments only create Pods during the initial apply.

**B)** Kubernetes recreates the Pod automatically, because the ReplicaSet controller detects the actual count (2) is less than the desired count (3) and creates a replacement.

**C)** Kubernetes recreates the Pod, but you must run `kubectl apply` again to trigger the reconciliation.

**D)** The Deployment enters a degraded state and sends an alert, but does not automatically recover.

<details>
<summary>Answer</summary>

**B** — The ReplicaSet controller runs a continuous reconciliation loop comparing desired state vs. actual state. When actual (2) < desired (3), it creates a new Pod immediately. No `kubectl apply` is needed. This is the core self-healing behavior of Kubernetes.
</details>

---

## Question 2

Which control plane component is responsible for deciding *which node* a newly created Pod should run on?

**A)** The API Server — it handles all cluster decisions.

**B)** The Controller Manager — it manages Pod placement through the ReplicaSet controller.

**C)** The Scheduler — it evaluates node resources, taints, and affinity rules to pick the best node.

**D)** etcd — it stores the Pod assignment and nodes read from it directly.

<details>
<summary>Answer</summary>

**C** — The Scheduler watches for Pods with no `nodeName` assignment. It filters nodes that can't run the Pod (insufficient resources, taints), scores the remaining ones, and updates the Pod's `spec.nodeName` in etcd via the API Server. The kubelet on the chosen node then picks up the Pod and starts it.
</details>

---

## Question 3

What is the role of **etcd** in a Kubernetes cluster?

**A)** etcd is the container runtime that pulls images and starts containers on worker nodes.

**B)** etcd is a distributed key-value store that holds the complete desired state of the cluster — every resource definition, every configuration, every secret.

**C)** etcd is the load balancer that distributes traffic to Pods via iptables rules.

**D)** etcd is the CNI plugin that assigns IP addresses to Pods.

<details>
<summary>Answer</summary>

**B** — etcd is the cluster's database. When you run `kubectl apply`, your manifest is ultimately stored in etcd. The API Server is the only component that reads and writes etcd directly. All other control plane components (Scheduler, Controller Manager) watch the API Server, not etcd directly. Losing etcd without a backup means losing the entire cluster's memory of what should be running.
</details>

---

## Question 4

In Kubernetes, why do you create Deployments instead of Pods directly?

**A)** Pods cannot be created directly — they can only exist as children of a Deployment.

**B)** Deployments provide self-healing, scaling, and rolling updates. A Pod created directly has no controller watching it — if it dies, it stays dead.

**C)** Deployments use less memory than Pods.

**D)** Pods are deprecated in favor of Deployments.

<details>
<summary>Answer</summary>

**B** — A bare Pod has no controller managing it. If it's deleted or crashes, nobody recreates it. A Deployment creates a ReplicaSet, which continuously reconciles the actual Pod count against the desired count. This gives you self-healing (crashed Pods are replaced), scaling (change `replicas`), and rolling updates (new ReplicaSet with updated image, old one scales down).
</details>

---

## Question 5

A Pod is in `ImagePullBackOff` status. What does this mean, and what is your first diagnostic step?

**A)** The Pod ran to completion successfully. `ImagePullBackOff` is the status for finished Pods.

**B)** The container crashed after starting. Check `kubectl logs <pod-name>` to see the crash output.

**C)** Kubernetes cannot pull the container image — likely due to a wrong image name, bad tag, or missing registry credentials. The first diagnostic step is `kubectl describe pod <pod-name>` to read the Events section, which shows the exact image pull error.

**D)** The Pod is waiting for a PersistentVolume to be provisioned. `ImagePullBackOff` indicates a storage issue.

<details>
<summary>Answer</summary>

**C** — `ImagePullBackOff` means kubelet tried to pull the image and failed. The "BackOff" means Kubernetes is retrying with exponential delay. `kubectl describe pod` shows the Events section with the exact error (e.g., "repository does not exist", "unauthorized", "not found"). Common causes: typo in image name (like `ngnix` instead of `nginx`), nonexistent tag, private registry without pull secret, or Docker Hub rate limiting.
</details>

---

## Score

- **5/5** — You've got this. Chapter 10 won't know what hit it.
- **4/5** — Solid. One concept to review before moving on.
- **3/5 or below** — Worth rereading the lessons before moving to Chapter 10. The architecture concepts in this chapter are foundational for everything that follows.
