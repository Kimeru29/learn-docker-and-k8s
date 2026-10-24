# Chapter 17 Quiz: Delivery

> **Sarah:** "Five questions. These cover the mistakes I see teams make over and over — the ones that cause 2 AM pages and 45-minute rollbacks."

---

## Question 1

Your CI pipeline builds a container image and pushes it with three tags:

```bash
docker push registry.io/myapp:latest
docker push registry.io/myapp:1.4.2
docker push registry.io/myapp:abc123f
```

A week later, the CI pipeline runs again and pushes:

```bash
docker push registry.io/myapp:latest
docker push registry.io/myapp:1.5.0
docker push registry.io/myapp:def456a
```

**Which tag(s) now point to a DIFFERENT image than a week ago?**

A) All three tags point to different images.

B) Only `latest` changed. `1.4.2` and `abc123f` still point to the original images.

C) `latest` and `1.4.2` changed. Only `abc123f` is safe.

D) None changed — Docker registries are immutable.

<details>
<summary>Answer</summary>

**B.**

`latest` was re-pushed and now points to the v1.5.0 build. The `1.4.2` and `abc123f` tags were not re-pushed, so they still point to the original image.

This is why `latest` is dangerous: it's a mutable pointer that silently changes. `1.4.2` and `abc123f` remain stable because nobody pushed new content under those tags.

In a well-run pipeline, semver tags and git SHA tags are never reused. `latest` is always reused — which is why it should never appear in production manifests.

</details>

---

## Question 2

You have a Helm chart deployed as release `learn-api` in `staging` namespace. You run:

```bash
helm upgrade learn-api ./chart --set image.tag=v1.5.0 -n staging
```

The new version crashes. Pods go into CrashLoopBackOff. You need to roll back.

**What is the fastest way to restore the previous working version?**

A) Edit the Deployment YAML manually to change the image tag back, then `kubectl apply`.

B) `helm rollback learn-api 0 -n staging` — revision 0 is always the initial state.

C) `helm history learn-api -n staging` to find the previous revision number, then `helm rollback learn-api <revision> -n staging`.

D) Delete the release and reinstall with the old values.

<details>
<summary>Answer</summary>

**C.**

`helm history` shows all revisions with their status. Find the last `deployed` revision before the bad upgrade, then `helm rollback` to that revision number.

```bash
helm history learn-api -n staging
# REVISION  STATUS      DESCRIPTION
# 1         superseded  Install complete
# 2         deployed    Upgrade complete    ← this is the broken one

helm rollback learn-api 1 -n staging
```

Option A works but bypasses Helm's release tracking — Helm won't know about the change, causing confusion later. Option B is wrong — revision 0 doesn't exist. Option D works but is unnecessarily destructive and loses release history.

</details>

---

## Question 3

In a GitOps workflow with ArgoCD, a developer makes a manual change to a Deployment in the cluster:

```bash
kubectl scale deployment api --replicas=1 -n production
```

The ArgoCD Application has `selfHeal: true` configured.

**What happens next?**

A) ArgoCD accepts the change and updates Git to match the cluster (cluster → Git sync).

B) ArgoCD detects the drift and reverts the Deployment back to the replica count defined in Git.

C) ArgoCD ignores the change because it only watches Git, not the cluster.

D) ArgoCD alerts about the drift but takes no action until a manual sync is triggered.

<details>
<summary>Answer</summary>

**B.**

With `selfHeal: true`, ArgoCD continuously compares the cluster state with Git. When it detects that the replica count was changed manually (drift), it reverts the change to match what's in Git.

This is the core GitOps property: Git is the source of truth. Manual changes are treated as drift and corrected. If you want to change the replica count, you commit the change to Git and let ArgoCD sync it.

Option A describes the opposite direction — ArgoCD never writes to Git. Option C is wrong — ArgoCD watches both Git and the cluster to detect divergence.

</details>

---

## Question 4

You're choosing between Helm and Kustomize for managing your application's K8s manifests across dev, staging, and production.

**Which statement correctly describes a difference between the two?**

A) Helm templates produce valid Kubernetes YAML. Kustomize patches do not.

B) Kustomize base manifests are valid Kubernetes YAML. Helm templates contain Go template syntax and are not valid YAML on their own.

C) Helm supports rollback. Kustomize does too, through `kustomize rollback`.

D) Kustomize requires installing a separate tool. Helm is built into kubectl.

<details>
<summary>Answer</summary>

**B.**

Kustomize starts with plain, valid Kubernetes YAML (the "base") and applies patches. You can `kubectl apply` the base directly. Helm templates contain `{{ .Values.xxx }}` syntax — they're not valid YAML until rendered with `helm template` or `helm install`.

Option A is reversed. Option C is wrong — Kustomize has no built-in rollback command; you use Git for that. Option D is also reversed — Kustomize is built into kubectl (`kubectl apply -k`), while Helm is a separate tool.

</details>

---

## Question 5

Your deployment pipeline builds an image, runs tests, pushes to a registry, and deploys to staging. Everything passes. Now you need to deploy to production.

**Which approach follows the immutable artifact principle?**

A) Re-run the CI pipeline targeting production. It rebuilds the image from the same commit and deploys it.

B) Deploy the exact same image (same digest) that was tested in staging to production, using production-specific configuration from ConfigMaps and Secrets.

C) Copy the Dockerfile from the staging build and rebuild locally on a production-certified machine.

D) Pull the staging image, re-tag it as `production`, and push that new tag to the production registry.

<details>
<summary>Answer</summary>

**B.**

The immutable artifact principle says: build once, deploy everywhere. The image that passed tests in staging is the image that goes to production — same bytes, same digest. Environment-specific differences (database URLs, feature flags, secrets) come from ConfigMaps and Secrets, not from the image.

Option A rebuilds, which might produce a different image (different base image layers, different dependency versions). Option C is worse — manual builds on a "production-certified machine" is the opposite of a pipeline. Option D is partially correct (re-tagging preserves the content) but the key is deploying the same digest, not just re-tagging.

</details>

---

> **Sarah:** "Five for five? Good. You now understand why 'latest' is banned, how Helm rollback works, why Git is the source of truth, and what 'build once, deploy everywhere' actually means. Dave's laptop deployment era is officially over."
