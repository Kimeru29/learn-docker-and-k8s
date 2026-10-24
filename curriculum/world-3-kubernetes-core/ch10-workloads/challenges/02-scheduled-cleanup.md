# Challenge 2: Scheduled Cleanup

## Briefing

NoCappuccino's recommendation engine generates temporary data files every time it processes user preferences. These files pile up. Marcus wants an automated cleanup that runs regularly without anyone having to remember.

"Can't we just put a cron job on the server?" Dave asks.

"We don't have *a server* anymore," you remind him. "We have a cluster. But Kubernetes has CronJobs built in."

---

## Objective

Create a CronJob that runs a cleanup script on a schedule. Verify that it executes and maintains the correct job history.

---

## Requirements

1. Create a CronJob named `learn-cleanup` in the `learn-ch10` namespace
2. Use image `busybox:1.36`
3. Schedule: every 2 minutes (`*/2 * * * *`)
4. The command should: `sh -c "echo '[cleanup] Starting at $(date)' && echo 'Removing temp files...' && sleep 2 && echo '[cleanup] Done!'"`
5. Set `successfulJobsHistoryLimit` to 3
6. Set `failedJobsHistoryLimit` to 1
7. Set `concurrencyPolicy` to `Forbid`
8. Job template should have `backoffLimit: 2` and `restartPolicy: Never`
9. Pod labels must include: `app: cleanup`, `world: w03`, `chapter: ch10`
10. Wait for at least one Job to complete (you may need to wait up to 2 minutes)

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] CronJob `learn-cleanup` exists in `learn-ch10`
- [ ] CronJob schedule is set (not empty)
- [ ] At least one Job has been created by the CronJob
- [ ] `successfulJobsHistoryLimit` is set to 3
- [ ] `concurrencyPolicy` is set to `Forbid`

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

A CronJob wraps a Job template inside a schedule. The structure is `CronJob → spec.jobTemplate → spec.template → spec.containers`. Look at the lesson for the YAML structure. Remember: `apiVersion: batch/v1` for CronJobs.
</details>

<details>
<summary>Hint 2 — Verifying execution</summary>

After applying, the CronJob won't create its first Job until the schedule triggers. With `*/2 * * * *`, you'll need to wait up to 2 minutes. Use `kubectl get cronjobs -n learn-ch10 --watch` to see the LAST SCHEDULE column update. Then check `kubectl get jobs -n learn-ch10` to see the created Job.
</details>

<details>
<summary>Hint 3 — Triggering manually</summary>

If you don't want to wait, you can manually trigger a Job from a CronJob: `kubectl create job learn-manual-test --from=cronjob/learn-cleanup -n learn-ch10`. This creates a one-off Job immediately using the CronJob's template. It's great for testing.
</details>

---

## After You Finish

```bash
bash curriculum/world-3-kubernetes-core/ch10-workloads/challenges/verify.sh
```

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Created a CronJob that runs a cleanup script on a schedule. The CronJob controller created a Job at the scheduled time, which created a Pod that ran the cleanup and exited. History limits ensure old Jobs are cleaned up automatically.

**Why it works:** The CronJob controller watches the clock and creates a new Job at each scheduled tick. `concurrencyPolicy: Forbid` prevents overlap — if a previous Job is still running when the next tick hits, the new run is skipped. `successfulJobsHistoryLimit: 3` keeps the last 3 completed Jobs (and their Pods) for debugging, then garbage-collects older ones.

**Real-world connection:** CronJobs are everywhere in production K8s: log rotation, certificate renewal, database backups, cache warming, report generation. The `concurrencyPolicy` is critical — for operations like backups, you never want two running simultaneously.

**Interview angle:** "How do you run periodic tasks in Kubernetes?" — CronJobs. Know the schedule format, concurrency policies, and history limits. Bonus: mention that CronJobs are eventually consistent — they might miss a trigger if the controller is down. For critical scheduled tasks, use `startingDeadlineSeconds` to set a window.

**Pro tip:** Use `kubectl create job --from=cronjob/<name>` to test a CronJob immediately without waiting for the schedule. This is invaluable during development.
