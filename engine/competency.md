# Competency Tracking Model

This document defines how the AI engine tracks, assesses, and uses player competency data to adapt the learning experience. Read this alongside `rules.md` and `curriculum/map.yaml`.

---

## 1. Competency Areas

Every challenge maps to one or more competency areas. The engine tracks mastery independently per area.

### Docker Competencies

| Key | Label | Scope |
|-----|-------|-------|
| `docker-cli` | Docker CLI | Container lifecycle commands, image management, system inspection |
| `dockerfile` | Dockerfile Engineering | Image builds, layers, caching, multi-stage, security hardening |
| `container-runtime` | Container Runtime Internals | Namespaces, cgroups, PID 1, signals, OCI, containerd, runc |
| `docker-networking` | Docker Networking | Bridge networks, DNS, port mapping, network isolation, troubleshooting |
| `docker-storage` | Docker Storage | Volumes, bind mounts, tmpfs, OverlayFS, permissions |
| `docker-compose` | Docker Compose | Multi-service orchestration, health checks, profiles, secrets, overrides |
| `docker-security` | Docker Security | Non-root, capabilities, read-only FS, secret management, supply chain |
| `docker-troubleshooting` | Docker Troubleshooting | Systematic diagnosis using logs, inspect, exec, stats, events, exit codes |

### Kubernetes Competencies

| Key | Label | Scope |
|-----|-------|-------|
| `k8s-architecture` | Kubernetes Architecture | Control plane, nodes, reconciliation, API objects, declarative state |
| `k8s-workloads` | Kubernetes Workloads | Pods, Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs, CronJobs |
| `k8s-networking` | Kubernetes Networking | Services, Ingress, CoreDNS, NetworkPolicies, CNI concepts |
| `k8s-storage` | Kubernetes Storage | PV, PVC, StorageClasses, dynamic provisioning, StatefulSet storage |
| `k8s-configuration` | Kubernetes Configuration | ConfigMaps, Secrets, env injection, init containers, sidecars, lifecycle hooks |
| `k8s-health` | Health & Reliability | Probes, PDB, rolling updates, rollback, deployment strategies |
| `k8s-scheduling` | Scheduling & Resources | Requests, limits, node selectors, affinity, taints, tolerations, HPA |
| `k8s-security` | Kubernetes Security | RBAC, ServiceAccounts, security contexts, Pod Security Standards, NetworkPolicies |

### Platform & Foundational Competencies

| Key | Label | Scope |
|-----|-------|-------|
| `observability` | Observability | Logs, metrics, traces, Prometheus, Grafana, OpenTelemetry |
| `delivery` | Delivery & Deployment | CI pipelines, registries, tagging, Helm, Kustomize, GitOps concepts |
| `incident-response` | Incident Response | Triage, blast radius, mitigation, rollback, postmortems, runbooks |
| `linux-fundamentals` | Linux Fundamentals | Processes, signals, users, permissions, mounts, /proc, env vars |
| `networking-fundamentals` | Networking Fundamentals | TCP/UDP, DNS, subnets, NAT, routing, TLS, load balancing, L4 vs L7 |

---

## 2. Mastery Levels

Each competency is tracked at one of five mastery levels. These are integers `0`–`4` stored in `.player/progress.yaml`.

| Level | Name | Meaning |
|-------|------|---------|
| **0** | `unexposed` | Player hasn't encountered this area yet. No lessons or challenges attempted. |
| **1** | `introduced` | Player has seen lessons in this area but hasn't practiced through challenges. They may recognize terms but can't apply them independently. |
| **2** | `practicing` | Player has attempted challenges in this area. They may need hints, make mistakes, or take multiple attempts, but they are actively building skill. |
| **3** | `competent` | Player has passed challenges, can explain the concepts behind their solutions, and produces valid, working results with minimal assistance. |
| **4** | `proficient` | Player solved challenges efficiently on first or second attempt, handled edge cases, demonstrated awareness of production concerns (security, performance, reliability), and can reason about tradeoffs. |

### Progression Rules

- A competency starts at `0` and only moves forward based on observed signals (see Section 3).
- Levels **never decrease**. A player who struggles on a later challenge does not lose a previously earned level. Instead, record the struggle as a signal for adaptive guidance.
- Levels can skip: a player who aces a skip-level quiz on Docker CLI can jump from `0` straight to `3`.
- Boss challenges can push a competency from `3` to `4` if the player demonstrates deep understanding under multi-problem pressure.

---

## 3. How Mastery is Assessed

The engine does not assign levels mechanically from a single metric. It reads multiple signals and uses judgment to set the level. Here are the signals to observe, ordered by weight.

### Primary Signals

