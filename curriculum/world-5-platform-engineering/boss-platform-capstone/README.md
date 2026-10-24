```
  ____   ___  ____ ____    _____ ___ ____ _   _ _____
 | __ ) / _ \/ ___/ ___|  |  ___|_ _/ ___| | | |_   _|
 |  _ \| | | \___ \___ \  | |_   | | |  _| |_| | | |
 | |_) | |_| |___) |__) | |  _|  | | |_| |  _  | | |
 |____/ \___/|____/____/  |_|   |___\____|_| |_| |_|

  _____ _            _____      _ _   ____  _       _    __
 |_   _| |__   ___  |  ___|   _| | | |  _ \| | __ _| |_ / _| ___  _ __ _ __ ___
   | | | '_ \ / _ \ | |_ | | | | | | | |_) | |/ _` | __| |_ / _ \| '__| '_ ` _ \
   | | | | | |  __/ |  _|| |_| | | | |  __/| | (_| | |_|  _| (_) | |  | | | | | |
   |_| |_| |_|\___| |_|   \__,_|_|_| |_|   |_|\__,_|\__|_|  \___/|_|  |_| |_| |_|

  🏗️  WORLD 5 BOSS FIGHT

     ┌────────────────────────────────────────────────────────────┐
     │                                                            │
     │   MISSION BRIEF                                            │
     │                                                            │
     │   Source code → Build pipeline → Registry → Deploy (Helm)  │
     │   → Monitor (Prometheus) → Rolling update → INCIDENT       │
     │   → Triage → Mitigate (rollback) → Postmortem             │
     │                                                            │
     │   Everything you've learned. All at once.                  │
     │                                                            │
     │   Time limit: None. But the coffee is getting cold.        │
     │                                                            │
     └────────────────────────────────────────────────────────────┘

     (★‿★) Sarah: "This is it. The whole platform. From source to
                    production to incident to resolution. Show me
                    what you've learned."

     (ˊ_>ˋ) Dave:  "Wait, you can do ALL of that?"
```

# Boss Fight: The Full Platform

## The Story

NoCappuccino is launching a new feature: personalized bean subscriptions. The board is watching. Marcus has a countdown timer. Dave is "available on Slack" (which means he's getting coffee).

Your mission: take the NoCappuccino application through the entire platform engineering lifecycle:

1. **Build** a properly tagged image
2. **Deploy** to Kubernetes using Helm with proper health probes
3. **Monitor** with Prometheus — set up a basic dashboard
4. **Release** a new version via controlled rolling update while monitoring
5. **Respond** to an incident mid-rollout — the new version has a problem
6. **Resolve** — triage, mitigate, investigate, and document

This is everything from World 5 — observability, delivery, and incident response — combined into one scenario.

---

## Prerequisites

- Chapters 16, 17, and 18 completed
- kind cluster running with `kubectl` configured
- Helm installed
- Prometheus + Grafana installed in the cluster (from Chapter 16)
- Familiarity with Helm charts, GitOps concepts, and incident response process

---

## Estimated Time

2–3 hours. This is the final exam. Give it the time it deserves.

---

## The Challenge

Go to: [The Full Platform Challenge](challenges/01-full-platform.md)

---

## Competencies Tested

| Competency | How it's tested |
|-----------|-----------------|
| `observability` | Deploy Prometheus, monitor the rollout, use metrics to detect the incident |
| `delivery` | Build image with proper tags, deploy with Helm, rolling update strategy |
| `incident-response` | Triage the mid-rollout incident, mitigate, document postmortem |
| `k8s-health` | Health probes, rolling update configuration, readiness checks |
| `k8s-security` | Resource limits, proper configuration management |

---

> **Sarah:** "Five worlds. Eighteen chapters. And this. Everything you've learned — containers, images, networking, orchestration, production Kubernetes, observability, delivery, incident response — it all comes together right now. I'm not going to help you on this one. You don't need me to."
