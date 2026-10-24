```
   ____ _     _ ___
  / ___| |__ / ( _ )
 | |   | '_ \| / _ \
 | |___| | | | | (_) |
  \____|_| |_|_|\___/

  ___            _     _            _
 |_ _|_ __   ___(_) __| | ___ _ __ | |_
  | || '_ \ / __| |/ _` |/ _ \ '_ \| __|
  | || | | | (__| | (_| |  __/ | | | |_
 |___|_| |_|\___|_|\__,_|\___|_| |_|\__|

  ____                                      
 |  _ \ ___  ___ _ __   ___  _ __  ___  ___ 
 | |_) / _ \/ __| '_ \ / _ \| '_ \/ __|/ _ \
 |  _ <  __/\__ \ |_) | (_) | | | \__ \  __/
 |_| \_\___||___/ .__/ \___/|_| |_|___/\___|
                |_|                          

  🚨 "The On-Call Shift"

     ┌────────────────────────────────────────────┐
     │                                            │
     │   02:14 AM — PAGER                         │
     │                                            │
     │   🔴 CRITICAL: Error rate > 5%             │
     │   🔴 CRITICAL: p99 latency > 10s           │
     │   🟡 WARNING: Pod restarts > 5 in 10m      │
     │                                            │
     │   On-call: You                             │
     │   Incident commander: You                  │
     │   Backup: Sarah (sleeping)                 │
     │                                            │
     │   Time to acknowledge: ...                 │
     │                                            │
     └────────────────────────────────────────────┘

     (•_•) Sarah: "The pager doesn't care that it's 2 AM.
                    But YOU care about having a process."
```

# Chapter 18: The On-Call Shift — Incident Response

## The Story

It's your first on-call rotation. Sarah walked you through the process, showed you the runbooks, and said "you've got the skills — you've done observability, you've done delivery pipelines, you've triaged broken clusters before."

Then she went home.

At 2:14 AM, the pager goes off. Error rate spiking. Latency through the roof. Pods restarting. Multiple alerts firing simultaneously.

This time is different from Chapter 7's "Great Latte Leak." Back then, you were reacting to broken manifests. Now you have real observability, real deployment pipelines, and a structured approach to incidents.

The question isn't whether you can fix it. The question is: can you fix it *professionally?* — with triage, communication, mitigation, root cause analysis, and a blameless postmortem.

---

## What You'll Learn

By the end of this chapter, you will be able to:

- Triage incidents using a structured methodology (impact, scope, urgency, blast radius)
- Distinguish between mitigation (stop the bleeding) and root cause (fix the disease)
- Use rollback, scaling, circuit breakers, and feature flags as mitigation strategies
- Communicate effectively during an incident (status updates, escalation, handoffs)
- Write a blameless postmortem with timeline, root cause, and actionable follow-ups
- Create runbooks that help the next on-call engineer

---

## Prerequisites

- Chapter 16 (Observability) recommended — you'll reference metrics and dashboards
- kind cluster running with `kubectl` configured
- Namespace `learn-ch18` will be created during challenges
- Familiarity with Deployments, Services, and basic troubleshooting

---

## Estimated Time

- Lessons: ~60 minutes
- Challenges: ~2–3 hours
- Quiz: ~15 minutes
- Total: ~4–5 hours

---

## Lessons

| # | Lesson | What You'll Learn |
|---|--------|-------------------|
| 01 | [Triage](lessons/01-triage.md) | Severity levels, impact assessment, blast radius, communication |
| 02 | [Mitigation vs Root Cause](lessons/02-mitigation-vs-root-cause.md) | Stop the bleeding first, then investigate. Rollback, scaling, circuit breakers. |
| 03 | [Postmortems](lessons/03-postmortems.md) | Blameless postmortems, timelines, 5 whys, action items, runbooks |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [The 2 AM Page](challenges/01-the-2am-page.md) | Full incident simulation: triage, mitigate, investigate, resolve |
| 02 | [Cascading Failure](challenges/02-cascading-failure.md) | Stop a cascade: one failure spreads to three services |
| 03 | [Write the Postmortem](challenges/03-write-the-postmortem.md) | Document what happened with a structured, blameless postmortem |

To verify your work: `bash curriculum/world-5-platform-engineering/ch18-incident-response/challenges/verify.sh`

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Incident** | An unplanned event that degrades service quality and requires immediate response |
| **Severity** | Classification of incident impact (SEV1 = critical, SEV4 = minor) |
| **Triage** | Rapid assessment of impact, scope, and urgency to prioritize response |
| **Blast radius** | How much of the system is affected by the incident |
| **Mitigation** | Immediate action to stop or reduce user impact (not necessarily the fix) |
| **Root cause** | The underlying reason the incident occurred |
| **Rollback** | Reverting to a previous known-good state as mitigation |
| **Circuit breaker** | A pattern that stops calling a failing service to prevent cascade |
| **Graceful degradation** | Serving a reduced but functional experience when a dependency fails |
| **Incident commander** | The person coordinating the response (decisions, communication, delegation) |
| **Postmortem** | A structured review of the incident after resolution |
| **Blameless** | Focusing on system failures and process gaps, not individual fault |
| **Runbook** | A step-by-step guide for responding to a specific type of incident |
| **5 Whys** | A root cause analysis technique: ask "why?" iteratively until the systemic cause is found |

---

> **Sarah:** "Every engineer freezes the first time the pager goes off at 2 AM. That's normal. What separates professionals from panickers is having a process. You follow the process, and the process handles the chaos for you."

**Next:** Start with [Lesson 01 — Triage](lessons/01-triage.md)
