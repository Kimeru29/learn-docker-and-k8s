# Lesson 2: Mitigation vs Root Cause

> **Sarah:** "When the house is on fire, you don't investigate the electrical wiring. You get people out and call the fire department. Then — after the fire is out — you figure out what caused it."

---

## The Two Phases of Incident Response

```
  Phase 1: MITIGATE              Phase 2: INVESTIGATE
  ────────────────────           ────────────────────────
  Stop the bleeding              Find the root cause
  Reduce user impact             Understand what happened
  Restore service ASAP           Prevent recurrence
  Speed over perfection          Thoroughness over speed

  "Make it work now"             "Make sure it doesn't happen again"
```

**Never skip Phase 1 to do Phase 2.** Investigating root cause while users are still impacted is a mistake. Get the system working first, even if the solution is ugly.

---

## Mitigation Strategies

### 1. Rollback

The fastest mitigation for a bad deployment.

```bash
# Kubernetes Deployment rollback
kubectl rollout undo deployment/learn-api -n learn-ch18

# Helm rollback
helm rollback learn-api 1 -n learn-ch18

# GitOps rollback
git revert <bad-commit> && git push
# Controller syncs the reverted state
```

**When to use:** Something changed recently (new deploy, config change) and the incident correlates with that change.

**When NOT to use:** The system was running fine for weeks with no changes — the problem is probably load, dependency, or data-related, not deployment-related.

### 2. Scale Up

If the system is overwhelmed by traffic:

```bash
# Manually scale
kubectl scale deployment/learn-api --replicas=10 -n learn-ch18

# Or let HPA handle it (if configured)
kubectl get hpa -n learn-ch18
```

**When to use:** CPU/memory saturation. Request queue building up. Load-related latency increase.

**When NOT to use:** The application is erroring, not slow. More replicas of a broken app just make more errors.

### 3. Feature Flags

Disable a broken feature without rolling back the entire deployment:

```yaml
# ConfigMap update
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  FEATURE_RECOMMENDATIONS: "false"   # Disable the broken feature
  FEATURE_CHECKOUT: "true"           # Keep working features
```

**When to use:** The incident is caused by a specific feature, and disabling it restores the rest of the system.

**When NOT to use:** You don't have feature flags implemented. (Note: this is an argument for always having them.)

### 4. Circuit Breaker

Stop calling a failing downstream service to prevent cascade:

```
  Without circuit breaker:       With circuit breaker:
  ┌─────┐     ┌─────┐           ┌─────┐     ┌─────┐
  │ API │────→│ DB  │           │ API │──X──│ DB  │
  │     │ ←── │ 💥  │           │     │     │ 💥  │
  │ 💥  │  timeout  │           │ ⚡  │     │     │
  └─────┘     └─────┘           └─────┘     └─────┘
  API hangs waiting              API returns cached/default
  for broken DB                  response immediately
```

**When to use:** A dependency is failing, and your service is timing out waiting for it, causing your own latency to spike.

**When NOT to use:** The problem IS your service, not a dependency.

### 5. Graceful Degradation

Serve a reduced experience instead of failing completely:

- Return cached recommendations instead of live ones
- Show "temporarily unavailable" for non-critical features
- Serve a static page if the entire backend is down
- Disable non-essential middleware (analytics, tracking)

**When to use:** A dependency is down but the core experience can still function.

---

## The Decision Tree

```
  Incident starts
       │
       ▼
  Was there a recent change?
       │
  YES──┼──NO
       │      │
       ▼      ▼
  Rollback   Is it load-related?
       │      │
       │  YES──┼──NO
       │      │      │
       │      ▼      ▼
       │  Scale up   Is it a specific feature?
       │      │      │
       │      │  YES──┼──NO
       │      │      │      │
       │      │      ▼      ▼
       │      │  Feature   Is a dependency failing?
       │      │  flag off  │
       │      │      │  YES──┼──NO
       │      │      │      │      │
       │      │      │      ▼      ▼
       │      │      │  Circuit   Graceful
       │      │      │  breaker   degradation
       │      │      │      │      │
       └──────┴──────┴──────┴──────┘
                     │
                     ▼
              Service restored?
              │
          YES─┤
              │
              ▼
         Phase 2: Root cause investigation
```

---

## Rollback as Default Mitigation

When in doubt, **roll back.** It's the safest, fastest mitigation for deployment-related incidents.

```bash
# Check when the last deployment happened
kubectl rollout history deployment/learn-api -n learn-ch18

# If the incident correlates with a recent deploy, roll back
kubectl rollout undo deployment/learn-api -n learn-ch18

# Verify rollback
kubectl rollout status deployment/learn-api -n learn-ch18
kubectl get pods -n learn-ch18
```

The rollback doesn't fix the root cause. The new version still has a bug. But users are no longer impacted, which buys you time to investigate without pressure.

### When to Scale vs When to Roll Back

| Symptom | Likely mitigation |
|---------|------------------|
| Latency up, errors normal, CPU high | **Scale** — more capacity needed |
| Errors spiking after a deploy | **Rollback** — the new version is broken |
| One endpoint broken, others fine | **Feature flag** — disable the broken endpoint |
| Dependency timing out, your service hanging | **Circuit breaker** — stop waiting for the dependency |
| Everything slow, nothing specific | **Investigate** — check metrics, logs, traces before acting |

---

## Investigation After Mitigation

Once the system is stable, you can take your time investigating:

1. **Timeline:** What changed? When did metrics shift? What was deployed?
2. **Correlation:** Does the incident timing match a deployment, a traffic spike, a dependency change?
3. **Logs:** What do the error logs say? What was the first error?
4. **Traces:** If available, which span is failing? What's the error?
5. **Metrics:** What metric changed first? (Error rate? Latency? Pod restarts?)

The root cause investigation happens in Phase 2 — after users are no longer impacted. This is where observability (Chapter 16) pays off.

---

## Common Mistakes During Incidents

| Mistake | Why it's bad | What to do instead |
|---------|-------------|-------------------|
| Investigating root cause while users are impacted | Users suffer longer | Mitigate first |
| Making changes without telling anyone | Others can't help or coordinate | Communicate every action |
| Making multiple changes simultaneously | You can't tell which one helped | One change at a time, verify after each |
| Not rolling back because "the fix is almost ready" | "Almost" can mean hours | Roll back now, fix later |
| Blaming someone in the incident channel | Shuts down collaboration | Focus on what happened, not who |

---

> **Sarah:** "I once spent 40 minutes trying to find the root cause of a memory leak during an active incident. Customers were seeing 500 errors the entire time. When I finally rolled back, the error rate dropped to zero in 30 seconds. Forty minutes of user impact because I was too proud to rollback. Never again. Mitigate first. Always."

**Next:** [Lesson 03 — Postmortems](03-postmortems.md)
