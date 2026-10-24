# Lesson 4: BuildKit and Advanced Caching

## The Scene

"Alright," you say, leaning back. "We've shrunk the image, fixed the layer order, and added multi-stage builds. The Bean-Tracker is lean. But there's one more level to this."

You open the terminal and type `DOCKER_BUILDKIT=1`.

"Meet BuildKit -- Docker's modern build engine. It's been the default since Docker 23.0, but most people have never touched its advanced features. Today we change that."

---

## What Is BuildKit?

BuildKit is the next-generation build engine for Docker. It replaced the legacy builder and brings significant improvements:

- **Parallel execution** -- independent build stages run concurrently
- **Better caching** -- more granular cache management and external cache backends
- **Build secrets** -- mount sensitive data during build without baking it into layers
- **Cache mounts** -- persist package manager caches across builds
- **Improved output** -- cleaner, more informative build logs

If you're running Docker 23.0+ (check with `docker version`), BuildKit is already your default builder. If you're on an older version, enable it with:

```bash
export DOCKER_BUILDKIT=1
```

You can verify by looking at the build output -- BuildKit shows `[+] Building` with stage numbers, while the legacy builder shows `Step 1/8 :`.

---

## Cache Mounts: The Package Manager Turbocharger

This is the single most impactful BuildKit feature for build speed.

### The Problem

Every time `RUN npm install` or `RUN go mod download` runs, it downloads packages from the internet. Even with good layer caching, the moment your `package.json` changes, the entire download happens again from scratch.

### The Solution: `--mount=type=cache`

Cache mounts let you persist a directory across builds -- like a local package manager cache that survives between builds.

```dockerfile
# syntax=docker/dockerfile:1

FROM node:20-alpine
WORKDIR /app

COPY package*.json ./

# Mount the npm cache directory -- persists across builds
RUN --mount=type=cache,target=/root/.npm \
    npm install

COPY . .
CMD ["node", "server.js"]
```

What happens:
1. First build: npm downloads all packages (slow)
2. You change `package.json` and rebuild
3. npm checks its cache (`/root/.npm`) -- many packages are already there
4. Only new/changed packages are downloaded

The cache mount is NOT part of the final image. It's a temporary mount during the build only.

### Cache Mounts for Other Languages

```dockerfile
# Go
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Python
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Rust
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    cargo build --release

# apt-get (Debian/Ubuntu)
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y curl
```

> **Note:** The `# syntax=docker/dockerfile:1` line at the top of the Dockerfile enables the latest Dockerfile syntax features. Always include it when using BuildKit-specific directives.

---

## Secret Mounts: Keeping Credentials Out of Layers

### The Problem

Sometimes you need credentials during the build -- a private npm token, a GitHub PAT, or an SSH key to clone a private repo. If you `COPY` them in or pass them as `ARG`, they end up in the image layers. Anyone who pulls the image can extract them.

### The Solution: `--mount=type=secret`

Secret mounts expose a file during a single `RUN` instruction. The file is never written to any layer.

```dockerfile
# syntax=docker/dockerfile:1

FROM node:20-alpine
WORKDIR /app

COPY package*.json ./

# Use a secret .npmrc for private registry auth
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm install

COPY . .
CMD ["node", "server.js"]
```

Build it with:

```bash
docker build \
  --secret id=npmrc,src=$HOME/.npmrc \
  -t learn-ch02-private-app .
```

The `.npmrc` file is available during `npm install` but is NOT in the final image. You can verify:

```bash
docker run --rm learn-ch02-private-app cat /root/.npmrc
# cat: can't open '/root/.npmrc': No such file or directory
```

### SSH Mounts

For cloning private git repos during builds:

```dockerfile
RUN --mount=type=ssh git clone git@github.com:private/repo.git
```

```bash
docker build --ssh default -t my-image .
```

This uses your local SSH agent -- the key is never copied into the image.

---

## Build Arguments: Build-Time Configuration

`ARG` defines variables that are available during the build but NOT at runtime (unlike `ENV`).

```dockerfile
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-alpine

ARG APP_VERSION=1.0.0
RUN echo "Building version $APP_VERSION"

ENV APP_VERSION=$APP_VERSION  # Promote to runtime if needed
```

```bash
docker build --build-arg NODE_VERSION=18 --build-arg APP_VERSION=2.0.0 -t my-app .
```

**Key difference from ENV:**
- `ARG` is available only during build, not at runtime
- `ARG` values are NOT embedded in the image (unless promoted to `ENV`)
- `ARG` values ARE visible in `docker history` -- do not use for secrets

**When to use ARG vs ENV:**

