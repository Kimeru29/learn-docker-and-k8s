# Lesson 2: Registries & Artifacts

> **Sarah:** "A container registry is where your images live between being built and being deployed. It's the warehouse. And like a real warehouse, you need to know what's in it, who can access it, and whether anything in there is expired or dangerous."

---

## What a Container Registry Does

A container registry stores, distributes, and manages container images. When you `docker push`, the image goes to a registry. When Kubernetes pulls an image for a pod, it pulls from a registry.

```
  Developer / CI
       │
       │  docker push
       ▼
  ┌──────────────┐
  │   Registry   │
  │              │
  │  myapp:1.4.2 │
  │  myapp:1.4.1 │
  │  myapp:1.4.0 │
  └──────────────┘
       │
       │  kubelet pull
       ▼
  Kubernetes Node
```

### Registry Types

| Registry | Description |
|----------|-------------|
| **Docker Hub** | The default public registry. Free for public images. |
| **GitHub Container Registry (ghcr.io)** | Integrated with GitHub repos and Actions. |
| **AWS ECR** | Amazon's managed registry. IAM-based auth. |
| **GCP Artifact Registry** | Google's managed registry. |
| **Azure Container Registry** | Microsoft's managed registry. |
| **Harbor** | Open-source, self-hosted registry with scanning and RBAC. |
| **Local registry** | A registry running in your cluster (useful for kind and development). |

---

## Pushing and Pulling Images

### Push

```bash
# Tag the image with the registry prefix
docker tag myapp:1.4.2 registry.example.com/nocappuccino/myapp:1.4.2

# Push to the registry
docker push registry.example.com/nocappuccino/myapp:1.4.2
```

The full image reference format:

```
registry.example.com / nocappuccino / myapp : 1.4.2
│                      │               │       │
│                      │               │       └── tag
│                      │               └── image name
│                      └── repository / namespace
└── registry host (defaults to docker.io if omitted)
```

### Pull

```bash
docker pull registry.example.com/nocappuccino/myapp:1.4.2
```

In Kubernetes, the image field in a pod spec triggers the pull:

```yaml
containers:
  - name: api
    image: registry.example.com/nocappuccino/myapp:1.4.2
```

The kubelet on the node where the pod is scheduled pulls the image from the registry.

---

## Registry Authentication

Most registries require authentication. In Kubernetes, you configure registry credentials as a Secret:

```bash
# Create a docker-registry secret
kubectl create secret docker-registry learn-registry-creds \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  -n learn-ch17
```

Reference it in your pod spec:

```yaml
spec:
  imagePullSecrets:
    - name: learn-registry-creds
  containers:
    - name: api
      image: registry.example.com/nocappuccino/myapp:1.4.2
```

Or attach it to the ServiceAccount so all pods in the namespace use it:

```bash
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "learn-registry-creds"}]}' \
  -n learn-ch17
```

---

## Image Scanning

Image scanning checks your container image for known vulnerabilities (CVEs) in:

- Base image packages (OS-level)
- Application dependencies (npm, pip, NuGet, etc.)
- Misconfiguration (running as root, exposed secrets)

### When to Scan

1. **In the CI pipeline** — before pushing to the registry. A critical vulnerability blocks the push.
2. **In the registry** — some registries (Harbor, ECR) can scan images on push.
3. **At admission** — Kubernetes admission controllers can block pods that reference unscanned or vulnerable images.

### Tools

| Tool | Description |
|------|-------------|
| **Trivy** | Open-source, fast, covers OS packages and language dependencies |
| **Grype** | Open-source from Anchore, similar to Trivy |
| **Snyk** | Commercial + free tier, deep language dependency scanning |
| **Docker Scout** | Built into Docker Desktop, scans images in your local environment |

Example with Trivy:

