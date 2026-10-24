# Chapter 10 Quiz: The Fleet

Use this quiz to test your understanding before moving to Chapter 11 — or to unlock Chapter 10 if you're skipping ahead. You need 4 out of 5 correct to pass.

---

## Question 1

Marcus wants to run a database migration script that should execute once, apply schema changes, and stop. Which workload type should he use?

**A)** A Deployment with `replicas: 1` — it runs one instance of the script.

**B)** A Job — it runs the Pod to completion and doesn't restart it after exit.

**C)** A CronJob with a schedule far in the future — it will only run once.

**D)** A DaemonSet — it ensures the migration runs on every node.

<details>
<summary>Answer</summary>

**B** — A Job is designed for one-shot tasks. It creates a Pod, runs the command, and when the container exits with code 0, the Job is marked `Complete`. A Deployment (A) would restart the container after it exits (infinite migration loop). A CronJob (C) is for recurring tasks, and using it as a one-shot is a hack. A DaemonSet (D) runs on every node, which makes no sense for a migration.
</details>

---

## Question 2

You create a StatefulSet named `learn-db` with 3 replicas. What will the Pod names be, and in what order are they created?

**A)** `learn-db-abc12`, `learn-db-def34`, `learn-db-ghi56` — created in random order, like a Deployment.

**B)** `learn-db-0`, `learn-db-1`, `learn-db-2` — created sequentially. `learn-db-0` must be Running before `learn-db-1` starts.

**C)** `learn-db-0`, `learn-db-1`, `learn-db-2` — created simultaneously for faster startup.

**D)** `learn-db-primary`, `learn-db-replica-1`, `learn-db-replica-2` — Kubernetes names them based on their role.

<details>
<summary>Answer</summary>

**B** — StatefulSet Pods get ordinal names: `<statefulset-name>-<index>`. They are created sequentially — `learn-db-0` must be Running and Ready before `learn-db-1` is created. This ordering matters for databases and distributed systems where the primary must be available before replicas try to connect.
</details>

---

## Question 3

A CronJob has `concurrencyPolicy: Forbid`. What happens when a scheduled trigger occurs but the previous Job hasn't finished yet?

**A)** The new Job runs alongside the old one — they execute concurrently.

**B)** The old Job is killed and the new Job takes its place.

**C)** The new Job run is skipped entirely. The CronJob waits for the next scheduled trigger.

**D)** The CronJob enters an error state and stops scheduling until manually reset.

<details>
<summary>Answer</summary>

**C** — `Forbid` means: if a previous Job is still running, skip this trigger entirely. The CronJob will try again at the next scheduled time. This is the safest option for operations that shouldn't overlap, like database backups or cleanup scripts. `Allow` would create a concurrent Job (A). `Replace` would kill the old Job and start a new one (B).
</details>

---

## Question 4

What is the purpose of a headless Service (`clusterIP: None`) when used with a StatefulSet?

**A)** It prevents external traffic from reaching the StatefulSet Pods.

**B)** It provides individual DNS records for each StatefulSet Pod (e.g., `pod-0.service-name.namespace.svc.cluster.local`), enabling direct Pod-to-Pod discovery.

**C)** It removes the need for kube-proxy rules, reducing network overhead.

**D)** It makes the StatefulSet Pods invisible to other resources in the cluster.

<details>
<summary>Answer</summary>

**B** — A headless Service doesn't allocate a ClusterIP. Instead, DNS queries return the individual Pod IPs directly. For StatefulSets, this creates predictable DNS names for each Pod: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`. This is how distributed systems (databases, caches) discover specific cluster members by name.
</details>

---

## Question 5

Which workload type ensures exactly one Pod runs on every node in the cluster, and automatically adds Pods when new nodes join?

**A)** Deployment with a node affinity rule

**B)** StatefulSet with replicas equal to the number of nodes

**C)** DaemonSet

**D)** CronJob with a node selector

<details>
<summary>Answer</summary>

**C** — A DaemonSet automatically schedules one Pod per node. When a new node joins the cluster, the DaemonSet controller creates a Pod on it. When a node is removed, the Pod is cleaned up. No manual replica count management needed. A Deployment with node affinity (A) would require manual replica count updates. A StatefulSet (B) also requires manual updates and provides ordered semantics you don't need.
</details>

---

## Score

- **5/5** — The fleet is yours to command. Onward to Chapter 11.
- **4/5** — Solid. One workload type to review before moving on.
- **3/5 or below** — Review the lessons on Jobs, CronJobs, StatefulSets, and DaemonSets. Understanding when to use each type is critical for production K8s.
