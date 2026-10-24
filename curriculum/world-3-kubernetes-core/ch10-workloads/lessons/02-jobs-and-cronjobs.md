# Lesson 2: Jobs and CronJobs

## Jobs: Run Once, Then Stop

A **Job** creates one or more Pods and ensures they run to **completion**. Unlike a Deployment (which restarts Pods forever), a Job's Pods are expected to exit with status 0 (success). Once all Pods complete successfully, the Job is marked as `Complete`.

This is the right workload type for:
- Database migrations
- Batch data processing
- Data exports or imports
- One-time cleanup scripts
- Test suites

### Job YAML

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: learn-db-migrate
  namespace: learn-ch10
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch10
spec:
  backoffLimit: 3
  activeDeadlineSeconds: 120
  template:
    metadata:
      labels:
        app: db-migrate
        world: w03
        chapter: ch10
    spec:
      restartPolicy: Never    # Jobs must use Never or OnFailure
      containers:
        - name: migrate
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Running migration...' && sleep 5 && echo 'Migration complete!'"]
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
```

#### Key Fields

**`spec.backoffLimit: 3`**
How many times Kubernetes will retry the Job if a Pod fails. After 3 failures, the Job is marked as `Failed` and no more Pods are created. The default is 6.

**`spec.activeDeadlineSeconds: 120`**
Maximum time the Job can run before being terminated. If the Job hasn't completed within this time, Kubernetes kills it. This prevents runaway jobs from consuming resources indefinitely.

**`spec.template.spec.restartPolicy: Never`**
Jobs must use `Never` or `OnFailure`:
- `Never`: If the Pod fails, create a new Pod (the old one stays for debugging with `kubectl logs`)
- `OnFailure`: Restart the container within the same Pod (the Pod stays, container restarts)

Deployments use `Always` (the default), which is why you can't use a Deployment for one-shot tasks.

### Job Lifecycle

```
kubectl apply → Job created
                  │
                  ▼
              Pod created → Container runs → Exit code 0?
                                                │
                                    ┌───────────┴───────────┐
                                    ▼                       ▼
                                  Yes                      No
                                    │                       │
                                    ▼                       ▼
                              Job: Complete          Retry (up to backoffLimit)
                              Pod: Completed         Pod: Error
```

### Monitoring Jobs

```bash
# List Jobs
kubectl get jobs -n learn-ch10

# Watch Job progress
kubectl get jobs -n learn-ch10 --watch

# See the Pod created by a Job
kubectl get pods -n learn-ch10 -l job-name=learn-db-migrate

# Read the Pod's output
kubectl logs -l job-name=learn-db-migrate -n learn-ch10

# Delete a completed Job (and its Pods)
kubectl delete job learn-db-migrate -n learn-ch10
```

Sample `kubectl get jobs` output:
```
NAME               COMPLETIONS   DURATION   AGE
learn-db-migrate   1/1           8s         2m
```

`COMPLETIONS: 1/1` means 1 out of 1 required completions succeeded.

### Parallel Jobs

For batch processing, you can run multiple Pods in parallel:

```yaml
spec:
  completions: 5      # Total Pods that must succeed
  parallelism: 2      # How many Pods run simultaneously
  backoffLimit: 3
```

This creates up to 2 Pods at a time until 5 have completed successfully. Useful for processing a queue or batch dataset.

---

## CronJobs: Jobs on a Schedule

A **CronJob** creates Jobs on a time-based schedule. It's the Kubernetes equivalent of `cron` on Linux.

### CronJob YAML

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: learn-cleanup
  namespace: learn-ch10
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch10
spec:
  schedule: "*/5 * * * *"           # Every 5 minutes
  successfulJobsHistoryLimit: 3     # Keep last 3 successful Jobs
  failedJobsHistoryLimit: 1         # Keep last 1 failed Job
  concurrencyPolicy: Forbid         # Don't overlap
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        metadata:
          labels:
            app: cleanup
            world: w03
            chapter: ch10
        spec:
          restartPolicy: Never
          containers:
            - name: cleanup
              image: busybox:1.36
              command: ["sh", "-c", "echo 'Cleaning up old data...' && date && echo 'Cleanup done!'"]
              resources:
                requests:
                  memory: "16Mi"
                  cpu: "25m"
                limits:
                  memory: "32Mi"
                  cpu: "50m"
```

