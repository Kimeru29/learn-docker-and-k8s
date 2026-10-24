# Challenge 8.1: Harden the Container

> "The audit says: 'Container runs as root, has full capabilities, writable filesystem.' Your mission: fix all three without breaking the application."
> — Sarah

---

## The Situation

The NoCappuccino API is running in production with default Docker security settings. The security audit flagged three issues:

1. The container runs as root (UID 0)
2. The container has all default Linux capabilities
3. The root filesystem is writable — an attacker could install tools or modify code

Your job: harden the container so it runs as non-root, with no capabilities, and a read-only filesystem. The application must still work.

---

## Setup

Create the following files.

**`server.js`**:

```javascript
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const LOG_DIR = '/app/logs';

// Ensure log directory exists
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

const server = http.createServer((req, res) => {
  // Write access log
  const logLine = `${new Date().toISOString()} ${req.method} ${req.url}\n`;
  fs.appendFileSync(path.join(LOG_DIR, 'access.log'), logLine);

  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', user: process.env.USER || 'unknown' }));
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API\n');
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});

server.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
  console.log(`Running as UID: ${process.getuid()}, GID: ${process.getgid()}`);
});
```

**`package.json`**:

```json
{
  "name": "ch08-api",
  "version": "1.0.0",
  "dependencies": {}
}
```

**`Dockerfile`** (the insecure version):

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY package.json server.js ./

EXPOSE 3000
CMD ["node", "server.js"]
```

**`docker-compose.yml`** (the insecure version):

```yaml
name: learn-ch08

services:
  api:
    build: .
    ports:
      - "3000:3000"
    labels:
      app: learn-docker-k8s
      world: w02
```

---

## Your Task

Modify the `Dockerfile` and `docker-compose.yml` to:

1. **Run as non-root:** Add a non-root user and switch to it with `USER`. Fix any permission issues.
2. **Drop all capabilities:** Add `cap_drop: [ALL]` to the Compose service. Do not add any capabilities back.
3. **Read-only filesystem:** Set `read_only: true`. The app writes logs to `/app/logs` and needs `/tmp` — use `tmpfs` for these.

The application must still:
- Start and listen on port 3000
- Respond to `/health` with `{"status":"ok"}`
- Write access logs to `/app/logs/access.log`

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The script checks:
1. Container is running and `/health` responds
2. Container is NOT running as root (UID != 0)
3. All capabilities are dropped
4. Root filesystem is read-only
5. The app can still write logs (tmpfs mount)

---

## Hints

<details>
<summary>Hint 1 — Non-root user</summary>

The official Node.js Alpine image includes a `node` user (UID 1000). You can use it:

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY --chown=node:node package.json server.js ./
USER node
CMD ["node", "server.js"]
```

Or create your own:
```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
# ... copy files with --chown=appuser:appgroup
USER appuser
```

Make sure the app directory and log directory are owned by the non-root user.

</details>

<details>
<summary>Hint 2 — Capabilities and read-only filesystem</summary>

In `docker-compose.yml`:

```yaml
services:
  api:
    build: .
    ports:
      - "3000:3000"
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp
      - /app/logs
    labels:
      app: learn-docker-k8s
      world: w02
```

The `read_only: true` makes the entire root filesystem read-only. `tmpfs` creates in-memory writable directories for `/tmp` and `/app/logs`.

Since the app uses port 3000 (above 1024), no capabilities are needed — not even `NET_BIND_SERVICE`.

</details>

<details>
<summary>Hint 3 — Putting it together</summary>

**Dockerfile:**
```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY --chown=node:node package.json server.js ./

RUN mkdir -p /app/logs && chown node:node /app/logs

USER node

EXPOSE 3000
CMD ["node", "server.js"]
```

**docker-compose.yml:**
```yaml
name: learn-ch08

services:
  api:
    build: .
    ports:
      - "3000:3000"
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp
      - /app/logs
    security_opt:
      - no-new-privileges:true
    labels:
      app: learn-docker-k8s
      world: w02
```

Build and test:
```bash
docker compose up -d --build
curl http://localhost:3000/health
docker exec learn-ch08-api-1 whoami   # should NOT be root
```

</details>

---

## Post-Challenge Debrief

**What you did:** Hardened a container from default (root, full capabilities, writable filesystem) to production-ready (non-root, zero capabilities, read-only root filesystem with tmpfs for writable paths).

**Why it works:** Non-root prevents privilege escalation. Dropped capabilities remove kernel permissions the app doesn't need. Read-only filesystem prevents an attacker from modifying the application or installing tools. The combination significantly reduces the blast radius of a container compromise.

**Real-world connection:** Kubernetes PodSecurityStandards (`restricted` level) require all of these: non-root UID, no capability additions, read-only root filesystem. If you're deploying to a secured K8s cluster, your containers must meet these requirements or they'll be rejected.

**Interview angle:** "How do you harden a Docker container?" This is a top-5 DevOps/SRE interview question. Hit these points: non-root USER, `cap_drop: ALL`, `read_only: true`, `tmpfs` for writable directories, `no-new-privileges`, and minimal base image.

**Pro tip:** Add `security_opt: [no-new-privileges:true]` to prevent setuid escalation. This closes the last common privilege escalation path in containers.
