# Lesson 3: Postmortems

> **Sarah:** "Let me finally tell you about the Great Database Incident of 2024. It's not a war story — it's a lesson in what happens when you don't write things down."

---

## The Story Sarah Never Told

Six months before you joined NoCappuccino, Sarah was the on-call engineer when the production database ran out of connections. The API started timing out. Orders stopped processing. It took three hours to identify and fix.

She fixed it. She did not write a postmortem.

Three months later, the exact same thing happened. Same root cause. Same three-hour investigation. Same fix. Because she never documented what happened the first time, no one — including her — remembered the resolution.

"That was the day I learned: the postmortem isn't paperwork. It's how you make sure the same incident doesn't waste another three hours of someone's life at 2 AM."

---

## What a Postmortem Is

A postmortem is a structured document written **after** an incident is resolved. It captures:

1. **What happened** — a factual timeline
2. **Why it happened** — root cause analysis
3. **What we did** — mitigation and resolution steps
4. **What we'll do differently** — action items to prevent recurrence

A good postmortem transforms a bad experience into organizational knowledge.

---

## Blameless Postmortems

The most important principle: **postmortems are blameless.**

| Blameful (toxic) | Blameless (productive) |
|-----------------|----------------------|
| "Dave deployed without testing" | "The deployment pipeline did not include automated tests" |
| "Sarah should have caught the config error" | "The config change was not validated by a schema check" |
| "The on-call engineer was too slow to respond" | "The runbook for this alert was missing, increasing triage time" |

### Why Blameless?

1. **People hide information when they fear blame.** If Dave is afraid of punishment, he won't mention the deploy he did right before the incident — and you lose critical evidence.
2. **Humans don't cause incidents; systems do.** Dave deployed from his laptop because the pipeline allowed it. The system should have prevented it.
3. **Blame doesn't prevent recurrence.** Telling Dave "don't do that again" doesn't help. Adding a CI gate that prevents deploying untested code does.

---

## The Postmortem Template

### 1. Summary

One paragraph. What happened, when, how bad, how long.

```markdown
## Summary

On March 15, 2024, from 02:14 to 03:47 UTC (93 minutes), the NoCappuccino
checkout API experienced elevated error rates (peak: 34% of requests returning
HTTP 500). Approximately 2,400 checkout attempts failed during this window.
The root cause was a database connection pool exhaustion triggered by a new
database query introduced in v1.5.0, deployed at 02:00 UTC.
```

### 2. Impact

Quantify the damage.

```markdown
## Impact

- Duration: 93 minutes
- Users affected: ~1,200 unique users attempted checkout
- Failed requests: ~2,400 (34% error rate at peak)
- Revenue impact: estimated $4,200 in lost orders
- SLO impact: consumed 47% of monthly error budget in one incident
- No data loss
```

### 3. Timeline

A chronological list of events. Be precise. Include timestamps.

```markdown
## Timeline

All times UTC.

| Time | Event |
|------|-------|
| 02:00 | v1.5.0 deployed to production via CI pipeline |
| 02:14 | PagerDuty alert: error rate > 5% on checkout-api |
| 02:16 | On-call acknowledges alert, opens dashboard |
| 02:18 | Confirmed: 500 errors on POST /api/checkout, other endpoints normal |
| 02:22 | Checked pod status — all Running, no restarts |
| 02:25 | Checked database metrics — connection pool at 100% utilization |
| 02:28 | Identified: v1.5.0 added a new query with no connection timeout |
| 02:30 | Decision: rollback to v1.4.2 |
| 02:31 | Executed: helm rollback learn-api 3 |
| 02:33 | Rollback complete, new pods Running |
| 02:35 | Error rate dropping — 12% and falling |
| 02:40 | Error rate at 0.1% — normal levels |
| 02:45 | Confirmed: all health checks passing, dashboard green |
| 03:00 | Root cause confirmed: new recommendation query opened connections without closing them |
| 03:47 | Incident closed |
```

### 4. Root Cause Analysis

Explain what caused the incident. Use the **5 Whys** technique.

