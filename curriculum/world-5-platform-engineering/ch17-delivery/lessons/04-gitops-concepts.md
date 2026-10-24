# Lesson 4: GitOps Concepts

> **Sarah:** "What if I told you that the safest way to deploy to production is to merge a pull request? No `kubectl apply`. No Helm from your laptop. Just Git."

---

## What is GitOps?

GitOps is an operational model where:

1. **Git is the single source of truth** for infrastructure and application configuration.
2. **A controller** running in the cluster continuously compares the desired state (what's in Git) with the actual state (what's in the cluster).
3. **Divergence is automatically corrected** — the controller reconciles the cluster to match Git.

```
  Developer                Git Repo               Controller            Cluster
     │                        │                      │                     │
     │  push manifest change  │                      │                     │
     │───────────────────────→│                      │                     │
     │                        │  detect change       │                     │
     │                        │─────────────────────→│                     │
     │                        │                      │  apply manifests    │
     │                        │                      │────────────────────→│
     │                        │                      │                     │
     │                        │                      │  ✓ state matches    │
     │                        │                      │←────────────────────│
```

Nobody runs `kubectl apply`. Nobody SSHes into a server. Changes go through Git — which means they're reviewed, versioned, auditable, and reversible.

---

## Why GitOps?

### The Problems It Solves

| Problem | Without GitOps | With GitOps |
|---------|---------------|-------------|
| "Who deployed this?" | Check Slack, ask around | `git log` — there's the PR, the reviewer, the commit |
| "What's running in prod?" | `kubectl get deployment -o yaml` and hope it matches something | The Git repo IS what's running |
| "How do I roll back?" | Find the old manifest, `kubectl apply`, hope nothing else changed | `git revert`, merge, controller reconciles |
| "Staging and prod drifted" | Nobody noticed until something broke | Controller alerts on drift or auto-corrects |
| "Dave deployed from his laptop" | 🤷 | Impossible — deploys only happen through Git |

### The Core Principles

1. **Declarative.** The desired state of the system is described declaratively (YAML manifests in Git), not imperatively (a sequence of `kubectl` commands).

2. **Versioned and immutable.** Git provides version history, authorship, and the ability to revert. Every change is a commit.

3. **Pulled automatically.** The controller in the cluster pulls changes from Git — the cluster pulls its own state. Developers don't push to the cluster.

4. **Continuously reconciled.** The controller doesn't just apply once. It continuously watches for drift and corrects it. If someone manually changes a Deployment, the controller reverts the change to match Git.

---

## Push vs Pull Deployment Models

### Push Model (Traditional)

```
  CI Pipeline ──kubectl apply──→ Cluster
```

The CI system has cluster credentials and pushes changes. This is how most teams start.

**Pros:** Simple, direct, familiar.
**Cons:** CI system needs cluster credentials. No drift detection. No reconciliation if manual changes are made.

### Pull Model (GitOps)

```
  CI Pipeline ──push image──→ Registry
  Developer ──push manifests──→ Git Repo
  Controller (in cluster) ←──watches──→ Git Repo
  Controller ──applies──→ Cluster
```

The CI system never touches the cluster. It builds and pushes images. Developers update manifests in Git. A controller inside the cluster watches Git and applies changes.

**Pros:** Cluster credentials stay in the cluster. Drift detection. Auto-reconciliation. Full audit trail.
**Cons:** More moving parts. Requires a GitOps controller.

---

## ArgoCD

ArgoCD is the most popular Kubernetes-native GitOps tool. It runs inside your cluster and watches Git repositories.

### Core Concepts

| Concept | What it is |
|---------|-----------|
| **Application** | An ArgoCD resource that maps a Git repo path to a K8s namespace |
| **Sync** | The act of applying manifests from Git to the cluster |
| **Health** | ArgoCD checks if the deployed resources are actually healthy |
| **Drift** | When the cluster state doesn't match Git (someone did a manual `kubectl apply`) |
| **Auto-sync** | ArgoCD automatically syncs when Git changes (optional — can require manual sync) |

### ArgoCD Application CRD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nocappuccino-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nocappuccino/k8s-manifests
    targetRevision: main
    path: apps/api/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true      # Delete resources removed from Git
      selfHeal: true   # Revert manual changes to match Git
```

This tells ArgoCD: "Watch the `apps/api/overlays/production` directory in this Git repo. If anything changes, sync it to the `production` namespace. If someone manually changes something in the cluster, revert it."

### ArgoCD Workflow

```
1. Developer opens PR: "Update API image to v1.5.0"
   - Changes image tag in manifests (or Helm values, or Kustomize overlay)

