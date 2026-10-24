# Chapter 13 Quiz: Health & Reliability

> **Sarah:** "Five questions. These are the things that cause production incidents when people get them wrong."

---

## Question 1

A Deployment has 3 replicas running a web API. One pod is stuck in a deadlock — it accepts TCP connections but never sends HTTP responses. There are no health probes configured.

**What happens to traffic sent to this pod, and which probe type would fix the problem?**

A) Kubernetes detects the deadlock and restarts the pod automatically. No probe is needed.

B) Traffic continues to flow to the stuck pod indefinitely. A **liveness probe** would detect the deadlock and restart the pod.

C) Traffic continues to flow to the stuck pod indefinitely. A **readiness probe** would remove the pod from endpoints but not restart it. A **liveness probe** is also needed to restart it.

D) The pod shows `CrashLoopBackOff` after the deadlock. A **startup probe** would prevent this.

<details>
<summary>Answer</summary>

**C.**

Without probes, Kubernetes only checks if the container process is running (PID 1 is alive). A deadlocked process is still running — it just can't do useful work. Traffic continues flowing to it via the Service.

A **readiness probe** would remove the pod from Service endpoints (stopping traffic to it). A **liveness probe** would detect the deadlock and restart the pod. In practice, you want both: readiness to protect users immediately, liveness to recover the pod.

Option A is wrong — Kubernetes has no way to detect application-level deadlocks without probes. Option D is wrong — deadlocks don't cause CrashLoopBackOff (the process is still running).

</details>

---

## Question 2

A Deployment has this configuration:

```yaml
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 0
```

**During a rolling update, what is the maximum number of pods that can exist simultaneously, and what is the minimum number of ready pods at any time?**

A) Maximum: 4 pods. Minimum ready: 2 pods.

B) Maximum: 6 pods. Minimum ready: 4 pods.

C) Maximum: 6 pods. Minimum ready: 2 pods.

D) Maximum: 8 pods. Minimum ready: 4 pods.

<details>
<summary>Answer</summary>

**B.**

With `replicas: 4` and `maxSurge: 2`: K8s can run up to `4 + 2 = 6` pods simultaneously.

With `maxUnavailable: 0`: zero pods can be unavailable at any time, so the minimum number of ready pods is always 4 (the full desired count).

The update proceeds by starting up to 2 new pods (total 6), waiting for them to be Ready, then removing up to 2 old pods (total 4), and repeating. You always have at least 4 ready pods.

</details>

---

## Question 3

A liveness probe is configured to check the database connection:

```yaml
livenessProbe:
  httpGet:
    path: /healthz   # This endpoint queries the database
    port: 8080
  periodSeconds: 10
  failureThreshold: 3
```

The database goes down for 2 minutes. **What happens to the pods, and why is this configuration problematic?**

A) The pods are removed from Service endpoints until the database recovers. This is correct behavior.

B) All pods fail the liveness probe and are restarted. When they come back up, they all try to reconnect to the still-down database, fail again, and restart again — creating a restart cascade.

C) The pods continue running normally because liveness probes only check the container process, not dependencies.

D) The liveness probe is ignored because the database is an external dependency.

<details>
<summary>Answer</summary>

**B.**

Liveness probes that check dependencies are dangerous. When the database goes down, all pods fail the liveness check and get restarted. The restarted pods immediately try to connect to the still-down database, fail the liveness check again, and restart again. This is a **restart cascade** — the pods are healthy, but the liveness probe is killing them because a dependency is down.

**The fix:** Liveness probes should check the application process, not its dependencies. Use a `/livez` endpoint that returns 200 if the HTTP server is running. Use a **readiness probe** to check dependencies — it removes the pod from endpoints (no traffic) but doesn't restart it.

</details>

---

## Question 4

A pod has `terminationGracePeriodSeconds: 30` and a preStop hook that sleeps for 20 seconds. The application needs 25 seconds to drain connections after receiving SIGTERM.

**What happens when this pod is terminated?**

A) The pod shuts down gracefully in 45 seconds (20s preStop + 25s drain).

B) The pod is killed by SIGKILL after 30 seconds. The preStop hook completes (20s), but the application only gets 10 seconds for drain before SIGKILL, not the 25 it needs.

C) The preStop hook and the grace period run independently, so the pod gets 50 seconds total.

D) The preStop hook is skipped because the grace period is shorter than the total time needed.

<details>
<summary>Answer</summary>

**B.**

`terminationGracePeriodSeconds` is the **total** time from the start of the preStop hook to SIGKILL. It is not additive — the preStop hook runs within the grace period.

Timeline:
- T=0: preStop hook starts (sleep 20)
- T=20: SIGTERM sent to the process
- T=30: SIGKILL sent — only 10 seconds elapsed since SIGTERM, but the 30-second grace period is up
- The application needed 25 seconds to drain but only got 10

**Fix:** Set `terminationGracePeriodSeconds` to at least 50 (20s preStop + 25s drain + 5s buffer).

</details>

---

## Question 5

You need to run a database migration before your API containers start. The migration takes 10–30 seconds and must complete successfully before the API accepts traffic. **Which pattern should you use?**

A) Add the migration command to the API container's startup script so it runs before the HTTP server starts.

B) Use a **startup probe** with a 30-second timeout to delay readiness until the migration completes.

C) Use an **init container** that runs the migration. The API containers only start after the init container exits with code 0.

D) Use a **preStop hook** to run the migration before the previous version's pods are terminated.

<details>
<summary>Answer</summary>

**C.**

An init container runs to completion before the main containers start. If the migration fails (non-zero exit code), the pod retries the init container — the API never starts with an unmigrated database.

Option A works but mixes concerns — the API container shouldn't be responsible for schema management. It also means every replica runs the migration, creating race conditions.

Option B is wrong — a startup probe checks if the main container is ready, but the migration needs to run as a separate step before the API starts.

Option D is wrong — preStop runs during shutdown, not startup.

</details>

---

> **Sarah:** "Five for five? Good. You understand the difference between running and ready, between killing and draining, and between liveness and readiness. That's production thinking."