| | ARG | ENV |
|---|---|---|
| Available during build | Yes | Yes |
| Available at runtime | No | Yes |
| Visible in `docker history` | Yes | Yes |
| Settable from CLI | `--build-arg` | `-e` (at run time) |
| Use for | Build-time config (versions, flags) | Runtime config (ports, DB hosts) |

---

## Pinning Images by Digest vs Tag

Tags are mutable. Someone can push a new image to `node:20-alpine` and your next build uses a completely different base. In production, this matters.

### Tags: Convenient, Not Reproducible

```dockerfile
FROM node:20-alpine
# Which exact version of node:20-alpine? Depends when you pull.
```

### Digests: Exact and Reproducible

```dockerfile
FROM node:20-alpine@sha256:abc123def456...
# This ALWAYS refers to the exact same image, forever.
```

To find the digest:

```bash
docker pull node:20-alpine
docker inspect node:20-alpine --format '{{index .RepoDigests 0}}'
# node@sha256:abcdef1234567890...
```

**When to pin by digest:**
- Production Dockerfiles where reproducibility matters
- CI/CD pipelines where builds must be deterministic
- Security-sensitive builds where you need to verify the base image hasn't changed

**When tags are fine:**
- Local development
- Tutorials and learning (like this one)
- When you want to automatically pick up security patches in the base image

---

## Multi-Platform Awareness

Modern Docker can build images for multiple CPU architectures from a single machine:

```bash
# Build for both amd64 and arm64:
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t learn-ch02-multiarch:latest \
  --push .
```

This uses QEMU emulation to cross-compile. The result is a **manifest list** -- a single tag that points to multiple architecture-specific images. When someone pulls `learn-ch02-multiarch:latest`, Docker automatically selects the right one for their CPU.

In your Dockerfile, you can use `TARGETARCH` and `TARGETOS` to adapt:

```dockerfile
ARG TARGETARCH
RUN echo "Building for architecture: $TARGETARCH"
```

We won't dive deep into multi-architecture builds here -- there's an optional Deep Dive for that. But knowing the concept exists helps you understand why some official images support both `amd64` and `arm64` out of the box.

---

## Vulnerability Scanning Concepts

Before we close this chapter, a quick word on image security.

Every package in your image is a potential vulnerability. The smaller your image, the smaller the attack surface. But even a minimal `alpine` image gets security updates.

### Built-in Scanning

```bash
# Docker Desktop includes Scout scanning:
docker scout cves learn-ch02-app:optimized

# Or use Trivy (open source, very popular):
trivy image learn-ch02-app:optimized
```

### What Scanners Check

- Known CVEs in OS packages (from vulnerability databases)
- Known CVEs in language-specific dependencies (npm, pip, Go modules)
- Misconfigurations (running as root, exposed secrets)

### Practical Guidelines

1. **Start from minimal bases** -- `alpine`, `distroless`, or `scratch` have fewer packages to scan
2. **Pin your dependencies** -- lock files (`package-lock.json`, `go.sum`) make builds reproducible
3. **Update regularly** -- rebuild with fresh base images to pick up security patches
4. **Scan in CI** -- fail the build if critical vulnerabilities are found
5. **Don't ship build tools** -- multi-stage builds reduce the scannable surface by 90%+

You don't need to memorize scanner commands now. Just know that image scanning is a standard part of any production Docker workflow, and everything you've learned in this chapter (small images, multi-stage builds, no secrets in layers) directly reduces your vulnerability count.

---

## Summary: BuildKit Features

| Feature | What it does | When to use |
|---------|-------------|-------------|
| Cache mounts | Persist package manager caches across builds | Always (free speed boost) |
| Secret mounts | Mount credentials during build, never in layers | Private registries, API keys |
| SSH mounts | Use local SSH agent for git clone during build | Private repos |
| `ARG` | Build-time variables | Version selection, feature flags |
| Digest pinning | Lock base image to exact version | Production, CI/CD |
| Multi-platform | Build for multiple architectures | Deploying to mixed ARM/x86 environments |
| `docker scout` / `trivy` | Scan images for vulnerabilities | CI/CD pipelines, before production deploy |

---

## Key Takeaways

1. BuildKit is Docker's modern builder -- use `# syntax=docker/dockerfile:1` to enable all features
2. Cache mounts (`--mount=type=cache`) persist package caches across builds, dramatically speeding up dependency installs
3. Secret mounts (`--mount=type=secret`) keep credentials out of image layers -- never `COPY` secrets into a Dockerfile
4. Pin base images by digest (`@sha256:...`) for reproducible production builds
5. Vulnerability scanning is a standard practice -- smaller images = smaller attack surface
6. Multi-platform builds exist for when you need to target both `amd64` and `arm64`

---

You now have the full picture of modern Docker image building. Let's put it to work in the challenges.

**First challenge:** [Optimize the Bloated Image](../challenges/01-optimize-bloated-image.md)
