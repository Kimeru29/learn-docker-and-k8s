```
  ___ _    ___   __
 / __| |_ / _ \ / /_
| (__| ' \ (_) / _ \
 \___|_||_\___/\___/

 🧟 "The Zombie Barista"

    WHAT'S HAPPENING?

    $ docker stop learn-ch06-worker
    ... 10 seconds ...
    ... still waiting ...
    ... SIGKILL! 💀

    $ docker top learn-ch06-worker
    PID   CMD
    1     /bin/sh -c node worker.js     ← shell is PID 1?!
    7     node worker.js                ← actual app is PID 7
    15    [defunct]                      ← ZOMBIE 🧟
    23    [defunct]                      ← ZOMBIE 🧟

    (◎_◎;) Dave: "WHY WON'T IT STOP"
    (•‿•)  Sarah: "Because PID 1 matters."
```

# Chapter 6: The Zombie Barista

> "I just ran `docker stop` on the worker and it took 10 seconds to shut down. Every time. And `docker top` is showing these `[defunct]` processes that nobody started. What is going on?"
> — You, Wednesday afternoon

## The Story So Far

The Compose stack from Chapter 5 is running beautifully. New developers join, run `docker compose up`, and are productive in minutes. Dave is happy. Marcus has moved on to bothering the product team.

Then the deployment pipeline starts acting up.

Every time you deploy a new version, `docker stop` takes exactly 10 seconds before the container is killed. The deployment script waits, and waits, and then Docker gives up and sends SIGKILL. The new container starts, but 10 seconds of unnecessary downtime per deploy adds up.

Then on Thursday, you notice something stranger. One of the worker containers — the one that processes coffee order recommendations — is using more CPU than expected. You run `docker top` and see several processes marked `[defunct]`. They're zombies. Not the horror movie kind — the Unix kind. And they're accumulating.

Sarah takes one look at your Dockerfile and sighs: "Shell form. Classic."

---

## What You'll Learn

This chapter is about what happens *inside* your containers at the process level. Most Docker tutorials skip this entirely. Most production incidents involve it.

---

## Chapter Objectives

By the end of this chapter, you will be able to:

1. Explain why PID 1 matters in containers and how it differs from a normal Linux system
2. Fix containers that take 10 seconds to stop (the shell form problem)
3. Understand how ENTRYPOINT and CMD interact and when to use each
4. Diagnose and fix zombie processes in containers
5. Implement graceful shutdown handling in containerized applications
6. Use init processes (tini/dumb-init) when your app shouldn't be PID 1

---

## Lessons

| # | Lesson | Concepts |
|---|--------|----------|
| 01 | [PID 1 and Signals](lessons/01-pid1-and-signals.md) | PID 1 in containers, signal handling, shell vs exec form, the 10-second kill |
| 02 | [ENTRYPOINT and CMD](lessons/02-entrypoint-cmd-interaction.md) | How ENTRYPOINT and CMD combine, override behavior, common mistakes |
| 03 | [Graceful Shutdown and Init](lessons/03-graceful-shutdown-and-init.md) | SIGTERM handling, zombie processes, tini/dumb-init, health checks vs liveness |

## Challenges

| # | Challenge | Focus |
|---|-----------|-------|
| 01 | [Fix Signal Handling](challenges/01-fix-signal-handling.md) | Container takes 10s to stop — fix it to stop in <2s |
| 02 | [Zombie Cleanup](challenges/02-zombie-cleanup.md) | Container accumulating zombie processes — diagnose and fix |
| 03 | [The ENTRYPOINT Puzzle](challenges/03-entrypoint-puzzle.md) | Container behaving wrong due to ENTRYPOINT/CMD conflict |

---

## Post-Chapter Debrief

Once you complete all three challenges and `verify.sh` passes:

**What you did:** Fixed containers that couldn't stop gracefully, cleaned up zombie processes, and untangled ENTRYPOINT/CMD interactions that were causing unexpected behavior.

**Why it matters:** PID 1 behavior is the most commonly misunderstood aspect of Docker in production. A container that takes 10 seconds to stop on every deploy means 10 seconds of unnecessary downtime multiplied by every container, every deploy, every day. Zombie processes leak resources. Incorrect signal handling means your app can't clean up database connections, flush caches, or finish in-flight requests.

**Real-world connection:** Every major container orchestrator (Kubernetes, ECS, Nomad) sends SIGTERM before SIGKILL. If your container doesn't handle SIGTERM, you're forcing hard kills on every deployment. In Kubernetes, this is controlled by `terminationGracePeriodSeconds` — if your app doesn't respond to SIGTERM, K8s waits 30 seconds and then kills it.

**Interview angle:** "What happens when you run `docker stop`?" is a deceptively deep question. The strong answer covers: SIGTERM sent to PID 1, the 10-second grace period, SIGKILL if the process doesn't exit, and why shell form breaks this entire flow.

**Pro tip:** If you're inheriting a codebase with Dockerfiles, `grep -r "CMD.*sh -c" .` is a fast way to find shell form usage that might cause signal handling problems.

---

## The Cliffhanger

The containers stop cleanly now. No more zombies, no more 10-second deploy delays. Sarah gives you an approving nod.

Then, on Monday morning, you get a Slack message from a junior dev: "The API container keeps restarting and I don't know why. It was working on Friday."

You check `docker ps`. The container status says `Restarting (1)`. You check the logs — nothing useful. You check `docker inspect` — exit code 1.

Sarah pulls up a chair. "Time to learn the debugging workflow. The one I use at 3 AM."

*Chapter 7: The Debugging Grind — coming up.*