2. PR is reviewed and merged to main

3. ArgoCD detects the change (polls Git every 3 minutes, or webhook)

4. ArgoCD syncs: applies the updated manifests to the cluster

5. ArgoCD checks health: waits for pods to be Running and Ready

6. If healthy: status = Synced + Healthy ✓
   If unhealthy: status = Degraded — investigate

7. To rollback: git revert the merge commit, merge to main
   ArgoCD syncs the reverted state automatically
```

---

## Flux

Flux is another popular GitOps tool, part of the CNCF. It's lighter-weight than ArgoCD and designed as a set of composable controllers.

### Key Differences from ArgoCD

| | ArgoCD | Flux |
|-|--------|------|
| **UI** | Rich web UI for visualization | CLI-first, no built-in UI (Weave GitOps UI available) |
| **Architecture** | Monolithic server + UI | Set of composable controllers |
| **Git watching** | Application CRD | GitRepository + Kustomization CRDs |
| **Helm support** | Native | Via HelmRelease CRD |
| **Maturity** | Graduated CNCF project | Graduated CNCF project |

Both are excellent. ArgoCD is more popular for teams that want a visual UI. Flux is more popular for teams that prefer a CLI-first, composable approach.

---

## Repository Strategies

### Single Repo (Monorepo)

```
nocappuccino/
├── apps/
│   ├── api/
│   │   ├── src/
│   │   ├── Dockerfile
│   │   └── k8s/
│   │       ├── base/
│   │       └── overlays/
│   └── worker/
│       ├── src/
│       ├── Dockerfile
│       └── k8s/
└── infrastructure/
    ├── prometheus/
    └── ingress/
```

**Pros:** Everything in one place. Easy to find.
**Cons:** CI triggers on every change. Permission boundaries are harder.

### Separate Repos

```
nocappuccino-api (source + Dockerfile)
nocappuccino-worker (source + Dockerfile)
nocappuccino-k8s-manifests (all K8s YAML, Helm charts, Kustomize overlays)
nocappuccino-infrastructure (Prometheus, ingress, cluster config)
```

**Pros:** Clear ownership. CI only triggers for relevant changes. GitOps repo is separate from source.
**Cons:** More repos to manage. Cross-repo changes require coordination.

### The GitOps Repo Pattern

A common pattern: keep application source code separate from deployment manifests.

```
  App Repo (nocappuccino-api)         GitOps Repo (nocappuccino-deploy)
  ├── src/                            ├── apps/
  ├── Dockerfile                      │   ├── api/
  └── .github/workflows/              │   │   ├── base/
      └── build.yaml                  │   │   └── overlays/
                                      │   │       ├── dev/
  CI builds image → pushes to         │   │       ├── staging/
  registry → updates image tag        │   │       └── production/
  in GitOps repo automatically        │   └── worker/
                                      └── infrastructure/
```

The CI pipeline in the app repo builds the image and then opens a PR (or commits directly) to the GitOps repo to update the image tag. ArgoCD/Flux watches the GitOps repo and deploys.

---

## GitOps and Rollback

Rollback in GitOps is beautifully simple:

```bash
# Find the bad commit
git log --oneline

# Revert it
git revert abc123f

# Push (or open a PR)
git push

# ArgoCD/Flux detects the revert and syncs
# The cluster returns to the previous state
```

This is faster than Dave's 45-minute rollback because:

1. You're reverting a known change (the Git commit)
2. The controller applies it automatically
3. There's no guessing about "what was running before"
4. The rollback itself is a Git commit — auditable and reversible

---

## Quick Reference

| Concept | Description |
|---------|-------------|
| GitOps | Git is the source of truth; a controller reconciles cluster state |
| Push model | CI pushes changes to the cluster (traditional) |
| Pull model | Controller in cluster pulls changes from Git (GitOps) |
| ArgoCD | Popular GitOps controller with a web UI |
| Flux | Composable GitOps controllers, CLI-first |
| Reconciliation | Continuous process of matching cluster state to Git state |
| Drift detection | Alerting when cluster state diverges from Git |
| Rollback | `git revert` + merge → controller syncs the reverted state |

---

> **Sarah:** "GitOps isn't a tool — it's a principle. The tool can be ArgoCD, Flux, or even a cron job that runs `kubectl apply` from a Git checkout. What matters is: Git is the truth, changes are reviewed, and the cluster converges to what Git says. After switching to GitOps, Dave's 'laptop deploy' problem disappeared because there's nothing to run from a laptop."

**Next:** [Challenge 01 — Tag Strategy](../challenges/01-tag-strategy.md)
