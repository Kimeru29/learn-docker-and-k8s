# Challenge 7.4: The Stale Image

> "I deployed the fix 20 minutes ago. The container is running. But the API is still returning the old response. I pushed the code, rebuilt, ran `docker compose up`... what am I missing?"
> — Developer, increasingly frustrated

---

## The Situation

A developer fixed a bug in the NoCappuccino API — a typo in the health endpoint response. They:

1. Fixed the code in `server.js`
2. Ran `docker compose up -d`
3. Checked the endpoint — the old (buggy) response is still there

They're sure they saved the file. They're sure they ran `docker compose up`. But the fix isn't showing up.

---

## Setup

Create the following files.

**`server.js`** — the "fixed" version with the correct response:

```javascript
const http = require('http');

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    // This is the FIXED version — "status" should be "ok"
    res.end(JSON.stringify({ status: 'ok', version: '2.0.0' }));
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API v2.0.0\n');
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});

server.listen(3000, () => {
  console.log('NoCappuccino API v2.0.0 started on port 3000');
});
```

**`Dockerfile`**:

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY server.js .

CMD ["node", "server.js"]
```

**Step 1: First, build and run the "old" (buggy) version.**

Before creating the files above, create an initial "buggy" `server.js`:

```javascript
const http = require('http');

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    // BUG: "staus" instead of "status"
    res.end(JSON.stringify({ staus: 'ok', version: '1.0.0' }));
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API v1.0.0\n');
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});

server.listen(3000, () => {
  console.log('NoCappuccino API v1.0.0 started on port 3000');
});
```

**`docker-compose.yml`**:

```yaml
name: learn-ch07

services:
  api:
    build: .
    ports:
      - "3000:3000"
    labels:
      app: learn-docker-k8s
      world: w02
```

**Workflow to reproduce the problem:**

```bash
# 1. Build and start with the buggy server.js (v1.0.0)
docker compose up -d --build

# 2. Verify it returns the buggy response
curl http://localhost:3000/health
# {"staus":"ok","version":"1.0.0"}  ← note the typo "staus"

# 3. Now update server.js to the fixed version (v2.0.0)
# (replace the file content with the fixed version above)

# 4. Run docker compose up again (WITHOUT --build)
docker compose up -d

# 5. Check the endpoint — it still returns the OLD response!
curl http://localhost:3000/health
# {"staus":"ok","version":"1.0.0"}  ← STILL the old version!
```

---

## Your Task

1. Reproduce the stale image problem using the workflow above
2. Diagnose *why* the updated code isn't showing up
3. Fix it so the API returns the new response with `"status": "ok"` and `"version": "2.0.0"`
4. Understand what `docker compose up -d` does differently from `docker compose up -d --build`

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The script checks:
1. The API container is running
2. `/health` returns `"version": "2.0.0"` (the fixed version)
3. `/health` returns `"status"` (not `"staus"`)

---

## Hints

<details>
<summary>Hint 1 — The key question</summary>

`docker compose up -d` starts containers. If the image already exists, it reuses the cached image. It does NOT rebuild the image automatically, even if the source files have changed.

The developer updated `server.js` on disk, but the Docker image still contains the old version of `server.js`. The image was built during step 1 and cached. Step 4 (`docker compose up -d`) sees that the image exists and starts a container from the cached (old) image.

How do you verify? Check the image creation time:

```bash
docker inspect learn-ch07-api --format '{{.Created}}'
```

If it was created hours ago, the image is stale.

</details>

<details>
<summary>Hint 2 — The flag</summary>

The `--build` flag forces Docker Compose to rebuild the image before starting:

```bash
docker compose up -d --build
```

This re-runs the Dockerfile, picks up the updated `server.js` via `COPY`, creates a new image, and starts a container with the new code.

Without `--build`:
```
docker compose up -d
→ Image exists? Yes (cached)
→ Use cached image
→ Container runs old code
```

With `--build`:
```
docker compose up -d --build
→ Run Dockerfile again
→ COPY picks up updated server.js
→ New image created
→ Container runs new code
```

</details>

<details>
<summary>Hint 3 — Multiple ways to fix</summary>

**Fix 1: Use --build** (most common)
```bash
docker compose up -d --build
```

**Fix 2: Explicitly rebuild then restart**
```bash
docker compose build api
docker compose up -d api
```

**Fix 3: Force recreate** (if the image was rebuilt but the container wasn't updated)
```bash
docker compose up -d --build --force-recreate
```

After fixing, verify:
```bash
curl http://localhost:3000/health
# {"status":"ok","version":"2.0.0"}  ← note: "status" not "staus"

curl http://localhost:3000/
# NoCappuccino API v2.0.0
```

</details>

---

## Post-Challenge Debrief

**What you did:** Diagnosed a stale Docker image that was serving old code despite the source file being updated. Fixed by rebuilding the image with `--build`.

**Why it works:** Docker images are immutable snapshots. Once built, the image contains a copy of the files at build time. Updating files on disk does not update the image. You must explicitly rebuild to pick up changes. `docker compose up -d` checks if an image exists — if it does, it reuses it without rebuilding.

**Real-world connection:** This is one of the most common "deployment" bugs. In CI/CD pipelines, the build step is always explicit. But in local development, developers often forget `--build` and spend 20 minutes debugging a fix that's "not working" — when the fix was never deployed in the first place.

**Interview angle:** "You deployed a fix but the old behavior is still showing. What do you check?" Strong answer: verify the image was rebuilt (check creation time with `docker inspect`), verify the container is using the new image (check image ID), and rebuild with `--build` if needed.

**Pro tip:** In development, consider using bind mounts for rapid iteration:
```yaml
services:
  api:
    build: .
    volumes:
      - ./server.js:/app/server.js    # changes reflect immediately
```
This bypasses the rebuild step entirely — changes to `server.js` on disk are immediately visible inside the container. Useful for development, but never for production.