| Signal | What to observe | Impact |
|--------|-----------------|--------|
| **Challenge performance** | Did the player pass? First attempt or multiple? How many hints were needed? | Strongest indicator. First-attempt pass with 0 hints → strong evidence of competence. 3+ hints → still practicing. |
| **Solution quality** | Is the solution merely valid, or also production-safe, efficient, and secure? | A valid solution that uses `--privileged` or skips health checks is not the same as a hardened one. Quality separates `competent` (3) from `proficient` (4). |
| **Verbal reasoning** | Can the player explain *why* their solution works when asked? Do they understand the underlying mechanism or just the command? | A player who can articulate "the user-defined bridge provides DNS resolution by container name, unlike the default bridge" is demonstrating competence beyond rote command knowledge. |

### Secondary Signals

| Signal | What to observe | Impact |
|--------|-----------------|--------|
| **Lesson engagement** | Does the player ask insightful follow-up questions? Do they skip ahead confidently? Do they need re-explanation of core concepts? | Skipping ahead with correct intuition → likely `introduced` or higher already. Needing repeated re-explanation → still at `introduced`. |
| **Quiz performance** | Score on skip-level quizzes (from the skip-level protocol in `rules.md`). | >= 80% pass means the player can be credited at `competent` (3) for the covered competencies. 100% with strong reasoning → consider `proficient` (4). |
| **Cross-application** | Can the player apply a concept from one area to a new context? (e.g., using Docker networking mental models to reason about K8s Services) | Evidence of transfer indicates deep understanding. This is a strong signal for `proficient` (4). |
| **Time to solution** | How long did the player take relative to the challenge's expected difficulty? | Not a primary metric — speed without understanding is meaningless. But consistently fast, correct solutions with clean reasoning reinforce a `proficient` assessment. |

### Assessment Timing

- **After each challenge:** Re-evaluate the relevant competencies based on the new signals.
- **After each boss challenge:** Re-evaluate all competencies involved in the boss encounter.
- **After a skip-level quiz:** Set competency levels for the skipped chapters based on quiz score and reasoning quality.
- **Periodically during lessons:** If the player asks exceptional questions or demonstrates prior knowledge, note it as a signal. You don't need to update the level mid-lesson, but factor it into the next assessment.

---

## 4. How Mastery Affects the Experience

The player's competency profile directly controls how the engine teaches, hints, and challenges.

### Level 0 — Unexposed

- Full explanations with analogies and NoCappuccino story context.
- Step-by-step demonstrations during teaching mode.
- Generous hint progression during challenges.
- Connect new concepts to real-world analogies the player can relate to.
- Example: *"A Docker volume is like a USB drive you plug into the container — the container can come and go, but the drive keeps the data."*

### Level 1 — Introduced

- Shorter concept explanations; skip the "what is X" intro and go to "here's how X works in practice."
- Still demonstrate commands during teaching mode, but move faster.
- Standard hint progression during challenges.
- Start connecting concepts across areas: *"Remember how the default bridge didn't give us DNS? Same idea applies when we set up Compose networks."*

### Level 2 — Practicing

- Abbreviated explanations focused on the specific gap or nuance the player hasn't grasped yet.
- During teaching, show less and ask the player to predict more: *"What do you think happens if we restart this container without a volume? Try it."*
- During challenges, start with higher-level hints before getting specific.
- Introduce "why" questions in debriefs: *"Your solution works — but why did you choose a named volume over a bind mount here?"*

### Level 3 — Competent

- Skip foundational explanations entirely. Jump to nuance, edge cases, and production concerns.
- During teaching, focus on the "what could go wrong" angle and real-world war stories.
- During challenges, give minimal hints — one directional nudge, then let them work.
- Suggest related advanced topics or deep dives: *"Since you're solid on Docker networking, want to try the advanced-networking deep dive on iptables and veth pairs?"*
- Include interview-style follow-ups in debriefs: *"In an interview, they might ask: what's the difference between a bridge network and an overlay network?"*

### Level 4 — Proficient

- Minimal explanation. Treat the player as a peer.
- During teaching, present concepts as discussion, not instruction: *"You probably know how probes work — the interesting part is choosing between liveness and startup probes for slow-starting apps. What's your take?"*
- During challenges, offer harder variants or additional constraints: *"Want to try this without using `docker exec`? Real production containers often don't have a shell."*
- Recommend interview practice modes when available.
- Suggest they help explain concepts to the "Rookie" character as a teaching exercise.

---

## 5. Progress Storage Format

Competency data is stored in `.player/progress.yaml` under a `competencies` key. This sits alongside the existing `player` and `chapters` sections.

```yaml
competencies:
  docker-cli:
    level: 3          # 0=unexposed, 1=introduced, 2=practicing, 3=competent, 4=proficient
    signals:
      challenges_passed: 6
      challenges_attempted: 7
      hints_used: 2
      first_attempts: 4
      quality_scores:
        - valid
        - valid
        - production-safe
        - efficient
        - production-safe
        - secure
    last_assessed: "2026-10-24"

  dockerfile:
    level: 2
    signals:
      challenges_passed: 2
      challenges_attempted: 3
      hints_used: 3
      first_attempts: 1
      quality_scores:
        - valid
        - valid
    last_assessed: "2026-10-22"

  docker-networking:
    level: 0
    signals:
      challenges_passed: 0
      challenges_attempted: 0
      hints_used: 0
      first_attempts: 0
      quality_scores: []
    last_assessed: null
```

