# Lesson 1: Triage

> **Sarah:** "The pager goes off. Your heart rate spikes. You have a choice: panic and start changing random things, or follow a process. The process always wins."

---

## The First 5 Minutes

When an incident starts, the most important thing is NOT to immediately start fixing. It's to **understand what's happening.**

```
  PAGER FIRES
       │
       ▼
  1. Acknowledge        (I'm on it — 30 seconds)
       │
       ▼
  2. Assess impact      (What's broken? Who's affected? — 2 minutes)
       │
       ▼
  3. Classify severity  (SEV1? SEV2? SEV3? — 30 seconds)
       │
       ▼
  4. Communicate        (Tell stakeholders what you know — 1 minute)
       │
       ▼
  5. Start mitigation   (Stop the bleeding — time varies)
```

Resist the urge to skip to step 5. If you start fixing before understanding, you might:
- Fix the wrong thing
- Make it worse
- Miss the actual blast radius
- Waste time on a symptom while the root cause spreads

---

## Severity Levels

Every organization defines severity slightly differently, but the core tiers are:

| Severity | Impact | Response | Example |
|----------|--------|----------|---------|
| **SEV1 / Critical** | Major user-facing outage. Revenue impact. | Page immediately. All hands. Drop everything. | Checkout is down. No orders processing. |
| **SEV2 / High** | Significant degradation. Many users affected. | Page on-call. Escalate within 15 minutes if no progress. | API latency 10x normal. 30% of requests failing. |
| **SEV3 / Medium** | Partial degradation. Some users affected. | Investigate during business hours. | One region's CDN is slow. Admin dashboard is down. |
| **SEV4 / Low** | Minor issue. Minimal user impact. | Track and fix in normal sprint. | Log formatting broken. Non-critical cron job failed. |

### How to Classify

Ask three questions:

1. **Impact:** What is the user experience right now?
   - Complete outage vs. degraded performance vs. cosmetic issue

2. **Scope:** How many users are affected?
   - All users vs. one region vs. one customer vs. internal only

3. **Urgency:** Is it getting worse?
   - Spreading vs. stable vs. self-resolving

---

## Blast Radius Assessment

**Blast radius** = how much of the system is affected by this incident.

```
  Blast radius: SMALL           Blast radius: LARGE
  ┌───────────────────┐         ┌───────────────────┐
  │ ┌───┐ ┌───┐ ┌───┐│         │ ┌───┐ ┌───┐ ┌───┐│
  │ │ ✓ │ │ ✗ │ │ ✓ ││         │ │ ✗ │ │ ✗ │ │ ✗ ││
  │ │API│ │Wrk│ │Web││         │ │API│ │Wrk│ │Web││
  │ └───┘ └───┘ └───┘│         │ └───┘ └───┘ └───┘│
  │                   │         │                   │
  │ One service down  │         │ Everything down   │
  │ Others functional │         │ Cascading failure  │
  └───────────────────┘         └───────────────────┘
```

To assess blast radius:

```bash
# Check all pods in the namespace
kubectl get pods -n learn-ch18 -o wide

# Check all services
kubectl get svc -n learn-ch18

# Check recent events (K8s events often show the spread)
kubectl get events -n learn-ch18 --sort-by='.lastTimestamp' | tail -20

# Check metrics (if Prometheus is available)
# Error rate across all services
# Pod restart counts
# Memory/CPU across namespace
```

Blast radius determines severity. One non-critical pod restarting is SEV3. The entire API layer being unreachable is SEV1.

---

## Communication During Incidents

Bad communication during incidents causes more damage than the incident itself.

### The Status Update Template

Post updates every 15 minutes during a SEV1/SEV2, even if nothing has changed:

```
INCIDENT UPDATE — 02:32 AM
Status: Investigating
Impact: Checkout API returning 500 errors for ~30% of requests
Blast radius: checkout-api and payment-service affected, other services healthy
Current action: Examining recent deployment (v1.5.0 rolled out at 02:00 AM)
Next update: 02:47 AM
```

### Rules for Incident Communication

1. **State facts, not speculation.** "Error rate is 30%" not "I think the database might be down."
2. **Update regularly.** Silence is worse than "still investigating."
3. **Say what you're doing next.** "Checking deployment history" gives stakeholders confidence.
4. **Escalate early.** If you're stuck after 15 minutes, call for help. Nobody will judge you.
5. **Don't blame.** "A recent deployment introduced a regression" not "Dave's bad code broke production."

---

## The Incident Commander Role

In larger incidents, one person is the **incident commander (IC)**. The IC does NOT fix the problem — they coordinate:

| IC Responsibility | NOT the IC's job |
|------------------|-----------------|
| Assign tasks ("Alice, check the database. Bob, check the API.") | Debugging the code |
| Maintain the timeline | Writing the fix |
| Post status updates | Running kubectl commands |
| Decide when to escalate | Being the expert on every system |
| Call the "all clear" | Knowing the root cause |

For smaller incidents (and at 2 AM when you're the only one awake), you're both the IC and the responder. The process still applies — just faster.

---

## Who to Notify

| Severity | Notify |
|----------|--------|
| SEV1 | On-call team, engineering manager, customer support, exec stakeholders |
| SEV2 | On-call team, engineering manager |
| SEV3 | On-call team, file a ticket |
| SEV4 | File a ticket |

Don't wake people up for a SEV3. Do wake people up for a SEV1 — they'll be glad you did when they see the customer impact.

---

## Triage Checklist

Use this checklist when the pager fires:

```
□ Acknowledge the alert
□ Open the dashboard — what do metrics show?
□ Check pod status: kubectl get pods -n <namespace>
□ Check recent events: kubectl get events -n <namespace> --sort-by='.lastTimestamp'
□ Check recent deployments: kubectl rollout history deployment/<name> -n <namespace>
□ Assess: Impact? Scope? Urgency? Blast radius?
□ Classify severity (SEV1/2/3/4)
□ Post initial status update
□ Begin mitigation
```

---

## Practical Triage Commands

```bash
# What's the state of all pods?
kubectl get pods -n learn-ch18 -o wide

# Which pods are NOT Running?
kubectl get pods -n learn-ch18 --field-selector=status.phase!=Running

# Recent events (errors, warnings)
kubectl get events -n learn-ch18 --sort-by='.lastTimestamp' --field-selector type=Warning

# Pod details (look for Last State, Exit Code, Events)
kubectl describe pod <pod-name> -n learn-ch18

# Recent logs
kubectl logs <pod-name> -n learn-ch18 --tail=50

# Previous container logs (for CrashLoopBackOff)
kubectl logs <pod-name> -n learn-ch18 --previous

# Check deployment rollout status
kubectl rollout status deployment/<name> -n learn-ch18

# Check deployment history
kubectl rollout history deployment/<name> -n learn-ch18

# Resource usage
kubectl top pods -n learn-ch18
```

---

> **Sarah:** "The hardest part of triage isn't technical. It's emotional. At 2 AM, your brain wants to panic and start typing random kubectl commands. The checklist is your friend. Follow it, and the chaos becomes a list of questions with answers."

**Next:** [Lesson 02 — Mitigation vs Root Cause](02-mitigation-vs-root-cause.md)
