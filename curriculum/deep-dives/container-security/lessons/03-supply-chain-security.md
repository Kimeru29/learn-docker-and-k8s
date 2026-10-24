# Lesson 03: Supply Chain Security

> "You can harden your container all you want, but if the base image itself is compromised, none of it matters. Supply chain security is about trusting what you run."
> — Sarah

---

## The Supply Chain Problem

When you write `FROM node:20-alpine` in a Dockerfile, you're trusting:
- The Docker Hub registry to serve the correct image
- The `node` maintainers to build a clean image
- The Alpine Linux team to provide a secure base
- Every dependency in the Node.js ecosystem
- That nobody tampered with the image in transit

A **supply chain attack** compromises any link in that chain. Real-world examples:
- **Event-stream (2018):** A popular npm package was taken over and injected with cryptocurrency-stealing malware
- **SolarWinds (2020):** Build system compromised, malicious updates pushed to thousands of organizations
- **Codecov (2021):** CI tool's Docker image was modified to exfiltrate secrets
- **Log4Shell (2021):** Critical vulnerability in a ubiquitous Java library, present in millions of containers

---

## Vulnerability Scanning

### What it scans

Vulnerability scanners check container images against databases of known vulnerabilities (CVEs):

```
Image layers
    │
    ▼
Scanner identifies:
  - OS packages (apk, apt, yum)
  - Language packages (npm, pip, gems, Maven)
  - Shared libraries
    │
    ▼
Matches against CVE databases:
  - NVD (National Vulnerability Database)
  - Alpine SecDB
  - Debian Security Tracker
  - GitHub Advisory Database
    │
    ▼
Report: CVE ID, severity, affected package, fixed version
```

### Trivy — Open-source scanner

