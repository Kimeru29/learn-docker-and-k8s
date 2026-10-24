```
 __        __         _     _   ____
 \ \      / /__  _ __| | __| | |___ \
  \ \ /\ / / _ \| '__| |/ _` |   __) |
   \ V  V / (_) | |  | | (_| |  / __/
    \_/\_/ \___/|_|  |_|\__,_| |_____|

  ____             _                _____ _   _  ____ ___ _   _ _____ _____ ____  ___ _   _  ____
 |  _ \  ___   ___| | _____ _ __  | ____| \ | |/ ___|_ _| \ | | ____| ____|  _ \|_ _| \ | |/ ___|
 | | | |/ _ \ / __| |/ / _ \ '__| |  _| |  \| | |  _ | ||  \| |  _| |  _| | |_) || ||  \| | |  _
 | |_| | (_) | (__|   <  __/ |    | |___| |\  | |_| || || |\  | |___| |___|  _ < | || |\  | |_| |
 |____/ \___/ \___|_|\_\___|_|    |_____|_| \_|\____|___|_| \_|_____|_____|_| \_\___|_| \_|\____|

    From solo containers to production-grade systems.

    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │   Ch05  Compose          ♫ The Symphony of Steam        │
    │   Ch06  Processes        🧟 The Zombie Barista          │
    │   Ch07  Troubleshooting  🔍 The Debugging Grind         │
    │   Ch08  Security         🔒 The Audit                   │
    │   BOSS  Production       💥 The Full Stack Meltdown     │
    │                                                         │
    └─────────────────────────────────────────────────────────┘

    (•‿•) Sarah: "Time to build things that don't break at 3 AM."
```

# World 2: Docker Engineering

> "You know how to run containers. Now let's make them *survive*."
> — Sarah, Monday morning standup

---

## The Story So Far

World 1 was about survival. You learned to build images, persist data, wire networks, and ship containers that actually work. The investor demo went perfectly. Dave is happy. Marcus has stopped panic-messaging for at least 48 hours.

But NoCappuccino is growing. Fast.

Three new developers joined this month. The staging server has become a graveyard of orphaned containers. Someone committed database credentials to the public repo. And last Tuesday, a container ate all the host memory and took down the entire staging environment — including the coffee ordering API, which meant the office literally could not order coffee.

World 2 is about engineering discipline. You'll learn to orchestrate multi-container systems, handle processes like a Linux veteran, debug like a 3 AM incident responder, and secure everything before the auditors arrive.

By the end of this world, you won't just run containers — you'll run them *well*.

---

## Chapters

| # | Chapter | Title | Focus |
|---|---------|-------|-------|
| 05 | [Compose](ch05-compose/README.md) | The Symphony of Steam | Multi-container orchestration, health checks, secrets, profiles |
| 06 | [Process Management](ch06-process-management/README.md) | The Zombie Barista | PID 1, signals, ENTRYPOINT/CMD, graceful shutdown, init processes |
| 07 | [Troubleshooting](ch07-troubleshooting/README.md) | The Debugging Grind | Systematic debugging, exit codes, resource monitoring, inspection |
| 08 | [Docker Security](ch08-docker-security/README.md) | The Audit | Non-root containers, image security, runtime hardening, least privilege |
| BOSS | [Production Docker](boss-production-docker/README.md) | The Full Stack Meltdown | All skills combined — multi-failure triage under pressure |

---

## Competencies Covered

| Competency | Chapters | Description |
|------------|----------|-------------|
| `docker-compose` | Ch05 | Define, manage, and operate multi-container applications with Compose |
| `container-runtime` | Ch06 | Understand PID 1, signal handling, process lifecycle, and init systems |
| `docker-troubleshooting` | Ch07 | Systematic debugging methodology for containers in distress |
| `docker-security` | Ch08 | Non-root execution, secret management, capabilities, runtime hardening |

---

## Prerequisites

- **World 1: Docker Foundations** — completed (or skipped with quiz)
- Comfortable with: `docker run`, `docker build`, Dockerfiles, volumes, networks
- A working Docker installation (Docker Desktop or equivalent)

---

## Estimated Time

**10–14 hours** depending on experience.

- Each chapter: 2–3 hours (lessons + challenges + quiz)
- Boss fight: 1–2 hours
- Experienced Docker users may move faster through Ch05 and focus on Ch06–Ch08

---

## What You'll Build

By the end of World 2, you will have:

1. A complete Docker Compose stack with health checks, secrets, profiles, and resource limits
2. Containers that handle SIGTERM gracefully and clean up zombie processes
3. A repeatable debugging methodology you can use at 3 AM
4. Hardened containers running as non-root with minimal capabilities and no leaked secrets
5. Survived a multi-failure boss fight that tests everything at once

---

## How to Start

If you're continuing from World 1:

```
"next" or "let's continue"
```

If you're jumping in:

```
"skip to chapter 5" or "start world 2"
```

Sarah will quiz you on World 1 fundamentals before letting you skip ahead. Fair warning — she's thorough.

---

*"Anyone can start a container. Engineering is making sure it stays running when everything goes wrong."*
*— Sarah, post-incident retro notes*
