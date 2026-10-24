```
 __        __         _     _   _
 \ \      / /__  _ __| | __| | / |
  \ \ /\ / / _ \| '__| |/ _` | | |
   \ V  V / (_) | |  | | (_| | | |
    \_/\_/ \___/|_|  |_|\__,_| |_|

  ____             _                _____ _
 |  _ \  ___   ___| | _____ _ __  |  ___| |
 | | | |/ _ \ / __| |/ / _ \ '__| | |_  | |
 | |_| | (_) | (__|   <  __/ |    |  _| |_|
 |____/ \___/ \___|_|\_\___|_|    |_|   (_)

  _____                      _       _   _
 |  ___|__  _   _ _ __   __| | __ _| |_(_) ___  _ __  ___
 | |_ / _ \| | | | '_ \ / _` |/ _` | __| |/ _ \| '_ \/ __|
 |  _| (_) | |_| | | | | (_| | (_| | |_| | (_) | | | \__ \
 |_|  \___/ \__,_|_| |_|\__,_|\__,_|\__|_|\___/|_| |_|___/
```

# World 1: Docker Foundations

> *Your first week at NoCappuccino. Dave's apps keep breaking, data keeps disappearing,
> services can't find each other, and Demo Day is approaching fast.
> Time to learn Docker -- the hard way, the right way.*

---

## The Story Arc

**Day 1 — "It Works on My Machine"**
You walk into NoCappuccino on your first day. Dave, the CTO, is panicking. The Aroma-Discovery API works on his laptop but crashes on staging. Different Node versions, missing libraries, the whole classic mess. Sarah (your mentor, senior DevOps) introduces you to containers and you fix it before lunch.

**Day 2 — "The 2GB Espresso"**
Marcus, the PM, shows you a deploy-time chart that's going up and to the right -- the bad kind. The staging server is at 94% disk because someone shipped a 2GB image with a C compiler baked in. You learn how Docker images are built, how layers work, and how to make images small and fast.

**Day 3 — "The Vanishing Beans"**
Customer support ticket: "My saved coffee preferences disappeared." Dave restarted the database container to "free up memory" and three weeks of data evaporated. You learn why containers are ephemeral by design and how to make data persist across restarts with volumes.

**Day 4 — "The Silent Grinder"**
Demo Day. Two hours until investors arrive. The frontend is up, the database is running, but the frontend can't find the backend. `Error: getaddrinfo ENOTFOUND backend`. You dive into Docker networking, DNS, and port mapping to save the demo.

**Day 5 — "The Morning From Hell"**
Marcus and Dave are both unreachable. Four Docker problems hit simultaneously. A bloated image, a database with no volume, containers that can't communicate, and a port conflict on the frontend. You triage and fix them all under pressure. Welcome to your first boss fight.

---

## Chapters

| #  | Chapter | Title | Focus |
|----|---------|-------|-------|
| 01 | [ch01-containers](ch01-containers/) | It Works on My Machine | Containers, images, Docker CLI lifecycle |
| 02 | [ch02-images](ch02-images/) | The 2GB Espresso | Dockerfiles, layers, caching, multi-stage builds, BuildKit |
| 03 | [ch03-storage](ch03-storage/) | The Vanishing Beans | Ephemeral storage, volumes, bind mounts, tmpfs |
| 04 | [ch04-networking](ch04-networking/) | The Silent Grinder | Network drivers, DNS, port mapping, troubleshooting |
| Boss | [boss-docker-diagnosis](boss-docker-diagnosis/) | The Morning From Hell | All four chapters combined under pressure |

---

## Competencies Covered

By the end of World 1, you will have demonstrated:

| Competency | What it means |
|------------|---------------|
| **docker-cli** | Full container lifecycle: run, stop, rm, logs, exec, inspect |
| **docker-images** | Dockerfile authoring, layer optimization, multi-stage builds, BuildKit, .dockerignore |
| **docker-storage** | Named volumes, bind mounts, tmpfs, OverlayFS basics, permission debugging |
| **docker-networking** | Bridge networks, DNS resolution, port mapping internals, network isolation, troubleshooting |

---

## Prerequisites

- Docker installed and running (Docker Desktop, colima, Rancher Desktop, or native)
- A terminal and a text editor
- No prior Docker experience required -- that's what World 1 is for

Run the environment check to verify:

```bash
bash engine/environment-check.sh
```

---

## Estimated Time

| Component | Time |
|-----------|------|
| Lessons (4 chapters) | ~3-4 hours |
| Challenges (12 + boss) | ~4-6 hours |
| Quizzes & review | ~1-2 hours |
| **Total** | **~8-12 hours** |

Pace yourself. Each chapter is self-contained. Take breaks between chapters -- Sarah would insist.

---

## Resource Naming

All Docker resources in World 1 follow these conventions:

- **Prefix:** `learn-chXX-`
- **Labels:** `--label app=learn-docker-k8s --label world=w01 --label chapter=chXX`
- **Cleanup:** `bash engine/cleanup.sh` removes all `learn-*` resources

---

## Post-World Unlock

Completing World 1 (all four chapters + boss fight) unlocks:

- **World 2: Docker Engineering** (Docker Compose, environment management, multi-container orchestration)
- **Interview Mode: Conceptual** (progressive Docker questions testing your mental models)
- **Deep Dive: Multi-Architecture** (buildx, ARM64/AMD64, manifest lists)

---

## Let's Begin

Ready? Head to [Chapter 1: It Works on My Machine](ch01-containers/).

Sarah's waiting at the coffee bar.