### Quality Score Values

When evaluating a completed challenge, assign one of these quality labels:

| Score | Meaning |
|-------|---------|
| `valid` | Solution works and meets the challenge requirements, but uses defaults or takes shortcuts (e.g., runs as root, no health check, hardcoded values). |
| `production-safe` | Solution follows production best practices: non-root user, proper error handling, clean resource naming, appropriate restart policies. |
| `efficient` | Solution is optimized: small image size, good layer caching, minimal resource usage, fast startup. |
| `secure` | Solution demonstrates security awareness: secrets handled properly, minimal privileges, read-only filesystem where appropriate, no unnecessary capabilities. |

A single challenge can earn multiple quality labels. Record all that apply.

### Storage Rules

- Initialize all competencies at level `0` with empty signals when a new player starts.
- Update signals after every challenge attempt, whether passed or failed.
- Update `level` only after assessment (not automatically from signal counts).
- Update `last_assessed` whenever the level is re-evaluated.
- Never delete signal history — it accumulates across the entire game.

---

## 6. Recommendations Engine

The engine should periodically review the player's competency profile and offer targeted recommendations. Do this at natural transition points: chapter completions, session starts, and after boss challenges.

### Weak Area Nudges

When a competency is at level `1` or `2` while surrounding competencies are at `3`+, surface it:

> *"I noticed networking tends to trip you up — you needed a few extra hints on the DNS challenges. Want to revisit the networking lesson, or try the advanced-networking deep dive for a different angle?"*

Look for patterns:
- High hint usage in a specific area.
- Repeated failures on challenges tagged to a competency.
- Quality scores that stay at `valid` while other areas show `production-safe` or better.

### Strength Recognition

When a competency reaches level `3` or `4`, acknowledge it and offer acceleration:

> *"You're strong at Docker CLI — you've been nailing these challenges on the first try. Want to skip the CLI basics in the next chapter and jump to the meaty stuff?"*

Use strength data to:
- Abbreviate lessons in strong areas.
- Offer to skip review sections.
- Suggest the player help explain concepts to the Rookie character.

### Next Step Suggestions

Based on the overall competency profile, suggest what to tackle next:

> *"Based on your profile, I'd recommend Chapter 11 (K8s Networking) next — your Docker networking is solid, so the concepts will transfer well. K8s storage can wait since you haven't hit storage issues yet."*

Consider:
- Which competencies are prerequisites for upcoming chapters.
- Which areas have the most room for growth.
- Which deep dives are unlocked and relevant to the player's current level.

### Interview Readiness Assessment

When the player has sufficient competencies, suggest interview modes:

| Mode | Unlock Criteria |
|------|----------------|
| Conceptual Interview | At least 3 Docker competencies at level `3`+ |
| Troubleshooting Interview | `docker-troubleshooting` at level `3`+ AND `docker-compose` at level `2`+ |
| Architecture Interview | At least 3 Kubernetes competencies at level `3`+ |

Surface this naturally:

> *"Your Docker competencies are looking solid — CLI, Dockerfile, and networking are all at competent or above. Want to try the conceptual interview mode? It's a good way to test your mental models before a real interview."*

### Recommendation Timing

- **Session start:** Review profile, mention one strength and one area to watch.
- **Chapter completion:** Suggest next chapter based on competency gaps and story progression.
- **Boss challenge completion:** Broad assessment across all involved competencies, suggest deep dives or interview modes.
- **Player asks "show progress":** Display a competency summary with level names and actionable recommendations.

---

## 7. Integration with Other Engine Rules

This model works alongside the existing engine systems:

- **Teaching vs Challenge mode** (`rules.md`): Competency levels determine explanation depth in teaching mode and hint aggressiveness in challenge mode. The mode rules still apply — competency tracking just tunes the intensity.
- **Skip-level protocol** (`rules.md`): Quiz scores feed into competency signals. A passed skip quiz sets relevant competencies to at least level `3`.
- **Curriculum map** (`curriculum/map.yaml`): The `competencies` list on each chapter defines which competency areas are assessed when the player completes that chapter's challenges.
- **Post-mission debriefs** (`rules.md`): Debrief depth adapts to competency level. A `proficient` player gets a shorter debrief focused on edge cases and interview angles. An `introduced` player gets the full five-section debrief.
- **Narrator tone** (`narrator.md`): Sarah's tone doesn't change based on competency — she's always warm and encouraging. But her *content* adapts: more peer-level discussion for proficient players, more analogies and hand-holding for newer ones.
