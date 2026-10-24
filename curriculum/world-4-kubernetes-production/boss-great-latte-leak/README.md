```
  _____ _            ___                _     _         _   _         _               _
 |_   _| |_  ___   / __|_ _ ___ __ _| |_  | |   __ _| |_| |_ ___  | |   ___ __ _| | __
   | | | ' \/ -_) | (_ | '_/ -_) _` |  _| | |__/ _` |  _|  _/ -_) | |__/ -_) _` | |/ /
   |_| |_||_\___|  \___|_| \___\__,_|\__| |____\__,_|\__|\__\___| |____\___\__,_|_|\_\

    🔥 THE FINALE RETURNS — EXPANDED 🔥

    .------------------------------------------------------.
    |  INCIDENT REPORT — 06:12 AM                           |
    |                                                       |
    |  [!!] API: ImagePullBackOff (typo in image tag)       |
    |  [!!] Worker: OOMKilled repeatedly (no memory limit)  |
    |  [!!] DB creds visible in pod logs (env vars)         |
    |  [!!] Readiness probe misconfigured (false healthy)   |
    |  [!!] ServiceAccount has cluster-admin (security)     |
    |                                                       |
    |  Dave: on a flight (unreachable)                      |
    |  Marcus: panicking (as usual)                         |
    |  Sarah: "Five fires. Same playbook. Let's go."        |
    '------------------------------------------------------'

    ✈️  Dave is unreachable.  😱 Marcus is panicking.  💪 You've got this.
```

# Boss Fight: The Great Latte Leak — The Finale Returns

## The Story

It's 6:12 AM. Your phone wakes you up. Not the gentle notification kind — the sustained, every-few-seconds kind that means something is genuinely wrong.

You open Slack. Fifty-three unread messages. The incident channel is on fire.

**6:07 AM — Monitoring:** `api` deployment unhealthy. Pod count 0/3 Running.

**6:08 AM — Monitoring:** `worker` deployment pod restarting. OOMKilled. Restart count: 7.

**6:09 AM — Security Alert:** Database credentials detected in pod log output. Severity: CRITICAL.

**6:10 AM — Monitoring:** `order-service` returning 503 to all requests. Readiness probe passing but app returning errors.

**6:11 AM — Security Alert:** ServiceAccount `deploy-bot` has `cluster-admin` binding. Severity: CRITICAL.

**6:12 AM — @dave:** "hey just boarded, 11hr flight to tokyo, no wifi on this one. you got this. trust the training."

**6:12 AM — @dave:** "also why is pagerduty going off"

**6:13 AM — @dave:** "nvm boarding gotta go"

**6:15 AM — @marcus:** "the investors demo is at 9 AM. please tell me the API is working."

**6:15 AM — @marcus:** "???"

Sarah is already at her desk. Coffee in hand. Calm.

"Five things are broken," she says. "Dave is over the Pacific. Marcus is going to start escalating in about forty minutes. The morning rush starts at seven."

She takes a sip.

"But here's the thing: you trained for this. Chapters 13, 14, and 15 — health probes, resource management, and security. Every one of these five problems maps to something you already know how to fix. The only difference is they're all happening at the same time."

"Triage first. Don't try to fix everything at once. Find the most critical issue, fix it, verify it, move to the next one."

---

## What You'll Face

Five simultaneous production failures. You are NOT told which component has which problem. You must investigate, diagnose, and fix each one.

| # | Failure | Category |
|---|---------|----------|
| 1 | A deployment is stuck in ImagePullBackOff | Image/Config |
| 2 | A pod keeps getting OOMKilled | Resources |
| 3 | Database credentials are visible in pod logs | Security/Secrets |
| 4 | A service receives traffic but the app returns errors | Health/Probes |
| 5 | A ServiceAccount has cluster-admin access | Security/RBAC |

---

## Prerequisites

- Chapters 13, 14, and 15 completed
- `learn-k8s` kind cluster running
- All the skills from World 4

---

## Estimated Time

- Triage and fix: ~2–3 hours
- This is the World 4 capstone — give it the time it deserves

---

## The Challenge

**[Begin the Boss Fight →](challenges/01-great-latte-leak.md)**

---

> **Sarah:** "Five fires. One playbook: investigate, diagnose, fix, verify. You've done harder things than this — just never all at once. Welcome to production."