```markdown
## Root Cause

### 5 Whys

1. **Why did checkout fail?**
   The database connection pool was exhausted — no connections available.

2. **Why was the pool exhausted?**
   A new query in v1.5.0 was opening connections but not closing them properly.

3. **Why wasn't the connection leak caught in testing?**
   The test database has a much higher connection limit (100 vs 20 in production).
   The leak only manifested under production's more constrained pool.

4. **Why is the production connection limit lower?**
   It was set conservatively when the database was provisioned and never revisited.
   The application has grown but the pool size hasn't.

5. **Why wasn't the connection issue visible in staging?**
   Staging has 10% of production traffic. The leak rate was too slow to exhaust
   the pool during the staging validation window.

### Root cause
A database query in the recommendation engine (introduced in v1.5.0) opened
connections without a `defer conn.Close()`. Under production traffic, connections
leaked faster than the pool could reclaim them, leading to pool exhaustion and
500 errors on the checkout endpoint.
```

### 5. Contributing Factors

Things that didn't cause the incident but made it worse.

```markdown
## Contributing Factors

- Production database connection pool size (20) is significantly lower than
  staging (100), making production more sensitive to connection leaks
- No alerting on database connection pool utilization — the first alert was
  HTTP errors, not the underlying pool exhaustion
- The deployment happened at 02:00 UTC with no on-call awareness —
  deployments during low-traffic hours have less monitoring attention
```

### 6. Action Items

Specific, assigned, time-bound improvements. Each action item should prevent or detect this class of incident faster.

```markdown
## Action Items

| # | Action | Owner | Priority | Due |
|---|--------|-------|----------|-----|
| 1 | Fix connection leak in recommendation query | Dev team | P0 | March 16 |
| 2 | Add database connection pool utilization alert (>80%) | Platform team | P1 | March 22 |
| 3 | Increase production connection pool to 50 | DBA | P1 | March 18 |
| 4 | Add connection leak detection to CI test suite | Dev team | P2 | April 1 |
| 5 | Match staging and production connection pool configs | Platform team | P2 | April 1 |
| 6 | Add deployment freeze during low-traffic hours or require on-call awareness | Platform team | P3 | April 15 |
```

### 7. Lessons Learned

What went well, what didn't, and what was lucky.

```markdown
## Lessons Learned

### What went well
- Alert fired within 14 minutes of deployment
- Rollback was clean and fast (2 minutes)
- Error rate recovered within 10 minutes of rollback

### What didn't go well
- Root cause (connection pool) was not immediately obvious from HTTP error metrics
- No alert on the actual root cause (pool utilization) — we only saw the symptom
- Investigation took 12 minutes before rollback decision — should have rolled back sooner

### Where we got lucky
- The incident happened at 2 AM (low traffic). During peak hours, the pool would have
  exhausted in minutes instead of 14, and many more users would have been affected.
```

---

## Creating Runbooks

A runbook is a step-by-step guide for handling a specific type of incident. Good runbooks come from postmortems.

### Runbook Template

```markdown
# Runbook: Database Connection Pool Exhaustion

## Symptoms
- HTTP 500 errors on API endpoints
- "connection pool exhausted" in application logs
- Database connection count at or near limit

## Diagnosis
1. Check database connections: `kubectl exec -it <db-pod> -- psql -c "SELECT count(*) FROM pg_stat_activity;"`
2. Check application logs for "connection" errors: `kubectl logs -l app=api | grep -i connection`
3. Check when the last deployment happened: `kubectl rollout history deployment/api`

## Mitigation
1. If recent deployment: `kubectl rollout undo deployment/api`
2. If no recent deployment: restart application pods to release connections:
   `kubectl rollout restart deployment/api`
3. If database is overloaded: reduce replica count temporarily to reduce connection demand

## Escalation
- If connections don't decrease after restart: escalate to DBA
- If this recurs within a week: reopen the postmortem action items
```

---

## Postmortem Culture

A postmortem is not a punishment. It's a gift to the next person who gets paged at 2 AM.

**Conducting the postmortem meeting:**

1. Schedule within 48 hours of the incident (while memory is fresh)
2. Include everyone who participated in the response
3. Walk through the timeline together — correct misremembered details
4. Focus on systems and processes, not people
5. Generate action items with owners and due dates
6. Publish the postmortem where the whole engineering org can read it
7. Follow up on action items — an action item without follow-through is worse than no action item

---

> **Sarah:** "The Great Database Incident of 2024 happened twice because I didn't write a postmortem. The Great Database Incident of 2025 didn't happen because someone — a new hire — read the postmortem I finally wrote and caught the same pattern during code review. That's the point. You're not writing it for yourself. You're writing it for the person who hasn't been hired yet."

**Next:** [Challenge 01 — The 2 AM Page](../challenges/01-the-2am-page.md)
