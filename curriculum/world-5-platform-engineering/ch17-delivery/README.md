```
   ____ _     _ _____
  / ___| |__ / |___  |
 | |   | '_ \| |  / /
 | |___| | | | | / /
  \____|_| |_|_|/_/

  ____       _ _
 |  _ \  ___| (_)_   _____ _ __ _   _
 | | | |/ _ \ | \ \ / / _ \ '__| | | |
 | |_| |  __/ | |\ V /  __/ |  | |_| |
 |____/ \___|_|_| \_/ \___|_|   \__, |
                                 |___/

  🚀 "The Pipeline"

     ┌─────────────────────────────────────────────────┐
     │                                                 │
     │   DEPLOY LOG — Tuesday 2:47 PM                  │
     │                                                 │
     │   dave@macbook:~$ kubectl apply -f api.yaml     │
     │   dave@macbook:~$ # wait is it the right image? │
     │   dave@macbook:~$ # what tag did I push?        │
     │   dave@macbook:~$ # oh no                       │
     │                                                 │
     │   Image tag: "latest"                           │
     │   Rollback time: 45 minutes                     │
     │   Incidents this month: 3                       │
     │                                                 │
     └─────────────────────────────────────────────────┘

     (◎_◎;) Dave: "It worked when I deployed it from my laptop..."
     (•‿•)  Sarah: "That's the problem."
```

# Chapter 17: The Pipeline — Delivery

## The Story

Dave deployed again. From his laptop. With `kubectl apply`. Using the `latest` tag.

The deploy went fine — until it didn't. The new version had a bug that made the checkout page return 500 errors. Dave noticed after 20 minutes. He tried to roll back, but he wasn't sure which version was running before. The rollback took 45 minutes. Three customers filed support tickets.

This has happened three times this month.

Sarah finally says what everyone's been thinking: "We need a real delivery pipeline. Code goes in one end, tested artifacts come out the other, and nobody deploys from their laptop ever again."

---

## What You'll Learn

By the end of this chapter, you will be able to:

- Build and tag container images with a proper strategy (git SHA, semver) — not `latest`
- Push images to a container registry and understand artifact promotion
- Package Kubernetes applications with Helm (charts, values, releases, rollback)
- Use Kustomize to manage environment-specific configurations
- Understand GitOps principles (Git as source of truth, reconciliation, audit trails)
- Set up a simplified GitOps-style deployment workflow

---

## Prerequisites

- World 4 completed (kind cluster, Deployments, Services, probes)
- `kubectl` connected to your `learn-k8s` cluster
- Helm installed (`helm version`)
- Git installed (`git --version`)
- Namespace `learn-ch17` will be created during challenges

---

## Estimated Time

- Lessons: ~90 minutes
- Challenges: ~2–3 hours
- Quiz: ~15 minutes
- Total: ~4–5 hours

---

## Lessons

| # | Lesson | What You'll Learn |
|---|--------|-------------------|
| 01 | [Container Delivery Model](lessons/01-container-delivery-model.md) | Source → build → test → image → registry → deploy → verify → promote |
| 02 | [Registries & Artifacts](lessons/02-registries-and-artifacts.md) | Container registries, push/pull, authentication, scanning, digest references |
| 03 | [Helm & Kustomize](lessons/03-helm-and-kustomize.md) | Helm charts, values, releases. Kustomize bases, overlays. When to use which. |
| 04 | [GitOps Concepts](lessons/04-gitops-concepts.md) | Git as source of truth, ArgoCD, Flux, push vs pull deployments |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Tag Strategy](challenges/01-tag-strategy.md) | Build an image with git SHA + semver tags, push to a local registry |
| 02 | [Helm Deploy](challenges/02-helm-deploy.md) | Package NoCappuccino as a Helm chart, deploy to different environments, rollback |
| 03 | [GitOps Simulation](challenges/03-gitops-simulation.md) | Set up a Git-based deployment flow with reconciliation and rollback |

To verify your work: `bash curriculum/world-5-platform-engineering/ch17-delivery/challenges/verify.sh`

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Immutable artifact** | A container image that never changes once built — identified by digest, not mutable tag |
| **Image tag** | A human-readable label for an image version (e.g., `v1.2.3`, `abc123f`) |
| **Image digest** | A content-addressable hash that uniquely identifies an image (`sha256:...`) |
| **Container registry** | A service that stores and distributes container images |
| **Artifact promotion** | Moving a verified image from one stage (dev) to the next (staging, production) |
| **Helm** | Kubernetes package manager — charts, values, releases, rollback |
| **Helm chart** | A package of Kubernetes manifests with templated values |
| **Helm release** | A deployed instance of a chart with specific values |
| **Kustomize** | A tool for customizing Kubernetes YAML using patches and overlays |
| **GitOps** | Using Git as the single source of truth for infrastructure and application state |
| **Reconciliation** | A controller continuously comparing desired state (Git) with actual state (cluster) |
| **ArgoCD** | A Kubernetes-native GitOps tool that syncs cluster state from Git repositories |

---

> **Sarah:** "A deployment pipeline isn't bureaucracy. It's the difference between 'Dave deployed a mystery image from his laptop' and 'version 1.4.2, built from commit abc123, tested, scanned, and deployed automatically with a one-click rollback.'"

**Next:** Start with [Lesson 01 — Container Delivery Model](lessons/01-container-delivery-model.md)
