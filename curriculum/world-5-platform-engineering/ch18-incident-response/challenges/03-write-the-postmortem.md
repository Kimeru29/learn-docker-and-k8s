# Challenge 3: Write the Postmortem

> **Sarah:** "The incidents are resolved. The dashboard is green. Now comes the part most people skip — and the part that matters most."

---

## The Situation

You've handled two incidents in this chapter:

1. **The 2 AM Page** — Bad image tag on the API, OOMKilled worker
2. **The Cascading Failure** — Database failure cascading to API and frontend

Now write a structured, blameless postmortem for one of them (or combine both into a single postmortem if they were related to the same deploy cycle).

---

## Your Mission

Create a postmortem as a ConfigMap in the `learn-ch18` namespace. The postmortem should follow the structure from Lesson 03.

### Required Sections

Your postmortem must include:

1. **Summary** — What happened, in one paragraph
2. **Severity** — SEV level with justification
3. **Impact** — Quantified (duration, services affected, blast radius)
4. **Timeline** — Key events with timestamps (simulated times are fine)
5. **Root Cause** — Use the 5 Whys technique
6. **Contributing Factors** — What made it worse
7. **Action Items** — At least 3 specific, actionable improvements
8. **Lessons Learned** — What went well, what didn't

### Create the Postmortem ConfigMap

```bash
kubectl create configmap learn-postmortem \
  --from-literal=summary="On [date], from 02:14 to 02:45 UTC (31 minutes), NoCappuccino experienced a multi-service outage. The learn-api Deployment had a broken image tag (nginx:1.25-nonexistent) causing ImagePullBackOff, and learn-worker had insufficient memory limits causing OOMKilled restarts. Both issues were introduced by the v1.5.0 deployment at 02:00 UTC. Resolution: rolled back API image to nginx:1.25-alpine and increased worker memory limits." \
  --from-literal=severity="SEV2 - Multiple services affected, clear rollback path available" \
  --from-literal=impact="Duration: 31 minutes. Services affected: learn-api (complete outage), learn-worker (unstable/restarting). Blast radius: API and background worker. Frontend would show errors to all users attempting checkout or recommendations." \
  --from-literal=timeline="02:00 - v1.5.0 deployed via CI pipeline. 02:14 - Alerts fire: error rate >5%, pod restarts >5. 02:16 - On-call acknowledges, checks dashboard. 02:20 - Identified: API in ImagePullBackOff (bad image tag), Worker OOMKilled (memory too low). 02:25 - Rolled back API image to nginx:1.25-alpine. 02:28 - Increased worker memory limits to 128Mi. 02:35 - All pods Running, alerts resolved. 02:45 - Incident closed." \
  --from-literal=root_cause="5 Whys: (1) Why did API fail? ImagePullBackOff - image nginx:1.25-nonexistent does not exist. (2) Why was a nonexistent image deployed? The v1.5.0 CI pipeline used an incorrect image tag. (3) Why wasn't the bad tag caught? No image validation step in the pipeline before deployment. (4) Why did worker OOMKill? Memory limit of 6Mi is below nginx minimum. (5) Why was the limit so low? The concurrency increase in v1.5.0 changed memory requirements but limits were not updated." \
  --from-literal=contributing_factors="1. No pre-deployment image pull validation in CI pipeline. 2. No staging environment smoke test that would catch ImagePullBackOff before production. 3. Worker memory limits not reviewed when concurrency was changed. 4. Deployment at 02:00 UTC had minimal monitoring attention." \
  --from-literal=action_items="1. [P0] Add image existence validation to CI pipeline before deploy (Owner: Platform, Due: 1 week). 2. [P1] Add staging smoke test that verifies all pods reach Running state (Owner: Platform, Due: 2 weeks). 3. [P1] Require resource limit review when application configuration changes (Owner: Dev leads, Due: 2 weeks). 4. [P2] Add deployment notification to on-call channel (Owner: Platform, Due: 3 weeks). 5. [P3] Evaluate deployment windows - consider avoiding off-hours deploys without explicit on-call awareness (Owner: Engineering Manager, Due: 1 month)." \
  --from-literal=lessons_learned="What went well: Alert fired within 14 minutes. Rollback process was fast (under 10 minutes total). On-call followed triage process. What went poorly: Investigation took longer than needed - should have checked deployment history first. No pre-deploy validation caught the bad image. Resource limits were not reviewed with the code change. Where we got lucky: Low-traffic hours meant fewer users were affected." \
  --from-literal=blameless="true" \
  -n learn-ch18
```

