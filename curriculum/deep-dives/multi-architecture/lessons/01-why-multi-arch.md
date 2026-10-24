# Lesson 01: Why Multi-Arch Matters

> "The first time someone on an M1 Mac built an image, pushed it to staging, and the CI server choked on it — that was a fun afternoon. Let me explain what happened."
> — Sarah

---

## Images Are Architecture-Specific

A Docker image contains compiled binaries. Compiled binaries are built for a specific CPU architecture. An ARM64 binary cannot run on an AMD64 processor, and vice versa — they use entirely different instruction sets.

```
Your M1 Mac (ARM64)          Your CI server (AMD64)
┌─────────────────┐          ┌─────────────────┐
│  docker build   │          │  docker run      │
│  → ARM64 binary │          │  → expects AMD64 │
│  → ARM64 image  │──push──▶│  → CRASH         │
└─────────────────┘          └─────────────────┘
```

When you run `docker build` on an M1 Mac, the resulting image contains ARM64 binaries. Pull that image on an x86 server and you get:

```
exec format error
```

Or worse — Docker might silently use QEMU emulation, making everything 5-10x slower with no warning.

---

## The Two Architectures That Matter

For most teams, two architectures cover 99% of use cases:

| Architecture | Also known as | Where you see it |
|-------------|---------------|-----------------|
| **AMD64** | x86_64, x64, Intel 64 | Most servers, Intel/AMD desktops, CI runners, cloud instances |
| **ARM64** | aarch64, ARMv8 | Apple Silicon (M1/M2/M3/M4), AWS Graviton, Azure Arm VMs, Raspberry Pi 4+ |

Other architectures exist (arm/v7 for older Raspberry Pis, s390x for IBM mainframes, ppc64le for IBM Power) but are niche.

---

## The Apple Silicon Problem

Before 2020, almost everyone built on AMD64. Images "just worked" everywhere because the CI server, staging, and production all ran the same architecture.

Apple Silicon changed everything:
- **Developer laptops** → ARM64 (M1/M2/M3/M4 Macs)
- **CI servers** → AMD64 (GitHub Actions, Jenkins, most cloud runners)
- **Production servers** → AMD64 (most cloud instances) OR ARM64 (Graviton, cost-optimized)

A team of 5 developers on Apple Silicon can build images all day that fail on every CI server and every production deployment.

---

## How Docker Handles Architectures

### What happens when you `docker pull`

When you run `docker pull nginx`, Docker doesn't pull "the" nginx image — it pulls the one that matches your platform.

Docker Hub stores images as **manifest lists** (also called **image indexes**). A manifest list is a JSON document that maps platform/architecture pairs to specific image digests:

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:aaa...",
      "platform": {
        "architecture": "amd64",
        "os": "linux"
      }
    },
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:bbb...",
      "platform": {
        "architecture": "arm64",
        "os": "linux"
      }
    }
  ]
}
```

Docker detects your platform, finds the matching entry, and pulls that specific image. This happens transparently — you don't notice unless something goes wrong.

### Inspecting manifest lists

```bash
# See the manifest list for an image:
docker manifest inspect nginx:alpine

# Or with more detail:
docker manifest inspect --verbose nginx:alpine
```

You'll see entries for `linux/amd64`, `linux/arm64`, `linux/arm/v7`, etc. The official nginx image supports many architectures.

### Checking your current platform

```bash
# What architecture are you on?
docker info --format '{{.Architecture}}'
# aarch64 (ARM64) or x86_64 (AMD64)

# What platform does your image target?
docker inspect nginx:alpine --format '{{.Architecture}}'
```

---

## What Happens When Architectures Don't Match

### Scenario 1: No matching manifest

If you try to pull an image that doesn't have a manifest for your architecture:

```bash
# Hypothetical AMD64-only image on an ARM64 machine:
docker pull --platform linux/amd64 some-amd64-only-image
# WARNING: image with reference was found but does not match the specified platform
```

### Scenario 2: QEMU emulation (Docker Desktop)

Docker Desktop includes QEMU emulation. If you pull an image for a different architecture, it may run via emulation:

```bash
# On an M1 Mac, run an AMD64 image:
docker run --platform linux/amd64 alpine uname -m
# x86_64  (emulated — works but slow)

# On an AMD64 machine, run an ARM64 image:
docker run --platform linux/arm64 alpine uname -m
# aarch64  (emulated — works but slow)
```

This emulation is convenient for development but has significant performance overhead (5-10x slower for CPU-intensive operations). It's not suitable for production.

### Scenario 3: exec format error

On Linux without QEMU configured, running an image for the wrong architecture gives:

```
standard_init_linux.go: exec user process caused "exec format error"
```

The kernel can't execute the binary because it's for a different CPU architecture.

---

## How Docker Serves the Right Image

The full flow:

```
docker pull nginx:alpine
    │
    ▼
Registry returns manifest list for "nginx:alpine"
    │
    ▼
Docker checks local platform (e.g., linux/arm64)
    │
    ▼
Finds matching entry in manifest list
    │
    ▼
Pulls the ARM64-specific image layers
    │
    ▼
Stores locally with the tag "nginx:alpine"
```

Two developers on different architectures can both run `docker pull nginx:alpine` and get different underlying images — both tagged `nginx:alpine` locally but containing different binaries.

---

## Practical: Compare Architectures

```bash
# Check what you're running:
uname -m

# See the manifest list for a popular image:
docker manifest inspect --verbose python:3.12-slim 2>/dev/null | head -30

# Pull for a specific platform:
docker pull --platform linux/amd64 alpine:latest
docker pull --platform linux/arm64 alpine:latest

# Compare sizes (they may differ slightly):
docker images alpine --format "{{.Repository}}:{{.Tag}} {{.Size}}"
```

---

## Summary

- Container images contain compiled binaries — they're architecture-specific
- An ARM64 image won't run natively on AMD64 (and vice versa)
- Docker Hub uses **manifest lists** to serve the right image for each platform
- Apple Silicon made this a real problem for most teams
- QEMU emulation works but is 5-10x slower — fine for dev, not for production
- `exec format error` means "wrong architecture, no emulation available"

---

**Next:** [Buildx Multi-Platform](02-buildx-multi-platform.md) — Building images for multiple architectures