[Trivy](https://github.com/aquasecurity/trivy) is the most popular open-source container scanner.

```bash
# Install Trivy (multiple options):

# macOS:
brew install trivy

# Docker (no install needed):
docker run --rm aquasec/trivy image nginx:alpine

# Or pull and scan a specific image:
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image learn-ch01-app:v1
```

### Reading scan results

```bash
trivy image nginx:1.24
```

```
nginx:1.24 (debian 12.4)
═════════════════════════

Total: 42 (UNKNOWN: 0, LOW: 18, MEDIUM: 15, HIGH: 7, CRITICAL: 2)

┌──────────────────┬────────────────┬──────────┬───────────────────┬───────────────┬─────────────────────────────────┐
│     Library      │ Vulnerability  │ Severity │ Installed Version │ Fixed Version │            Title                │
├──────────────────┼────────────────┼──────────┼───────────────────┼───────────────┼─────────────────────────────────┤
│ libssl3          │ CVE-2024-XXXXX │ CRITICAL │ 3.0.11-1          │ 3.0.13-1      │ OpenSSL: Buffer overflow in ... │
│ libcurl4         │ CVE-2024-YYYYY │ HIGH     │ 7.88.1-10         │ 7.88.1-10+d12 │ curl: Use after free in ...     │
│ zlib1g           │ CVE-2023-ZZZZZ │ MEDIUM   │ 1.2.13-1          │ 1.2.13-1+deb  │ zlib: heap buffer overflow ...  │
└──────────────────┴────────────────┴──────────┴───────────────────┴───────────────┴─────────────────────────────────┘
```

### Severity levels

| Severity | What it means | Action |
|----------|--------------|--------|
| **CRITICAL** | Remote code execution, data breach, trivially exploitable | Fix immediately |
| **HIGH** | Significant impact, exploitation possible with some effort | Fix within days |
| **MEDIUM** | Limited impact or harder to exploit | Fix in next release |
| **LOW** | Minimal impact, unlikely exploitation | Fix when convenient |

### Scanning in CI

```yaml
# GitHub Actions example:
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:${{ github.sha }}'
    exit-code: '1'              # Fail the build on findings
    severity: 'CRITICAL,HIGH'   # Only fail on critical/high
```

### Other scanners

| Scanner | Type | Notes |
|---------|------|-------|
| **Trivy** | Open-source | Most popular, scans images + filesystems + repos |
| **Grype** | Open-source | Anchore's scanner, fast, good SBOM integration |
| **Snyk** | Commercial (free tier) | Deep language package analysis |
| **Docker Scout** | Docker's built-in | `docker scout cves <image>` |
| **AWS ECR scanning** | Cloud-native | Automatic scanning in ECR |

---

## Fixing Vulnerabilities

### Strategy 1: Update the base image

Most vulnerabilities come from the base image's OS packages:

```dockerfile
# Before: old base with known CVEs
FROM node:18.12-bullseye

# After: updated base
FROM node:20-bookworm-slim
```

Using `-slim` or `-alpine` variants reduces the attack surface (fewer packages = fewer CVEs).

### Strategy 2: Update dependencies

```bash
# Check for outdated packages:
npm audit          # Node.js
pip-audit          # Python
dotnet list package --vulnerable  # .NET
```

### Strategy 3: Use distroless or scratch images

```dockerfile
# Distroless — contains only your app and its runtime, no shell, no package manager:
FROM gcr.io/distroless/nodejs20-debian12
COPY --from=build /app /app
CMD ["server.js"]

# Scratch — completely empty, for statically compiled binaries:
FROM scratch
COPY --from=build /app/server /server
ENTRYPOINT ["/server"]
```

Fewer components = fewer vulnerabilities = smaller attack surface.

---

## Image Signing with Cosign

### Why sign images

Without signing, you trust that the image in the registry is the one you built. But registries can be compromised, images can be tampered with, and tags can be overwritten.

**Image signing** proves:
- The image was built by a trusted party
- The image hasn't been modified since it was signed
- The image matches a specific build pipeline

### Cosign basics

[Cosign](https://github.com/sigstore/cosign) is the standard tool for container image signing:

```bash
# Install:
brew install cosign   # macOS
# or: go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# Generate a key pair:
cosign generate-key-pair
# Creates cosign.key (private) and cosign.pub (public)

# Sign an image (after pushing to a registry):
cosign sign --key cosign.key myregistry.com/myapp:v1.0

# Verify a signature:
cosign verify --key cosign.pub myregistry.com/myapp:v1.0
```

### Keyless signing with Sigstore

Cosign supports **keyless signing** using your identity (GitHub, Google, Microsoft):

```bash
# Sign using your GitHub identity (no keys to manage):
cosign sign myregistry.com/myapp:v1.0
# Opens browser for OIDC authentication
# Signature is recorded in Rekor transparency log

# Verify:
cosign verify \
  --certificate-identity=user@example.com \
  --certificate-oidc-issuer=https://github.com/login/oauth \
  myregistry.com/myapp:v1.0
```

### Docker Content Trust (DCT)

Docker's built-in signing mechanism:

```bash
# Enable Docker Content Trust:
export DOCKER_CONTENT_TRUST=1

# Now docker pull and docker push require signed images:
docker pull nginx:latest
# If the image isn't signed, this fails
```

DCT uses Notary under the hood. Cosign is newer and more widely adopted.

---

## SBOM — Software Bill of Materials

An **SBOM** is a complete inventory of everything in your image: OS packages, language libraries, their versions, and their licenses.

### Why SBOMs matter

- **Incident response:** When a new CVE drops, quickly check if any of your images are affected
- **Compliance:** Regulations (like the US Executive Order on Cybersecurity) increasingly require SBOMs
- **License compliance:** Know what licenses your dependencies use

### Generating SBOMs

```bash
# Using Trivy:
trivy image --format spdx-json --output sbom.json nginx:alpine

# Using Syft (Anchore):
syft nginx:alpine -o spdx-json > sbom.json

# Using Docker:
docker sbom nginx:alpine
```

### SBOM formats

| Format | Organization | Notes |
|--------|-------------|-------|
| **SPDX** | Linux Foundation | ISO standard, widely adopted |
| **CycloneDX** | OWASP | Security-focused, supports VEX |
| **Syft JSON** | Anchore | Anchore's native format |

---

## Trusted Base Images

### Choosing good base images

| Base Image | Size | Packages | CVE Surface | Best For |
|-----------|------|----------|-------------|----------|
| `ubuntu:22.04` | ~77MB | ~100 | Medium | General purpose |
| `debian:bookworm-slim` | ~52MB | ~80 | Medium | General purpose, smaller |
| `alpine:3.19` | ~7MB | ~15 | Low | Small images, musl libc |
| `distroless` | ~20MB | ~5 | Very low | Production, no shell |
| `scratch` | 0B | 0 | None | Static binaries only |

### Base image best practices

1. **Pin versions:** `FROM node:20.11.0-alpine3.19` not `FROM node:latest`
2. **Use official images:** They're maintained and scanned by Docker
3. **Prefer slim/alpine:** Fewer packages = fewer CVEs
4. **Update regularly:** Set up automated base image updates (Dependabot, Renovate)
5. **Scan before deploy:** Make scanning a gate in your CI pipeline

---

## Registry Security

- **Use private registries** for your images (Docker Hub, ECR, GCR, ACR, Harbor)
- **Enable vulnerability scanning** on the registry (most cloud registries support this)
- **Use access controls** — not everyone should be able to push images
- **Enable immutable tags** — prevent tag overwriting (e.g., `v1.0` can't be replaced)
- **Set up image promotion** — images must pass scanning before promotion to production registry

---

## Summary

- Vulnerability scanning (Trivy, Grype) finds known CVEs in your images
- Fix vulnerabilities by updating base images, dependencies, or switching to distroless/scratch
- Sign images with cosign to prove provenance and integrity
- SBOMs inventory everything in your images — critical for incident response
- Choose minimal, pinned, official base images
- Make scanning and signing part of your CI pipeline, not an afterthought

---

**Next:** Time for the challenges. Head to [Custom Seccomp Profile](../challenges/01-custom-seccomp.md).
