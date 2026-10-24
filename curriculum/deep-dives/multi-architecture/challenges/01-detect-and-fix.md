# Challenge 01: Detect and Fix

> "Dave pushed an image from his new M2 MacBook. CI is failing with 'exec format error.' Your job: figure out what happened and fix it."
> — Sarah

---

## The Situation

Dave built the NoCappuccino API image on his ARM64 MacBook and pushed it. Now the staging server (AMD64) is failing to run it. The error is cryptic: `exec format error`.

You need to:
1. Detect the architecture mismatch
2. Rebuild the image for the correct platform
3. Verify it runs on the target architecture

---

## Setup

First, let's reproduce Dave's mistake — build an image for the "wrong" architecture:

```bash
mkdir -p /tmp/learn-dd-multi-detect
cat > /tmp/learn-dd-multi-detect/Dockerfile <<'EOF'
FROM alpine:3.19
RUN echo '#!/bin/sh' > /app.sh && \
    echo 'echo "NoCappuccino API running on $(uname -m)"' >> /app.sh && \
    chmod +x /app.sh
CMD ["/app.sh"]
EOF
```

Build for the "wrong" architecture (the one you're NOT on):

```bash
# Detect your current architecture and build for the OTHER one:
CURRENT_ARCH=$(uname -m)
if [ "$CURRENT_ARCH" = "x86_64" ]; then
  WRONG_ARCH="linux/arm64"
  RIGHT_ARCH="linux/amd64"
else
  WRONG_ARCH="linux/amd64"
  RIGHT_ARCH="linux/arm64"
fi

# Build for the wrong architecture (simulating Dave's mistake):
docker buildx build \
  --platform $WRONG_ARCH \
  -t learn-dd-multi-wrong:v1 \
  --label app=learn-docker-k8s --label track=deep-dive \
  --load \
  /tmp/learn-dd-multi-detect/
```

Try running it:

```bash
docker run --rm learn-dd-multi-wrong:v1
# Might get: exec format error
# Or it might run under QEMU emulation (Docker Desktop)
```

---

## Your Mission

### Part 1: Detect the problem

1. Inspect the "wrong" image to determine what architecture it was built for
2. Compare it to your host architecture
3. Confirm the mismatch

### Part 2: Fix it

4. Rebuild the image for your native architecture (or for `linux/amd64` specifically, since that's what "staging" runs)
5. Tag the fixed image as `learn-dd-multi-fixed:v1`
6. Run it and verify it outputs the correct architecture

### Part 3: Verify

7. Run the fixed container as `learn-dd-multi-fixed` (detached)

---

## Requirements

1. Image `learn-dd-multi-wrong:v1` must exist (the original broken image)
2. Image `learn-dd-multi-fixed:v1` must exist (your fix)
3. The fixed image must target a **different** architecture than the wrong image
4. Container `learn-dd-multi-fixed` must be running
5. Container must have labels `app=learn-docker-k8s` and `track=deep-dive`

---

## Success Criteria

```bash
bash curriculum/deep-dives/multi-architecture/challenges/verify.sh
```

---

## Hints

<details>
<summary>Hint 1 — Detecting the architecture</summary>

Use `docker inspect` to check what architecture an image was built for:

```
docker inspect learn-dd-multi-wrong:v1 --format '{{.Architecture}}'
```

Compare it with your host:
```
uname -m
```

If they're different, that's the mismatch.

</details>

<details>
<summary>Hint 2 — Rebuilding with the right platform</summary>

Use `docker buildx build --platform` to specify the correct target:

```
docker buildx build --platform linux/amd64 -t learn-dd-multi-fixed:v1 --load /tmp/learn-dd-multi-detect/
```

Or for your native platform:
```
docker build -t learn-dd-multi-fixed:v1 /tmp/learn-dd-multi-detect/
```

A regular `docker build` (without buildx) always builds for the native architecture.

</details>

<details>
<summary>Hint 3 — Running the fixed container</summary>

```
docker run -d --name learn-dd-multi-fixed \
  --label app=learn-docker-k8s --label track=deep-dive \
  learn-dd-multi-fixed:v1 sleep 3600
```

Verify it works:
```
docker exec learn-dd-multi-fixed /app.sh
```

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You detected an architecture mismatch using `docker inspect` to check the image's target architecture, then rebuilt the image with `--platform` targeting the correct architecture.

**Why it works:**
Docker images contain binaries compiled for a specific CPU architecture. When the image architecture doesn't match the host, the kernel can't execute the binary (exec format error). Rebuilding with the correct `--platform` flag produces an image with binaries matching the target CPU.

**Real-world connection:**
This exact scenario happens all the time now that development teams use Apple Silicon. A developer builds an image locally, pushes it, and it fails on CI or staging. The fix is either: always build with `--platform linux/amd64` in CI, or build multi-arch images. Most teams automate this in their CI pipeline.

**Interview angle:**
"A container fails with 'exec format error' — what's happening?" Answer: the image was built for a different CPU architecture. Check with `docker inspect --format '{{.Architecture}}'` and rebuild with the correct `--platform`.

**Pro tip:**
You can set a default platform in Docker's config to prevent accidentally building for the wrong architecture:
```json
// ~/.docker/config.json
{
  "experimental": "enabled",
  "platform": "linux/amd64"
}
```

</details>

---

## Cleanup

```bash
docker rm -f learn-dd-multi-fixed 2>/dev/null
docker rmi learn-dd-multi-wrong:v1 learn-dd-multi-fixed:v1 2>/dev/null
rm -rf /tmp/learn-dd-multi-detect
```
