```
  ___ _    ___ ___
 / __| |_ / _ \__  |
| (__| ' \ (_) |/ /
 \___|_||_\___//_/

 🔍 "The Debugging Grind"

    3:17 AM — PagerDuty alert

    $ docker ps
    learn-api-1    Restarting (137)   ← WHY?

    Step 1: docker logs        → nothing useful
    Step 2: docker inspect     → OOMKilled: true
    Step 3: docker stats       → 512M / 512M memory
    Step 4: fix the leak       → 💡
    Step 5: verify             → ✅

    (•‿•) Sarah: "This is the workflow. Memorize it."
```

# Chapter 7: The Debugging Grind

> "It's Monday. A container keeps restarting and nobody knows why. The logs say nothing useful. The junior dev has been staring at it for 30 minutes. Time to teach you the workflow I use at 3 AM."
> — Sarah

## The Story So Far

The containers are clean now. SIGTERM works, no more zombies, ENTRYPOINT and CMD play nice. Dave is talking about promoting you. Marcus is cautiously optimistic.

Then, on Monday morning, chaos:

- A junior developer's API container keeps restarting. It was working on Friday. They don't know what changed.
- The staging backend is "slow" but nobody can quantify it. Marcus just says "it feels sluggish."
- A deployment went out but the changes aren't appearing. The developer swears they pushed the new code.

You look at Sarah. She doesn't look worried. She looks... calm. She pulls up a chair and opens her terminal.

"Every production incident is the same," she says. "Not the symptoms — those are always different. The *process* is always the same. Let me show you the workflow I use at 3 AM, when I'm half-asleep and everything is on fire."

---

## What You'll Learn

This chapter is about developing a systematic debugging methodology for containers. Not just the commands — the *thinking pattern* behind them. The goal is that when something breaks, you have a repeatable process that works whether it's a simple config error or a subtle resource leak.

---

## Chapter Objectives

By the end of this chapter, you will be able to:

1. Follow a repeatable 6-step debugging methodology for any container problem
2. Interpret exit codes and understand what they mean (0, 1, 127, 137, 143)
3. Diagnose OOMKilled containers and restart loops
4. Use `docker stats`, `docker top`, `docker diff`, `docker history`, and `docker system df` for advanced inspection
5. Debug containers that crash silently, leak memory, lose network connectivity, or serve stale code
6. Build a mental toolkit for 3 AM incidents

---

## Lessons

| # | Lesson | Concepts |
|---|--------|----------|
| 01 | [The Diagnostic Workflow](lessons/01-the-diagnostic-workflow.md) | The 6-step debugging ladder — a repeatable methodology |
| 02 | [Exit Codes and Restart Loops](lessons/02-exit-codes-and-restart-loops.md) | Exit codes, OOMKilled, restart policies, docker events |
| 03 | [Advanced Inspection](lessons/03-advanced-inspection.md) | docker stats, top, diff, history, system df, debugging slim images |

## Challenges

| # | Challenge | Focus |
|---|-----------|-------|
| 01 | [The Silent Crash](challenges/01-the-silent-crash.md) | Container exits immediately — no obvious error |
| 02 | [The Memory Hog](challenges/02-the-memory-hog.md) | Container OOMKilled — diagnose the leak, apply limits |
| 03 | [The Network Black Hole](challenges/03-the-network-black-hole.md) | Container runs but can't reach a service |
| 04 | [The Stale Image](challenges/04-the-stale-image.md) | Changes deployed but not appearing |

---

## Post-Chapter Debrief

Once you complete all four challenges and `verify.sh` passes:

**What you did:** Diagnosed and fixed four different types of container failures using a systematic methodology — from silent crashes to memory leaks, network issues, and stale deployments.

**Why it matters:** In production, you don't get helpful error messages. Containers crash, and the logs are cryptic or empty. Network requests fail with generic timeouts. Images seem correct but serve old code. The ability to systematically work through "I don't know what's wrong" to "I found it and fixed it" is the difference between a 5-minute fix and a 2-hour firefight.

**Real-world connection:** The 6-step debugging workflow maps directly to incident response at any scale. Whether it's a single Docker container on staging or a Kubernetes cluster with 200 pods, the pattern is: observe, inspect, hypothesize, test, fix, verify. Every SRE team has a version of this.

**Interview angle:** "Walk me through how you'd debug a container that keeps restarting." Interviewers want to hear a systematic approach, not random guessing. Start with `docker logs`, move to `docker inspect` for exit codes, check `docker stats` for resources, and work through possibilities methodically.

**Pro tip:** Keep a personal incident log. Every time you debug something interesting, write down: the symptom, the diagnosis path, the root cause, and the fix. After a year, you'll have a personal troubleshooting playbook that's worth its weight in gold.

---

## The Cliffhanger

You fixed the crashes, plugged the memory leaks, restored the network, and untangled the stale deployments. Sarah is genuinely impressed. "You debug like someone who's been through a few on-calls," she says.

Then, on Thursday, an email arrives from `security-audit@nocappuccino.com`:

```
Subject: Security Assessment — Critical Findings

Finding 1: All containers run as root
Finding 2: Database credentials found in image layer history
Finding 3: No resource limits on production containers
Finding 4: Docker socket mounted in development container

Severity: HIGH
Deadline: 2 weeks
```

Dave reads the email three times. Then he looks at you. "Sarah, can we..."

Sarah is already walking toward your desk. "I've been waiting for this conversation."

*Chapter 8: The Audit — coming up.*
