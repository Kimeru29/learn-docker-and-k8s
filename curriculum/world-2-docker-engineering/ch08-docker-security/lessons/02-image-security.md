# Lesson 8.2: Image Security

> "I ran `docker history` on our production image and found the database password in plain text. Layer 7. Created six months ago. Anyone who can pull this image can read our credentials."
> — Sarah, incident postmortem

---

## The Layer Problem

Docker images are built in layers. Each instruction in the Dockerfile creates a layer. **Layers are immutable and permanent.** Even if you delete a file in a later layer, the file still exists in the earlier layer.

```dockerfile
FROM ubuntu:24.04

# Layer 1: Copy the secret file
COPY .env /app/.env

# Layer 2: Oh no, delete it!
RUN rm /app/.env        # ← This does NOT remove it from Layer 1!
```

Anyone can see every layer:

```bash
docker history myimage --no-trunc
```

And extract files from any layer:

```bash
docker save myimage | tar -x
# Each layer is a tarball — you can find .env in the layer 1 tarball
```

---

## How Secrets Leak Into Images

### Leak 1: `ENV` with sensitive values

```dockerfile
# BAD: password permanently in image metadata
ENV DB_PASSWORD=hunter2
```

This is visible in `docker inspect` and `docker history`:

```bash
docker inspect myimage --format '{{json .Config.Env}}'
# [..., "DB_PASSWORD=hunter2", ...]
```

### Leak 2: `COPY` of secret files

```dockerfile
# BAD: .env file copied into image layer
COPY . /app/
# Even if you delete it later, it's in this layer forever
```

### Leak 3: Secrets in `RUN` commands

```dockerfile
# BAD: password visible in layer history
RUN echo "DB_PASSWORD=hunter2" >> /app/config
```

### Leak 4: Build arguments logged in history

```dockerfile
# CAUTION: ARG values appear in docker history
ARG DB_PASSWORD
RUN echo "Using password: $DB_PASSWORD"
```

`docker history --no-trunc` will show the `ARG` value if used in a `RUN` command.

---

## Fix 1: Never Put Secrets in Images

The fundamental rule: **secrets belong at runtime, not build time.**

```yaml
# docker-compose.yml — secrets injected at runtime
services:
  backend:
    build: ./backend
    environment:
      DB_PASSWORD: ${DB_PASSWORD}     # from .env file
```

The password exists only in the running container's environment, not in the image.

---

## Fix 2: `.dockerignore`

Prevent sensitive files from entering the build context:

```
# .dockerignore
.env
.env.*
*.key
*.pem
secrets/
.git
node_modules
```

Without `.dockerignore`, `COPY . /app/` copies everything — including `.env`, `.git` history, `node_modules`, SSH keys, and anything else in the directory.

```bash
# Check your build context size
docker build . 2>&1 | head -1
# Sending build context to Docker daemon  1.5GB   ← too big!
# After .dockerignore:
# Sending build context to Docker daemon  5.2MB   ← much better
```

---

## Fix 3: Multi-Stage Builds as a Security Boundary

Multi-stage builds aren't just for size optimization — they're a security boundary. Secrets used during build (API keys for private registries, SSH keys for private repos) stay in the build stage and never reach the final image.

```dockerfile
# Stage 1: Build (has secrets, tools, source code)
FROM node:20 AS builder
WORKDIR /app

# This private npm token is needed to install private packages
ARG NPM_TOKEN
RUN echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc

COPY package*.json ./
RUN npm install

# Remove the token
RUN rm .npmrc

COPY . .
RUN npm run build

# Stage 2: Production (clean — no secrets, no build tools)
FROM node:20-alpine
WORKDIR /app

# Only copy the built artifacts — no source, no .npmrc, no node_modules from build
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

USER node
CMD ["node", "dist/server.js"]
```

The final image contains only `dist/`, `node_modules/`, and `package.json`. The NPM token, source code, and build tools are all discarded with the builder stage.

---

## Fix 4: BuildKit Secret Mounts (Modern Approach)

Docker BuildKit supports mounting secrets during build without baking them into layers:

