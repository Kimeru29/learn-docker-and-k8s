# Lesson 02: Buildx Multi-Platform Builds

> "buildx is the tool that makes multi-arch images practical. Without it, you'd need a build machine for every target architecture. With it, you can build for ARM64 and AMD64 from a single command."
> — Sarah

---

## What Is docker buildx?

`docker buildx` is an extended build command that uses **BuildKit** as the build backend. It supports features that the legacy `docker build` doesn't, most importantly: **multi-platform builds**.

BuildKit can build an image for a different architecture than the host by using:
1. **QEMU emulation** — Run the build steps in an emulated environment
2. **Cross-compilation** — Use the host's native tools to compile for a foreign target
3. **Remote builders** — Build on machines with different architectures

---

## Setting Up a Multi-Platform Builder

The default builder doesn't support multi-platform. You need to create one:

```bash
# Create a new builder with multi-platform support:
docker buildx create --name learn-multiarch --use --bootstrap

# Verify it supports multiple platforms:
docker buildx inspect learn-multiarch
```

You'll see output like:

```
Name:          learn-multiarch
Driver:        docker-container
Platforms:     linux/amd64, linux/arm64, linux/arm/v7, linux/386, ...
```

> **Docker Desktop users:** QEMU is already installed and configured. On Linux, you may need to install QEMU and register the binary formats:
> ```bash
> # Install QEMU static binaries and register with binfmt_misc:
> docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
> ```

---

## Building for a Single Foreign Platform

Build an image for a specific target architecture:

```bash
# Build for ARM64 (even if you're on AMD64):
docker buildx build --platform linux/arm64 -t learn-dd-multi-arm64:v1 \
  --label app=learn-docker-k8s --label track=deep-dive \
  --load .

# Build for AMD64 (even if you're on ARM64):
docker buildx build --platform linux/amd64 -t learn-dd-multi-amd64:v1 \
  --label app=learn-docker-k8s --label track=deep-dive \
  --load .
```

The `--load` flag loads the image into your local Docker daemon. Note: `--load` only works for a single platform at a time.

---

## Building for Multiple Platforms at Once

The real power of buildx is building for multiple platforms in a single command:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myregistry.com/myapp:v1.0 \
  --push .
```

This builds the image twice (once for each platform), creates a manifest list, and pushes everything to the registry in one operation.

> **Important:** `--push` is required when building for multiple platforms. You can't `--load` a multi-platform image into the local daemon — the local daemon can only hold one architecture at a time. You need a registry.

### Using a local registry for testing

If you don't have a remote registry, spin up a local one:

```bash
# Start a local registry:
docker run -d --name learn-dd-registry \
  --label app=learn-docker-k8s --label track=deep-dive \
  -p 5555:5000 \
  registry:2

# Build and push multi-platform:
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t localhost:5555/myapp:v1.0 \
  --push .

# Inspect the manifest list:
docker manifest inspect localhost:5555/myapp:v1.0
```

---

## QEMU Emulation vs Cross-Compilation

### QEMU emulation (easier, slower)

QEMU emulates a foreign CPU instruction by instruction. Every `RUN` step in the Dockerfile runs in the emulated environment:

```dockerfile
FROM alpine:3.19
RUN apk add --no-cache python3    # This runs under QEMU emulation for foreign arch
COPY app.py /app/
CMD ["python3", "/app/app.py"]
```

- **Pros:** Works with any Dockerfile. No code changes needed.
- **Cons:** 5-10x slower for CPU-intensive operations. `RUN npm install` or `RUN cargo build` can take forever.

### Native cross-compilation (harder, faster)

For compiled languages (Go, Rust, C), you can cross-compile natively — the host CPU does the work, targeting the foreign architecture:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS build

# These are set by buildx automatically:
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .

# Cross-compile using Go's built-in support:
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /server .

FROM alpine:3.19
COPY --from=build /server /server
ENTRYPOINT ["/server"]
```

Key elements:
- `FROM --platform=$BUILDPLATFORM` — Run the build stage on the host's native architecture (fast)
- `ARG TARGETOS` / `ARG TARGETARCH` — Buildx sets these automatically to the target platform
- `CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH` — Go's cross-compilation (no QEMU needed)

The final stage (`FROM alpine:3.19`) uses the target platform, but it only copies a pre-built binary — no emulation needed for that.

- **Pros:** Near-native build speed. No QEMU overhead.
- **Cons:** Only works for languages with cross-compilation support. CGO complicates things in Go.

### Buildx automatic variables

Buildx provides several automatic build arguments:

| Variable | Example | Description |
|----------|---------|-------------|
| `BUILDPLATFORM` | `linux/amd64` | The platform of the build machine |
| `TARGETPLATFORM` | `linux/arm64` | The platform being built for |
| `BUILDOS` | `linux` | OS of the build machine |
| `BUILDARCH` | `amd64` | Architecture of the build machine |
| `TARGETOS` | `linux` | Target OS |
| `TARGETARCH` | `arm64` | Target architecture |
| `TARGETVARIANT` | `v8` | Target variant (e.g., ARM version) |

---

## Platform-Specific Base Images

Some base images behave differently on different architectures:

```dockerfile
# Alpine uses musl libc — works on both amd64 and arm64
FROM node:20-alpine

# Debian/Ubuntu use glibc — also works on both, but heavier
FROM node:20-bookworm-slim

# Some images are architecture-specific:
# nvidia/cuda — AMD64 only (GPU containers)
# raspbian — ARM only
```

When a base image supports multiple architectures, Docker automatically pulls the right one. When it doesn't, your build fails on the unsupported architecture.

---

## Pushing Multi-Arch to a Registry

The typical workflow:

```bash
# 1. Create/use a multi-platform builder:
docker buildx use learn-multiarch

# 2. Build and push (creates a manifest list in the registry):
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myregistry.com/nocappuccino-api:v2.0 \
  --push .

# 3. Verify the manifest list:
docker manifest inspect myregistry.com/nocappuccino-api:v2.0

# 4. Users on any architecture just pull normally:
docker pull myregistry.com/nocappuccino-api:v2.0
# Docker selects the right architecture automatically
```

---

## Cleanup

```bash
docker buildx rm learn-multiarch 2>/dev/null
docker rm -f learn-dd-registry 2>/dev/null
```

---

## Summary

- `docker buildx` enables multi-platform builds using BuildKit
- Create a dedicated builder with `docker buildx create` for multi-platform support
- Build for multiple platforms with `--platform linux/amd64,linux/arm64`
- QEMU emulation works for any Dockerfile but is slow
- Cross-compilation (Go, Rust) is fast but requires Dockerfile changes
- Use `FROM --platform=$BUILDPLATFORM` and `ARG TARGETARCH` for cross-compilation
- Multi-platform builds require `--push` to a registry (can't `--load` multiple architectures)

---

**Next:** [Testing and CI](03-testing-and-ci.md) — Making sure your multi-arch images actually work everywhere