#### Key Fields

**`spec.schedule`**
Standard cron format: `minute hour day-of-month month day-of-week`

| Schedule | Meaning |
|----------|---------|
| `*/5 * * * *` | Every 5 minutes |
| `0 * * * *` | Every hour (at minute 0) |
| `0 2 * * *` | Daily at 2:00 AM |
| `0 0 * * 0` | Weekly on Sunday at midnight |
| `0 0 1 * *` | Monthly on the 1st at midnight |

**`spec.successfulJobsHistoryLimit`** and **`spec.failedJobsHistoryLimit`**
How many completed/failed Jobs to keep. Old Jobs (and their Pods) are garbage collected. Default is 3 successful and 1 failed.

**`spec.concurrencyPolicy`**
What happens if a new Job trigger occurs while the previous one is still running:

| Policy | Behavior |
|--------|----------|
| `Allow` (default) | Let them overlap; multiple Jobs can run simultaneously |
| `Forbid` | Skip the new run if the previous one hasn't finished |
| `Replace` | Kill the previous Job and start a new one |

`Forbid` is the safest for most data operations — you don't want two cleanup scripts running at the same time.

### CronJob Hierarchy

```
CronJob
  └── Job (created at each schedule tick)
        └── Pod (created by the Job)
              └── Container (does the actual work)
```

The CronJob controller creates a new Job at each scheduled time. The Job controller creates a Pod. The Pod runs to completion. Old Jobs are garbage collected based on history limits.

### Monitoring CronJobs

```bash
# List CronJobs
kubectl get cronjobs -n learn-ch10

# See the Jobs created by a CronJob
kubectl get jobs -n learn-ch10 -l app=cleanup

# See the last schedule
kubectl get cronjobs learn-cleanup -n learn-ch10 -o jsonpath='{.status.lastScheduleTime}'

# Trigger a CronJob manually (for testing)
kubectl create job learn-manual-cleanup --from=cronjob/learn-cleanup -n learn-ch10
```

Sample `kubectl get cronjobs` output:
```
NAME            SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
learn-cleanup   */5 * * * *   False     0        2m              15m
```

---

## TTL for Finished Jobs

By default, completed Job Pods stick around so you can read their logs. In production, this creates clutter. You can auto-clean them:

```yaml
spec:
  ttlSecondsAfterFinished: 300   # Delete Pod 5 minutes after completion
```

This is a Job-level setting. It applies to each individual Job, whether created directly or by a CronJob.

---

## Common Pitfalls

### 1. Using `restartPolicy: Always` in a Job

This is invalid. Jobs require `Never` or `OnFailure`. If you try `Always`, kubectl will reject the manifest with a validation error.

### 2. Forgetting `backoffLimit`

Without it, a failing Job will retry 6 times (the default). If your Job is doing something expensive (like sending emails), set a low `backoffLimit` to prevent accidental spam.

### 3. CronJob Timezone

CronJobs use the **kube-controller-manager's timezone** (usually UTC). If you need a specific timezone, use `spec.timeZone` (available since K8s 1.27):

```yaml
spec:
  schedule: "0 9 * * *"
  timeZone: "America/New_York"   # 9 AM Eastern
```

### 4. Missing `activeDeadlineSeconds`

Without a deadline, a stuck Job runs forever (consuming resources). Always set a reasonable deadline for production Jobs.

---

## Summary

| Concept | What it is |
|---------|-----------|
| Job | Runs Pods to completion; for one-shot tasks |
| `backoffLimit` | Max retries before marking a Job as Failed |
| `activeDeadlineSeconds` | Max runtime for a Job |
| `restartPolicy: Never` | Don't restart the container; create a new Pod on failure |
| `completions` / `parallelism` | Run multiple Pods for batch processing |
| CronJob | Creates Jobs on a cron schedule |
| `concurrencyPolicy` | How to handle overlapping runs (Allow, Forbid, Replace) |
| `successfulJobsHistoryLimit` | How many completed Jobs to keep |
| `ttlSecondsAfterFinished` | Auto-delete Pod after completion |

---

Up next: [Lesson 3 — StatefulSets and DaemonSets](03-statefulsets-and-daemonsets.md)

Jobs handle the "run once" pattern. Now let's look at two more specialized workload types: StatefulSets for ordered, identity-aware workloads, and DaemonSets for per-node agents.