```dockerfile
# syntax=docker/dockerfile:1

FROM node:20-alpine
WORKDIR /app

# Mount the secret file during this RUN — it's never saved to a layer
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) && \
    echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc && \
    npm install && \
    rm .npmrc

COPY . .
CMD ["node", "server.js"]
```

Pass the secret during build:

```bash
docker build --secret id=npm_token,src=.npm_token.txt .
```

The secret is available during the `RUN` step but never written to the image layer. This is the most secure approach for build-time secrets.

---

## Base Image Selection

The base image is the foundation of your security posture.

### Image Size and Attack Surface

| Base Image | Size | Packages | Attack Surface |
|-----------|------|----------|---------------|
| `ubuntu:24.04` | ~78 MB | Full package manager, many utils | Large |
| `debian:bookworm-slim` | ~75 MB | Minimal Debian, some utils | Medium |
| `alpine:3.21` | ~7 MB | Minimal, musl libc, no bloat | Small |
| `distroless` | ~2-20 MB | No shell, no package manager | Very small |
| `scratch` | 0 MB | Nothing — just the kernel | Minimal possible |

### Recommendations

| Use Case | Recommended Base | Why |
|----------|-----------------|-----|
| Node.js apps | `node:20-alpine` | Small, well-supported, includes `node` user |
| Python apps | `python:3.12-slim` | Smaller than full, has pip |
| Go apps | `scratch` or `distroless` | Go compiles to static binaries |
| Java apps | `eclipse-temurin:21-jre-alpine` | JRE only, no JDK |
| Generic | `alpine:3.21` | Smallest general-purpose |

### Distroless Images

Google's [distroless](https://github.com/GoogleContainerTools/distroless) images contain only your application and its runtime dependencies. No shell, no package manager, no ls, no cat.

```dockerfile
FROM node:20 AS builder
WORKDIR /app
COPY . .
RUN npm install --omit=dev

FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=builder /app .
CMD ["server.js"]
```

Without a shell, an attacker who gains code execution has far fewer tools to work with. The downside: debugging is harder (you can't `docker exec` into a shell).

---

## Vulnerability Scanning

### Docker Scout (built into Docker Desktop)

```bash
# Scan an image for known vulnerabilities
docker scout cves myimage

# Quick overview
docker scout quickview myimage
```

### Trivy (open source)

```bash
# Install: brew install trivy (or see trivy docs)
trivy image myimage
```

### What Scanners Check

- Known CVEs in OS packages (e.g., OpenSSL vulnerabilities)
- Known CVEs in language packages (npm, pip, Maven)
- Configuration issues (running as root, no health check)
- Secret detection in layers

### When to Scan

1. **During CI/CD:** Scan every image before pushing to the registry
2. **On schedule:** Rescan existing images for newly discovered CVEs
3. **Before promotion:** Scan before deploying to production

---

## Image Signing (Conceptual)

Image signing ensures that the image you pull is the same one that was pushed — no tampering in transit or in the registry.

- **Docker Content Trust (DCT):** Built into Docker. Uses Notary for signing.
- **Cosign (Sigstore):** Modern approach. Used by many open-source projects.

```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1
docker push myimage   # signs automatically
docker pull myimage   # verifies signature
```

This is beyond the scope of this chapter but worth knowing about for production deployments.

---

## Summary

- **Secrets in image layers are permanent** — deleting a file in a later layer doesn't remove it from earlier layers
- **Never use `ENV` for passwords** — they're visible in `docker inspect` and `docker history`
- **Use `.dockerignore`** to prevent sensitive files from entering the build context
- **Multi-stage builds** create a security boundary — build-stage secrets don't reach the final image
- **BuildKit secret mounts** (`--mount=type=secret`) are the most secure way to use secrets during build
- **Choose minimal base images** — smaller image = smaller attack surface
- **Scan images** for known vulnerabilities with Docker Scout, Trivy, or similar tools
- **Inject secrets at runtime** via environment variables, mounted files, or secret management tools

Next: the container is non-root with clean layers. But what about runtime security — capabilities, read-only filesystems, and the Docker socket?
