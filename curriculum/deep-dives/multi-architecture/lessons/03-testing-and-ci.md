# Lesson 03: Testing and CI

> "Building for multiple architectures is only half the battle. You also need to test on both, and your CI pipeline needs to handle it cleanly."
> — Sarah

---

## Testing Multi-Arch Images

### Testing locally with --platform

You can test an image for a foreign architecture on your machine using QEMU:

```bash
# On an ARM64 Mac, test the AMD64 build:
docker run --rm --platform linux/amd64 myapp:v1.0 echo "AMD64 works"

# On an AMD64 machine, test the ARM64 build:
docker run --rm --platform linux/arm64 myapp:v1.0 echo "ARM64 works"
```

This runs under emulation — it verifies the image works but runs slowly.

### Detecting architecture inside a container

Sometimes your application needs to know what architecture it's running on:

```bash
# Via uname:
docker run --rm alpine uname -m
# aarch64 (ARM64) or x86_64 (AMD64)

# Via /proc/cpuinfo:
docker run --rm alpine head -5 /proc/cpuinfo
```

### Architecture detection in Dockerfiles

Use `TARGETARCH` (set by buildx) to make architecture-specific decisions:

```dockerfile
FROM --platform=$BUILDPLATFORM alpine:3.19 AS download

ARG TARGETARCH

# Download architecture-specific binary:
RUN wget -O /tool https://example.com/tool-${TARGETARCH} && chmod +x /tool

# Or with conditional logic:
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      wget -O /tool https://example.com/tool-x86_64; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      wget -O /tool https://example.com/tool-aarch64; \
    fi && chmod +x /tool
```

---

## CI Pipeline Strategies

### Strategy 1: Build all platforms in one job

The simplest approach — one CI job builds both architectures:

```yaml
# GitHub Actions
name: Build Multi-Arch Image
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

- **Pros:** Simple, one job handles everything
- **Cons:** ARM64 build runs under QEMU (slow for heavy builds)

### Strategy 2: Parallel native builds, then merge

For faster builds, use architecture-native runners and merge the manifests:

```yaml
name: Build Multi-Arch (Parallel)
on: [push]

jobs:
  build-amd64:
    runs-on: ubuntu-latest     # Native AMD64
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          platforms: linux/amd64
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}-amd64

  build-arm64:
    runs-on: ubuntu-24.04-arm  # Native ARM64 runner
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          platforms: linux/arm64
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}-arm64

  merge:
    needs: [build-amd64, build-arm64]
    runs-on: ubuntu-latest
    steps:
      - name: Create manifest list
        run: |
          docker manifest create \
            ghcr.io/${{ github.repository }}:${{ github.sha }} \
            ghcr.io/${{ github.repository }}:${{ github.sha }}-amd64 \
            ghcr.io/${{ github.repository }}:${{ github.sha }}-arm64
          docker manifest push ghcr.io/${{ github.repository }}:${{ github.sha }}
```

- **Pros:** Both builds run natively at full speed
- **Cons:** Requires ARM64 CI runners (not always available/free), more complex pipeline

### Strategy 3: Cross-compile (fastest)

For Go/Rust applications, cross-compile on a single AMD64 runner:

```yaml
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

With a cross-compilation Dockerfile (from the previous lesson), the actual compilation runs natively on AMD64 for both targets. Only the `FROM alpine` base layer needs the target platform — and that's just pulling pre-built layers from the registry.

---

## Build Caching for Multi-Arch

Multi-arch builds can be slow. Cache aggressively:

```yaml
# GitHub Actions cache:
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max

# Registry cache:
- uses: docker/build-push-action@v5
  with:
    cache-from: type=registry,ref=ghcr.io/myapp:cache
    cache-to: type=registry,ref=ghcr.io/myapp:cache,mode=max
```

The `mode=max` setting caches all layers, not just the final image layers. This is especially valuable for multi-stage builds where intermediate layers are reused.

---

## Common Pitfalls

### 1. Base image doesn't support ARM64

```dockerfile
# This might not have an ARM64 variant:
FROM some-niche-image:latest
```

**Fix:** Check the manifest list first: `docker manifest inspect some-niche-image:latest`

### 2. Architecture-specific dependencies

```dockerfile
# This downloads an x86_64 binary regardless of target arch:
RUN curl -L https://example.com/tool-x86_64 -o /usr/local/bin/tool
```

**Fix:** Use `TARGETARCH` to select the right binary:

```dockerfile
ARG TARGETARCH
RUN curl -L https://example.com/tool-${TARGETARCH} -o /usr/local/bin/tool
```

### 3. CGO in Go

Go's cross-compilation doesn't work when CGO is enabled (C dependencies):

```dockerfile
# This fails for cross-compilation with CGO:
RUN CGO_ENABLED=1 GOOS=linux GOARCH=arm64 go build .
```

**Fix:** Either disable CGO (`CGO_ENABLED=0`) or use QEMU for the build stage.

### 4. npm/pip install under QEMU

Native addons (e.g., `node-gyp`, compiled Python packages) are extremely slow under QEMU:

```dockerfile
RUN npm install  # This compiles native addons — glacial under QEMU
```

**Fix:** Use `FROM --platform=$BUILDPLATFORM` for the install stage and copy only the built artifacts, or accept the slower build time.

---

## Verifying Multi-Arch Images

After building and pushing, verify both architectures are available:

```bash
# Check the manifest list:
docker manifest inspect myregistry.com/myapp:v1.0

# Pull and run each platform:
docker run --rm --platform linux/amd64 myregistry.com/myapp:v1.0 uname -m
# x86_64

docker run --rm --platform linux/arm64 myregistry.com/myapp:v1.0 uname -m
# aarch64

# Check the architecture of a local image:
docker inspect myapp:v1.0 --format '{{.Architecture}}'
```

---

## Summary

- Test foreign architectures locally using `--platform` (runs under QEMU)
- Use `TARGETARCH` in Dockerfiles for architecture-specific decisions
- CI strategies: single-job QEMU (simple), parallel native (fast), cross-compilation (fastest)
- Cache aggressively — multi-arch builds multiply build time
- Watch for pitfalls: base images without ARM64 support, hardcoded binary URLs, CGO issues
- Always verify the manifest list after pushing a multi-arch image

---

**Next:** Time for the challenges. Head to [Detect and Fix](../challenges/01-detect-and-fix.md).