---

## Evaluation Criteria

The AI (or verify script) evaluates your postmortem on:

### 1. Timeline Completeness
- [ ] Includes deployment time
- [ ] Includes alert time
- [ ] Includes diagnosis time
- [ ] Includes mitigation actions with times
- [ ] Includes resolution time

### 2. Root Cause Accuracy
- [ ] Correctly identifies the broken image tag
- [ ] Correctly identifies the insufficient memory limits
- [ ] Links both to the v1.5.0 deployment
- [ ] Uses 5 Whys or similar structured analysis

### 3. Quality of Action Items
- [ ] Action items are specific (not vague like "improve testing")
- [ ] Each has an owner
- [ ] Each has a priority
- [ ] Each has a due date
- [ ] At least one prevents this exact incident from recurring
- [ ] At least one improves detection speed

### 4. Blame-Free Language
- [ ] No individual names blamed
- [ ] Focuses on system/process failures
- [ ] Uses passive or system-focused language
- [ ] Acknowledges what went well, not just what failed

---

## Hints

<details>
<summary>Hint 1: What makes a good timeline?</summary>

A good timeline reads like a narrative:

```
02:00 — Deployment event (what changed)
02:14 — Alert fires (first symptom detected)
02:16 — On-call acknowledges (response starts)
02:20 — Diagnosis complete (problem identified)
02:25 — First mitigation applied (API rollback)
02:28 — Second mitigation applied (worker memory)
02:35 — All pods healthy (mitigation verified)
02:45 — Incident closed (all clear)
```

Include what you LEARNED at each step, not just what you DID.

</details>

<details>
<summary>Hint 2: What makes a good action item?</summary>

Bad: "Test better before deploying"
Good: "Add image pull validation to CI pipeline that verifies the image exists in the registry before deploying. Owner: Platform team. Priority: P0. Due: March 22."

Bad: "Fix the memory limits"
Good: "Require resource limit review in PR template when application configuration changes. Add a CI check that validates resource limits are set above minimum thresholds. Owner: Dev leads. Priority: P1. Due: April 1."

</details>

<details>
<summary>Hint 3: 5 Whys technique</summary>

Start with the symptom and keep asking "Why?":

1. Why did the API fail? → Bad image tag
2. Why was a bad tag deployed? → CI pipeline didn't validate
3. Why didn't CI validate? → No image pull check exists
4. Why not? → It was never built — we assumed images were correct
5. Why assume? → No one considered this failure mode

The root cause isn't "bad image tag" — it's "no validation in the pipeline." The fix addresses the system, not the symptom.

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch18-incident-response/challenges/verify.sh
```

---

## Reflection

Writing a postmortem is a skill. The first time feels awkward. By the tenth time, it's automatic.

The postmortem you just wrote will:
- Help the next on-call engineer who sees a similar alert
- Generate action items that prevent recurrence
- Create a culture where incidents are learning opportunities, not punishment

Sarah was right: the Great Database Incident of 2024 happened twice because nobody wrote it down. Your postmortem makes sure this incident only happens once.

---

> **Sarah:** "Read it one more time. Check for blame. Check for vague action items. Check that the timeline makes sense. Then share it with the team. The postmortem isn't done until someone who wasn't in the incident can read it and understand exactly what happened and what to do if it happens again."

**Next:** Take the [Chapter 18 Quiz](../quiz.md)
