```
  ____   ___  ____ ____    _____ ___ ____ _   _ _____
 | __ ) / _ \/ ___/ ___|  |  ___|_ _/ ___| | | |_   _|
 |  _ \| | | \___ \___ \  | |_   | | |  _| |_| | | |
 | |_) | |_| |___) |__) | |  _|  | | |_| |  _  | | |
 |____/ \___/|____/____/  |_|   |___\____|_| |_| |_|

 💥 "The Full Stack Meltdown"

    ┌──────────────────────────────────────────────────┐
    │                                                  │
    │   12:47 PM — Everything was fine.                │
    │                                                  │
    │   12:48 PM — Coffee influencer posts about us.   │
    │                                                  │
    │   12:49 PM — Traffic spike begins.               │
    │                                                  │
    │   12:52 PM — API takes 10 seconds to stop.       │
    │   12:53 PM — Worker OOMKilled.                   │
    │   12:54 PM — DB credentials in docker history.   │
    │   12:55 PM — Frontend image is 3 GB.             │
    │   12:57 PM — Services can't communicate.         │
    │                                                  │
    │   12:58 PM — Dave: "WHAT IS HAPPENING"           │
    │                                                  │
    │   (•‿•) Sarah: "You've trained for this.         │
    │          Triage. Fix. Verify. One at a time."     │
    │                                                  │
    └──────────────────────────────────────────────────┘
```

# Boss Fight: The Full Stack Meltdown

> "Five problems. All happening at once. Dave is pinging every 30 seconds. Marcus is live-tweeting the outage. The coffee influencer's followers are trying to sign up and getting errors. This is your moment."
> — Sarah, calm as always

---

## The Story

The coffee influencer is back. Two million followers. She just posted about NoCappuccino's new cold brew subscription. Within minutes, traffic spikes 20x.

The stack was already fragile. Now it's broken across multiple dimensions simultaneously. Five independent problems, all surfacing at once because of the load spike.

Sarah has seen this before. She knows the drill: **triage, fix, verify**. Don't panic. Don't try to fix everything at once. Pick the most impactful problem, fix it, verify it works, move to the next one.

"This is what World 2 was about," she says. "Compose, process management, debugging, security. You're going to need all of it."

---

## The Five Failures

| # | Problem | Chapter | Symptom |
|---|---------|---------|---------|
| 1 | The API crashes on restart — shell form | Ch06 | `docker stop` takes 10 seconds, deploys are slow |
| 2 | The worker service has a memory leak | Ch07 | Worker gets OOMKilled (exit 137) repeatedly |
| 3 | Database credentials in image history | Ch08 | `docker history` shows the password in plain text |
| 4 | The frontend image is 3 GB | Ch02/Ch08 | Pulls take forever, disk is filling up |
| 5 | Services can't communicate | Ch04/Ch05 | Backend can't reach Postgres — network misconfiguration |

Each problem is independent. You can fix them in any order. But some are more impactful than others — triage wisely.

---

## Rules of Engagement

1. **No step-by-step instructions.** You've trained for this. Use your skills.
2. **Triage first.** Decide which problem to fix first and why.
3. **Fix one thing at a time.** Verify each fix before moving to the next.
4. **Multiple valid solutions.** The verification script checks outcomes, not exact implementations.
5. **Ask for hints if stuck.** Progressive hints are available — but try on your own first.

---

## Getting Started

The challenge files and broken Compose stack are in:

```
challenges/01-full-stack-meltdown.md
```

Read the challenge, understand the setup, then start triaging.

---

## After the Boss Fight

When `verify.sh` passes with all checks green:

**What you did:** Triaged and fixed five simultaneous production failures spanning Compose, process management, troubleshooting, and security — the full breadth of World 2.

**Why it matters:** Production incidents rarely have one clean problem. They cascade. The skill isn't just knowing the fix — it's knowing the order: what to fix first, how to verify each step, and how to stay calm when everything is on fire.

**Real-world connection:** This is a typical "incident response" scenario at any company running containers. The person who can systematically triage, fix, and verify — while everyone else is panicking — is the person who earns the team's trust.

**What's next:** You've mastered Docker. You can build images, compose services, manage processes, debug failures, and secure everything. But NoCappuccino has outgrown a single machine. The influencer's traffic spike proved it.

Time for Kubernetes.

*World 3: Kubernetes Core — begins.*
