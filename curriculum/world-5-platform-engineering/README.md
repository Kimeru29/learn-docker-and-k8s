```
 __        __         _     _   ____
 \ \      / /__  _ __| | __| | | ___|
  \ \ /\ / / _ \| '__| |/ _` | |___ \
   \ V  V / (_) | |  | | (_| |  ___) |
    \_/\_/ \___/|_|  |_|\__,_| |____/

  ____  _       _    __                        _____ _   _  ____ ___ _   _ _____ _____ ____  ___ _   _  ____
 |  _ \| | __ _| |_ / _| ___  _ __ _ __ ___  | ____| \ | |/ ___|_ _| \ | | ____| ____|  _ \|_ _| \ | |/ ___|
 | |_) | |/ _` | __| |_ / _ \| '__| '_ ` _ \ |  _| |  \| | |  _ | ||  \| |  _| |  _| | |_) || ||  \| | |  _
 |  __/| | (_| | |_|  _| (_) | |  | | | | | || |___| |\  | |_| || || |\  | |___| |___|  _ < | || |\  | |_| |
 |_|   |_|\__,_|\__|_|  \___/|_|  |_| |_| |_||_____|_| \_|\____|___|_| \_|_____|_____|_| \_\___|_| \_|\____|

    Beyond running containers — seeing inside systems, automating delivery,
    and handling incidents like a professional.

    ┌──────────────────────────────────────────────────────────────────┐
    │                                                                  │
    │   Ch16  Observability       🔍 The Glass Roaster                 │
    │   Ch17  Delivery            🚀 The Pipeline                      │
    │   Ch18  Incident Response   🚨 The On-Call Shift                 │
    │   BOSS  Platform Capstone   🏗️  The Full Platform                │
    │                                                                  │
    │   ⚡ All three chapters can be done in any order                 │
    │                                                                  │
    └──────────────────────────────────────────────────────────────────┘

    (•‿•) Sarah: "You can deploy it. Now can you see inside it,
                   ship it safely, and fix it at 2 AM?"
```

# World 5: Platform Engineering

> "Running containers is table stakes. The real job starts when you need to understand why the system is slow, ship changes without fear, and respond when the pager goes off."
> — Sarah, Friday afternoon retro

---

## The Story So Far

You've come a long way since Day 1.

World 1 taught you containers. World 2 taught you engineering discipline. World 3 gave you a cluster. World 4 made it production-grade — probes, resources, security, the whole stack.

NoCappuccino is running on Kubernetes. The Deployments are healthy. The HPA scales. RBAC is locked down. Dave finally stopped texting "just restart it" at 3 AM.

But new problems have emerged. Quiet ones.

The dashboard is green but customers report the coffee recommendation engine is slow. Deploys still happen from Dave's laptop with `kubectl apply` and the image tag `latest`. Last Tuesday an incident turned into 45 minutes of chaos because nobody knew who was in charge, what was broken, or how to roll back.

World 5 is about the practices that surround the cluster. **Observability** — seeing inside the system when the dashboard lies. **Delivery** — shipping changes through a pipeline instead of from a laptop. **Incident Response** — handling the 2 AM page with structure instead of panic.

These are the skills that separate "I can deploy to K8s" from "I can operate a production platform."

---

## Chapters

| # | Chapter | Title | What You'll Learn |
|---|---------|-------|-------------------|
| 16 | [Observability](ch16-observability/) | "The Glass Roaster" | Logs, metrics, traces, Prometheus, Grafana, dashboards, alerts, SLIs/SLOs |
| 17 | [Delivery](ch17-delivery/) | "The Pipeline" | Tagging strategy, registries, Helm, Kustomize, GitOps, immutable artifacts |
| 18 | [Incident Response](ch18-incident-response/) | "The On-Call Shift" | Triage, mitigation, blast radius, postmortems, runbooks |
| 🏗️ | [Boss Fight](boss-platform-capstone/) | "The Full Platform" | Build, deploy, monitor, release, and handle an incident — all at once |

---

## Progression

All three chapters are **parallel** — you can do them in any order:

```
                ┌─── ch16 (Observability) ───┐
                │                            │
World 4 done → ├─── ch17 (Delivery) ─────────┼──→ Boss Fight
                │                            │
                └─── ch18 (Incident Response) ┘
```

The boss fight requires all three chapters.

---

## Competencies

| Competency | Description |
|-----------|-------------|
| `observability` | Logs, metrics, traces, Prometheus, Grafana, OpenTelemetry |
| `delivery` | CI pipelines, registries, tagging, Helm, Kustomize, GitOps concepts |
| `incident-response` | Triage, blast radius, mitigation, rollback, postmortems, runbooks |

---

## Prerequisites

- **World 4: Kubernetes Production** completed (health probes, deployment strategies, resource management, security)
- A working `learn-k8s` kind cluster with `kubectl` configured
- Helm installed: https://helm.sh/docs/intro/install/
- Familiarity with `kubectl`, Deployments, Services, ConfigMaps, Secrets

Verify your tools:

```bash
kubectl cluster-info
helm version
kind get clusters
```

---

## Estimated Time

**14–18 hours** across all chapters and the boss fight.

- Each chapter: 4–6 hours (lessons + challenges + quiz)
- Boss fight: 2–3 hours
- Experienced platform engineers may move faster through individual chapters

---

## Naming Convention

All Kubernetes resources in this world use:

- **Namespace:** `learn-chXX` (e.g., `learn-ch16`, `learn-ch17`)
- **Labels:** `app=learn-docker-k8s`, `world=w05`, `chapter=chXX`
- **Prefix:** `learn-` on all resource names
- **Cluster:** `learn-k8s` (kind cluster)

---

## What You'll Build

By the end of World 5, you will have:

1. A Prometheus + Grafana observability stack that tells you when the system is actually healthy
2. A container delivery pipeline with proper tagging, a Helm chart, and GitOps-style deployment
3. A structured incident response methodology you can use at 2 AM
4. Survived a boss fight that takes an app from source to production and throws an incident mid-rollout

---

## How to Start

If you're continuing from World 4:

```
"next" or "let's continue"
```

If you're jumping in:

```
"skip to chapter 16" or "start world 5"
```

Sarah will quiz you on World 4 fundamentals before letting you skip ahead.

---

*"Anyone can make a dashboard green. Platform engineering is knowing what to do when it's green and something is still broken."*
*— Sarah, incident retrospective notes*
