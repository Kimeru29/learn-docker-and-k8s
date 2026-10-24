  _    _                _            _   _            _   _               _
 | |  | |              | |          | | | |           | | | |             | |
 | |  | |_ __   ___  __| | ___ _ __ | |_| |__   ___  | |_| | ___   ___  __| |
 | |  | | '_ \ / _ \/ _` |/ _ \ '__||  _  | '_ \ / _ \ |  _  |/ _ \ / _ \ / _` |
 | |__| | | | | (_) | (_| |  __/ |   | | | | | | |  __/ | | | | (_) | (_) | (_| |
  \____/|_| |_|\___/ \__,_|\___|_|   \_| |_/_| |_|\___| \_| |_/\___/ \___/ \__,_|

 🔬 Deep Dive: "Under the Hood"

    .---------------------------------------------.
    |  userspace                                   |
    |  .-----------.  .-----------.  .----------.  |
    |  | Container |  | Container |  | Process  |  |
    |  | PID ns    |  | NET ns    |  | (host)   |  |
    |  | MNT ns    |  | UTS ns    |  |          |  |
    |  '-----------'  '-----------'  '----------'  |
    |  ─────────── kernel boundary ──────────────  |
    |  namespaces  │  cgroups  │  OverlayFS        |
    |  (isolation) │  (limits) │  (layers)         |
    '---------------------------------------------'

    (★‿★) Sarah: "Let me show you what's really
           going on under the container hood."

# Deep Dive: Under the Hood — Linux Internals for Container Engineers

## Why This Deep Dive Exists

You've been running containers for a while now. You know `docker run`, you know images, networks, volumes. But when something weird happens — a process won't die, a container is eating memory it shouldn't be, an image is inexplicably huge — you need to go deeper.

This deep dive takes you under Docker's abstractions and shows you the raw Linux machinery. Not theory — you'll create namespaces by hand and watch cgroups limit processes in real time.

> *Sarah speaking:* "When I was starting out, containers felt like magic boxes. Then one night at 3 AM a container refused to die, and I had to understand what PID 1 actually means in a namespace. That's when containers stopped being magic and started being just Linux. Let me save you the 3 AM part."

---

## Prerequisites

- **Required:** Chapter 06 — Process Management (completed)
- You should be comfortable with basic Docker commands and understand that containers are Linux processes

---

## What You'll Learn

- How Linux namespaces create the isolation containers depend on
- How cgroups enforce memory and CPU limits — and what happens when you hit them
- How OverlayFS layers images and implements copy-on-write
- How to inspect all of this on a running container using `/proc` and system tools

---

## Topics

| Topic | Description |
|-------|-------------|
| Namespaces | The isolation primitives — PID, NET, MNT, UTS, IPC, USER |
| cgroups | Resource limits and accounting — memory, CPU, I/O |
| OverlayFS | Layered filesystems, copy-on-write, why image size matters |
| `/proc` | The kernel's information API — everything is a file |
| Capabilities | Fine-grained root powers — why `CAP_NET_ADMIN` ≠ full root |
| Seccomp | Syscall filtering — the kernel's last line of defense |

---

## Lessons

| # | Lesson | Topics |
|---|--------|--------|
| 01 | [Namespaces Hands-On](lessons/01-namespaces-hands-on.md) | PID, NET, MNT, UTS, IPC, USER namespaces — creation, inspection, Docker's usage |
| 02 | [cgroups Hands-On](lessons/02-cgroups-hands-on.md) | cgroup hierarchy, memory.max, cpu.max, enforcement, v1 vs v2 |
| 03 | [OverlayFS and Layers](lessons/03-overlayfs-and-layers.md) | OverlayFS mechanics, upper/lower/merged/workdir, copy-on-write, layer caching |

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Namespace Exploration](challenges/01-namespace-exploration.md) | Find and explain container namespaces using docker inspect and /proc |
| 02 | [cgroup Limits](challenges/02-cgroup-limits.md) | Find a container's cgroup path, read usage, apply and verify limits |

To verify your work: `bash curriculum/deep-dives/linux-internals/challenges/verify.sh`

---

## Estimated Time

- Lessons: ~45 minutes
- Challenges: ~30–45 minutes
- Total: ~1.5 hours

---

## Platform Notes

⚠️ **macOS / Docker Desktop users:** Docker Desktop runs containers inside a lightweight Linux VM. Some commands that inspect `/proc` or cgroup files on the host won't work directly — you'll need to use `docker run --pid=host` or `nsenter` into the Docker Desktop VM. The lessons call out workarounds where needed.

⚠️ **`unshare` command:** Creating namespaces by hand with `unshare` requires Linux. On macOS, we'll demonstrate via containers instead.

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Namespace** | Kernel abstraction that gives a process an isolated view of a system resource |
| **cgroup** | Kernel mechanism to limit, account for, and isolate resource usage of process groups |
| **OverlayFS** | Union filesystem that merges multiple directory layers into a single view |
| **`/proc`** | Pseudo-filesystem exposing kernel and process information as files |
| **Capability** | A distinct unit of privilege that can be independently granted (replaces all-or-nothing root) |
| **Seccomp** | Kernel feature to filter which system calls a process can make |
| **veth pair** | Virtual ethernet cable with two ends — one inside a namespace, one outside |
| **Copy-on-write** | Data sharing strategy where copies are only made when a write occurs |
