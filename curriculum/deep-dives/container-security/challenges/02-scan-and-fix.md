# Challenge 02: Scan and Fix

> "You wouldn't deploy code without tests. Why would you deploy an image without scanning it? Let's find out what's lurking in one of our images."
> — Sarah

---

## The Situation

NoCappuccino has been running a web application using an older base image. Nobody has scanned it for vulnerabilities. Sarah suspects there are critical CVEs hiding in the OS packages and wants you to:

1. Scan the image
2. Identify the critical/high vulnerabilities
3. Create a fixed Dockerfile that eliminates the critical findings
4. Verify the fix by scanning the new image

---

## Setup

Create the vulnerable Dockerfile:

```bash
mkdir -p /tmp/learn-dd-sec-scan
cat > /tmp/learn-dd-sec-scan/Dockerfile <<'EOF'
FROM node:18-bullseye
WORKDIR /app
RUN echo '{"name":"nocappuccino-api","version":"1.0.0","main":"server.js"}' > package.json
RUN echo 'const http = require("http"); \
const server = http.createServer((req, res) => { \
  res.writeHead(200, {"Content-Type": "application/json"}); \
  res.end(JSON.stringify({status: "ok", service: "nocappuccino-api"})); \
}); \
server.listen(3000, () => console.log("Listening on 3000"));' > server.js
EXPOSE 3000
CMD ["node", "server.js"]
EOF
```

Build the vulnerable image:

```bash
docker build -t learn-dd-sec-vulnerable:v1 \
  --label app=learn-docker-k8s --label track=deep-dive \
  /tmp/learn-dd-sec-scan/
```

---

## Your Mission

### Part 1: Scan

Scan `learn-dd-sec-vulnerable:v1` for vulnerabilities using Trivy (or Docker Scout).

```bash
# Option A — Trivy (if installed):
trivy image learn-dd-sec-vulnerable:v1

# Option B — Trivy via Docker:
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image learn-dd-sec-vulnerable:v1

# Option C — Docker Scout (built into Docker):
docker scout cves learn-dd-sec-vulnerable:v1
```

Note the critical and high severity findings.

### Part 2: Fix

Create a new Dockerfile at `/tmp/learn-dd-sec-scan/Dockerfile.fixed` that eliminates the critical vulnerabilities. Strategies:

- Use a newer, smaller base image (e.g., `node:20-alpine` or `node:20-slim`)
- Remove unnecessary packages
- Use a non-root user

Build the fixed image:

```bash
docker build -t learn-dd-sec-fixed:v1 \
  --label app=learn-docker-k8s --label track=deep-dive \
  -f /tmp/learn-dd-sec-scan/Dockerfile.fixed \
  /tmp/learn-dd-sec-scan/
```

### Part 3: Verify

Run the fixed image and confirm it works:

```bash
docker run -d --name learn-dd-sec-fixed-app \
  --label app=learn-docker-k8s --label track=deep-dive \
  -p 3333:3000 \
  learn-dd-sec-fixed:v1
```

---

## Requirements

1. Image `learn-dd-sec-vulnerable:v1` must exist (the original scan target)
2. Image `learn-dd-sec-fixed:v1` must exist (your fixed version)
3. Fixed Dockerfile at `/tmp/learn-dd-sec-scan/Dockerfile.fixed`
4. The fixed image must use a different (newer/smaller) base image than `node:18-bullseye`
5. Container `learn-dd-sec-fixed-app` must be running
6. Port 3333 must respond with a JSON response containing `"status":"ok"`
7. The fixed image must be smaller than the vulnerable image

---

## Success Criteria

```bash
bash curriculum/deep-dives/container-security/challenges/verify.sh
```

---

## Hints

<details>
<summary>Hint 1 — Choosing a better base image</summary>

The original uses `node:18-bullseye` — a full Debian-based image with hundreds of OS packages. Consider:

- `node:20-alpine` — Alpine-based, much smaller (~180MB vs ~900MB), fewer packages
- `node:20-bookworm-slim` — Newer Debian, slim variant, fewer packages
- `node:20-slim` — Slim variant of the latest Debian-based Node image

Alpine-based images typically have far fewer CVEs because they have far fewer packages.

</details>

<details>
<summary>Hint 2 — Additional hardening</summary>

Beyond the base image, consider:
- Run as non-root: `USER node` (the official Node images include a `node` user)
- Use a multi-stage build if you need build tools but not in production
- Add `--no-cache` or `--no-install-recommends` to package installs

</details>

<details>
<summary>Hint 3 — Example fixed Dockerfile</summary>

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json server.js ./
USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

This switches to Alpine (much smaller, fewer CVEs), uses Node 20 (latest LTS), and runs as non-root.

Build with:
```
docker build -t learn-dd-sec-fixed:v1 \
  --label app=learn-docker-k8s --label track=deep-dive \
  -f /tmp/learn-dd-sec-scan/Dockerfile.fixed \
  /tmp/learn-dd-sec-scan/
```

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You scanned a container image for vulnerabilities, identified the root causes (old base image with many OS packages), and created a fixed image using a newer, smaller base with fewer CVEs.

**Why it works:**
Most container vulnerabilities come from OS packages in the base image, not from your application code. By switching from a full Debian image to an Alpine-based image (or slim variant), you dramatically reduce the number of packages — and therefore the number of potential vulnerabilities. Updating from Node 18 to Node 20 also picks up security patches in the Node runtime itself.

**Real-world connection:**
This is exactly what happens in production. Teams discover they're running images with critical CVEs because nobody set up scanning. The fix is usually straightforward: update the base image, update dependencies, scan again. The hard part is building the habit — making scanning part of CI and blocking deploys on critical findings.

**Interview angle:**
"How do you handle container image vulnerabilities in your pipeline?" Good answer: scan images in CI with Trivy/Grype, fail builds on critical/high CVEs, use minimal base images (alpine/distroless), automate base image updates with Dependabot/Renovate, and maintain an SBOM for incident response.

**Pro tip:**
Compare the image sizes: `docker images | grep learn-dd-sec`. The vulnerable image is likely 900MB+; the fixed Alpine image is under 200MB. Smaller images aren't just more secure — they pull faster, deploy faster, and use less disk. Security and efficiency align here.

</details>

---

## Cleanup

```bash
docker rm -f learn-dd-sec-fixed-app 2>/dev/null
docker rmi learn-dd-sec-vulnerable:v1 learn-dd-sec-fixed:v1 2>/dev/null
rm -rf /tmp/learn-dd-sec-scan
```