```bash
# Scan an image for vulnerabilities
trivy image myapp:1.4.2

# Fail if HIGH or CRITICAL vulnerabilities are found (for CI)
trivy image --exit-code 1 --severity HIGH,CRITICAL myapp:1.4.2
```

---

## Artifact Promotion

Promotion means moving an image through stages without rebuilding it.

```
  CI Build
     │
     │ push myapp:abc123f
     ▼
  ┌──────────┐    promote     ┌──────────┐    promote     ┌──────────┐
  │ Dev      │ ──────────────→ │ Staging  │ ──────────────→ │ Prod     │
  │ Registry │                 │ Registry │                 │ Registry │
  └──────────┘                 └──────────┘                 └──────────┘
```

Promotion can mean:
- **Retagging** — adding a `staging` or `production` tag to an existing image
- **Copying** — copying the image from one registry to another (e.g., dev ECR → prod ECR)
- **Promoting by reference** — updating the manifest in the staging/production Git repo to point to the new image digest

The key rule: **the image bits never change.** The same bytes that were tested in staging are the bytes that run in production.

### Digest-Based References

For maximum safety, reference images by digest in production manifests:

```yaml
# Tag-based (mutable — someone could re-push this tag)
image: registry.io/myapp:1.4.2

# Digest-based (immutable — this exact image, forever)
image: registry.io/myapp@sha256:8a2b3c4d5e6f7890abcdef123456...
```

Get the digest of an image:

```bash
docker inspect --format='{{index .RepoDigests 0}}' myapp:1.4.2
# Or from the registry:
# Most registries show the digest in their UI
```

---

## Local Registry with kind

For development and learning, kind can work with a local registry:

```bash
# Create a local registry container
docker run -d --restart=always -p 5001:5000 --name learn-registry registry:2

# Connect it to the kind network
docker network connect kind learn-registry

# Now you can push to localhost:5001 and kind can pull from it
docker tag myapp:1.4.2 localhost:5001/myapp:1.4.2
docker push localhost:5001/myapp:1.4.2
```

In your Kubernetes manifests, reference images from `localhost:5001`:

```yaml
image: localhost:5001/myapp:1.4.2
```

This is what we'll use in the challenges — a local registry that works without internet access or cloud credentials.

---

## Registry Hygiene

### Tag Retention

Registries accumulate images over time. Set retention policies to clean up old, unused images:

- Keep the last N tags per image
- Delete tags older than X days (except production-tagged images)
- Never delete images currently deployed in any cluster

### Don't Store Secrets in Images

Images are stored as layers. If you `COPY` a credentials file into a layer and then `RUN rm` it in the next layer, the credentials are still in the previous layer. Anyone who pulls the image can extract them.

```dockerfile
# BAD: secret is in the layer history
COPY credentials.json /app/
RUN ./setup.sh && rm credentials.json

# GOOD: use build secrets (BuildKit)
RUN --mount=type=secret,id=creds ./setup.sh

# GOOD: inject at runtime via K8s Secrets
# Don't put credentials in the image at all
```

---

## Quick Reference

```bash
# Push image to registry
docker tag myapp:tag registry.host/repo/myapp:tag
docker push registry.host/repo/myapp:tag

# Pull image
docker pull registry.host/repo/myapp:tag

# Create K8s registry secret
kubectl create secret docker-registry <name> \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n <namespace>

# Scan image for vulnerabilities
trivy image myapp:tag

# Get image digest
docker inspect --format='{{index .RepoDigests 0}}' myapp:tag

# Local registry for kind
docker run -d --restart=always -p 5001:5000 --name learn-registry registry:2
```

---

> **Sarah:** "The registry is the handoff point between 'built' and 'deployed.' Treat it like a library: organized, scanned, authenticated, and with old books regularly removed. Dave once pushed 47 versions of `latest` to Docker Hub in one day. Forty-seven. We don't talk about that day."

**Next:** [Lesson 03 — Helm & Kustomize](03-helm-and-kustomize.md)
