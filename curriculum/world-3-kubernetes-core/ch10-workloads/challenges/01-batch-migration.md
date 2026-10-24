# Challenge 1: Batch Migration

## Briefing

Marcus just approved the new recommendation engine feature. But before it can go live, you need to run a database migration — a one-time script that updates the schema and seeds some data.

Dave suggests putting it in a Deployment. "Just set replicas to 1, right?"

You explain why that's a terrible idea: the migration would run, complete, exit, and then Kubernetes would restart it. Infinite migration loop. The right tool for a one-shot task is a **Job**.

---

## Objective

Create a Kubernetes Job that simulates a database migration script. The Job should run to completion and handle potential failures gracefully.

---

## Requirements

1. Create a Job named `learn-db-migrate` in the `learn-ch10` namespace
2. Use image `busybox:1.36`
3. The Job should run the command: `sh -c "echo 'Starting migration...' && sleep 3 && echo 'Applying schema changes...' && sleep 2 && echo 'Migration complete!' && exit 0"`
4. Set `backoffLimit` to 3 (allow up to 3 retries on failure)
5. Set `activeDeadlineSeconds` to 60 (prevent runaway execution)
6. Use `restartPolicy: Never`
7. Pod labels must include: `app: db-migrate`, `world: w03`, `chapter: ch10`
8. After applying, the Job should reach `Complete` status
9. The Pod should show `Completed` status

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] Job `learn-db-migrate` exists in `learn-ch10`
- [ ] Job has `Complete` condition
- [ ] Pod created by the Job shows `Completed` status
- [ ] `backoffLimit` is set to 3
- [ ] Pod has correct labels (`chapter=ch10`)

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

A Job manifest looks similar to a Deployment but uses `apiVersion: batch/v1` and `kind: Job`. The `spec` section is different — no `replicas` field, but you do need `backoffLimit`, `activeDeadlineSeconds`, and a `template` with `restartPolicy: Never`. Look at the lesson for the structure.
</details>

<details>
<summary>Hint 2 — Checking the Job status</summary>

After applying, use `kubectl get jobs -n learn-ch10` to see the Job status. The `COMPLETIONS` column shows progress (e.g., `1/1`). If it shows `0/1`, the Pod hasn't completed yet — check the Pod with `kubectl get pods -n learn-ch10 -l job-name=learn-db-migrate`.
</details>

<details>
<summary>Hint 3 — Reading the output</summary>

To see what the migration script printed, find the Pod created by the Job and read its logs. The Pod name will include the Job name as a prefix. Use `kubectl logs` with the Pod name or with the label selector `-l job-name=learn-db-migrate`.
</details>

---

## After You Finish

```bash
bash curriculum/world-3-kubernetes-core/ch10-workloads/challenges/verify.sh
```

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Created a Job that runs a migration script once and stops. The Pod ran the command, printed its output, exited with code 0, and was marked as `Completed`. The Job controller confirmed the completion count.

**Why it works:** Jobs use `restartPolicy: Never` (or `OnFailure`), which means the container is not restarted after exit. The Job controller counts successful completions. When `completions` (default: 1) is reached, the Job is marked `Complete`. If the Pod had failed, the Job controller would have created a new Pod, up to `backoffLimit` times.

**Real-world connection:** Database migrations in production K8s clusters are commonly run as Jobs — often as init containers or Helm hooks. The `activeDeadlineSeconds` prevents stuck migrations from blocking deployments. `backoffLimit` prevents infinite retry loops on permanent failures.

**Interview angle:** "How would you run a database migration in Kubernetes?" — Use a Job (not a Deployment). Set `backoffLimit` to prevent infinite retries. Set `activeDeadlineSeconds` to prevent stuck processes. Use `restartPolicy: Never` so you can inspect failed Pods with `kubectl logs`. Consider an init container on the main Deployment if the migration must complete before the app starts.

**Pro tip:** After a Job completes, the Pod stays around (in `Completed` status) so you can read its logs. Use `spec.ttlSecondsAfterFinished` to auto-clean completed Pods if log retention isn't needed.
