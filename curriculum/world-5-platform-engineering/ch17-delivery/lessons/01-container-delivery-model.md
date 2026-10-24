# Lesson 1: The Container Delivery Model

> **Sarah:** "There's a path every change should follow — from a developer's commit to running in production. The moment you skip a step, you create the next incident."

---

## The Delivery Lifecycle

Every container-based application follows this lifecycle:

```
Source → Build → Test → Image → Registry → Deploy → Verify → Promote
```

Let's break each step down.

### 1. Source

Code lives in a version-controlled repository (Git). Every change is a commit with a SHA. This SHA becomes the immutable identifier for that exact version of the code.

### 2. Build

The CI system (GitHub Actions, GitLab CI, Jenkins, etc.) builds a container image from the Dockerfile. The build is:

- **Triggered** — by a commit, PR merge, or tag push
- **Reproducible** — the same commit should always produce the same image
- **Automated** — no human runs `docker build` on their laptop

### 3. Test

Before the image ships anywhere:

- Unit tests run against the code
- Integration tests run against the built image
- Security scanning (vulnerability scan of the image layers)
- Linting and static analysis

A failed test stops the pipeline. The image never reaches a registry.

### 4. Image

The build produces a container image — an immutable artifact. Once built, this artifact never changes. It gets tagged and pushed, but the bits inside are frozen.

### 5. Registry

The image is pushed to a container registry (Docker Hub, GitHub Container Registry, AWS ECR, etc.). The registry stores images and makes them available for deployment.

### 6. Deploy

The image is deployed to a target environment (dev → staging → production). The deployment system (kubectl, Helm, ArgoCD) updates the Kubernetes manifests to reference the new image.

### 7. Verify

After deployment, automated checks confirm the new version is healthy:

- Health probes pass
- Smoke tests or synthetic requests succeed
- Key metrics (error rate, latency) don't degrade
- No unexpected restarts

### 8. Promote

If verification passes, the image is promoted to the next stage. The same image (same digest) moves from staging to production. You never rebuild for production — you deploy the artifact you already tested.

```
  git commit → CI build → test → push to registry
                                      │
                        ┌──────────────┤
                        ▼              ▼
                   Deploy to       Deploy to
                    Staging        Production
                        │              │
                   Verify ✓        Verify ✓
```

---

## Why "latest" is an Anti-Pattern

The `latest` tag is the default tag Docker applies when you don't specify one:

```bash
docker build -t myapp .          # Tagged as myapp:latest
docker push myapp                # Pushes myapp:latest
```

This is dangerous in production for several reasons:

**1. "latest" is mutable.**

`latest` doesn't mean "the newest version." It means "whatever was last pushed without an explicit tag." If two developers push at different times, `latest` silently changes.

**2. You can't tell what's running.**

```bash
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'
# myapp:latest

# But WHICH latest? Built when? From which commit? Nobody knows.
```

**3. Rollback is impossible.**

If `latest` is broken and you need to roll back — roll back to what? The previous `latest`? It's been overwritten.

**4. `imagePullPolicy` gotcha.**

Kubernetes defaults to `imagePullPolicy: IfNotPresent` for tagged images, but `Always` for `latest`. This means a pod restart might pull a different image than what was running before.

---

## Tagging Strategies

Good tags are **immutable, traceable, and sortable.**

### Git SHA Tags

```
myapp:abc123f
myapp:7e4f2d1
```

- **Immutable:** One SHA = one exact commit = one exact image
- **Traceable:** `git show abc123f` shows you exactly what code is in that image
- **Automatable:** CI systems have the git SHA available as an environment variable

### Semantic Version Tags (SemVer)

```
myapp:1.4.2
myapp:2.0.0-rc.1
```

Format: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes
- **MINOR:** New features, backward-compatible
- **PATCH:** Bug fixes, backward-compatible

SemVer is human-friendly and sortable. You know `1.4.3` is newer than `1.4.2` and that `2.0.0` has breaking changes.

### Combined Strategy (Recommended)

Tag each image with both:

```bash
docker tag myapp:latest myapp:1.4.2
docker tag myapp:latest myapp:abc123f

docker push myapp:1.4.2
docker push myapp:abc123f
```

Now you have:
- **SemVer** for humans (release notes, changelogs, communication)
- **Git SHA** for traceability (which exact commit is deployed)

### Timestamp Tags

```
myapp:20240315-142347
```

Sortable by time but not traceable to a specific commit. Useful as a secondary tag.

---

## Immutable Artifacts

The principle: **build once, deploy everywhere.**

```
  ┌──────────────────────────────────────────────────┐
  │                                                  │
  │  ❌ Build for dev → test → build for staging     │
  │     → test → build for production                │
  │                                                  │
  │  ✅ Build once → test → deploy to dev            │
  │     → promote to staging → promote to production │
  │                                                  │
  └──────────────────────────────────────────────────┘
```

Why?

1. **The image you tested is the image you deploy.** If you rebuild for production, you might get a different result (different base image, different dependency versions, different build environment).
2. **Configuration is external.** The same image works in all environments because environment-specific values (database URLs, feature flags) come from ConfigMaps and Secrets, not from the image.
3. **Audit trail.** You can always point to the exact artifact that was deployed. `sha256:abc123...` is an immutable reference to a specific image.

### Image Digests

Tags are mutable pointers. Digests are immutable content hashes.

```bash
# Tag (mutable)
myapp:1.4.2

# Digest (immutable)
myapp@sha256:8a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890
```

In production Kubernetes manifests, you can reference images by digest for maximum immutability:

```yaml
containers:
  - name: api
    image: myregistry.io/myapp@sha256:8a2b3c4d5e6f...
```

This guarantees that even if someone re-pushes the `1.4.2` tag with different content, your pods run the exact image you deployed.

---

## What This Looks Like in Practice

A typical CI pipeline for a Kubernetes application:

```yaml
# Simplified GitHub Actions example
on:
  push:
    branches: [main]

jobs:
  build-and-push:
    steps:
      - uses: actions/checkout@v4

      - name: Set image tags
        run: |
          SHORT_SHA=$(git rev-parse --short HEAD)
          echo "IMAGE_TAG_SHA=$SHORT_SHA" >> $GITHUB_ENV
          echo "IMAGE_TAG_VERSION=1.4.2" >> $GITHUB_ENV

      - name: Build image
        run: docker build -t myapp:$IMAGE_TAG_SHA .

      - name: Run tests
        run: docker run --rm myapp:$IMAGE_TAG_SHA npm test

      - name: Scan for vulnerabilities
        run: trivy image myapp:$IMAGE_TAG_SHA

      - name: Push to registry
        run: |
          docker tag myapp:$IMAGE_TAG_SHA registry.io/myapp:$IMAGE_TAG_SHA
          docker tag myapp:$IMAGE_TAG_SHA registry.io/myapp:$IMAGE_TAG_VERSION
          docker push registry.io/myapp:$IMAGE_TAG_SHA
          docker push registry.io/myapp:$IMAGE_TAG_VERSION

      - name: Deploy to staging
        run: |
          helm upgrade --install myapp ./chart \
            --set image.tag=$IMAGE_TAG_SHA \
            --namespace staging
```

---

## Quick Reference

| Concept | Rule |
|---------|------|
| Image tags | Use git SHA + semver, never only `latest` |
| Build location | CI system, not a developer's laptop |
| Artifact flow | Build once, promote through environments |
| Configuration | External (ConfigMap/Secret), not baked into image |
| Rollback | Deploy the previous known-good tag — don't rebuild |
| Verification | Automated checks after every deploy |

---

> **Sarah:** "Dave's 'deploy from my laptop' approach worked when we were three people. Now we're fifteen. The pipeline isn't about slowing anyone down — it's about making sure the version running in production is the same one that passed tests, was scanned, and can be rolled back in 30 seconds instead of 45 minutes."

**Next:** [Lesson 02 — Registries & Artifacts](02-registries-and-artifacts.md)
