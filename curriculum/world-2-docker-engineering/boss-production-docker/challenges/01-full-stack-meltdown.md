# Boss Fight: The Full Stack Meltdown

> "Five fires. One engineer. Every skill you've learned. Let's go."
> — Sarah

---

## The Broken Stack

The NoCappuccino production stack has degraded across five dimensions simultaneously. Below is the broken Compose stack and supporting files. Your mission: fix all five problems.

---

## Setup

Create the following files.

### `api/server.js`

```javascript
const http = require('http');

const PORT = process.env.PORT || 3000;
const DB_HOST = process.env.DB_HOST || 'postgres';
const DB_PASSWORD = process.env.DB_PASSWORD;

console.log(`API starting on port ${PORT}`);
console.log(`DB host: ${DB_HOST}, password: ${DB_PASSWORD ? 'SET' : 'NOT SET'}`);

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'ok',
      service: 'api',
      db_host: DB_HOST,
      db_configured: !!DB_PASSWORD
    }));
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API\n');
});

// SIGTERM handler — this works correctly
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('API shut down cleanly.');
    process.exit(0);
  });
});

server.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});
```

### `api/Dockerfile` (BROKEN — Problem 1 and Problem 3)

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY server.js .

# PROBLEM 3: Secret baked into the image
ENV DB_PASSWORD=nocap_prod_password_2025

# PROBLEM 1: Shell form — signals not forwarded
CMD node server.js
```

### `worker/leaky-worker.js`

```javascript
// Worker that processes recommendations — has a memory leak
const cache = [];

function processRecommendation() {
  // Each recommendation adds ~512KB to the cache and never cleans up
  const data = Buffer.alloc(512 * 1024, 'recommendation-data');
  cache.push(data);
  console.log(`Processed recommendation #${cache.length} — cache: ~${(cache.length * 0.5).toFixed(1)}MB`);
}

// Process one recommendation every 2 seconds
setInterval(processRecommendation, 2000);
processRecommendation();

process.on('SIGTERM', () => {
  console.log('Worker shutting down...');
  process.exit(0);
});

console.log('Recommendation worker started.');
```

### `worker/Dockerfile`

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY leaky-worker.js .

CMD ["node", "leaky-worker.js"]
```

### `frontend/index.html`

```html
<!DOCTYPE html>
<html>
<head>
  <title>NoCappuccino</title>
  <style>body { font-family: sans-serif; background: #1a0a00; color: #f5e6d0; padding: 2rem; }
  h1 { color: #d4a96a; }</style>
</head>
<body>
  <h1>NoCappuccino</h1>
  <p>Specialty Coffee Subscriptions</p>
</body>
</html>
```

### `frontend/Dockerfile` (BROKEN — Problem 4)

```dockerfile
# PROBLEM 4: Uses a bloated base image with unnecessary tools
FROM ubuntu:24.04

LABEL app=learn-docker-k8s
LABEL world=w02

# Installs Apache, PHP, build tools — none of which are needed for static HTML
RUN apt-get update && apt-get install -y \
    apache2 \
    php \
    build-essential \
    curl \
    vim \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY index.html /var/www/html/index.html

EXPOSE 80

CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### `docker-compose.yml` (BROKEN — Problem 2 and Problem 5)

```yaml
name: learn-boss

services:

  api:
    build: ./api
    ports:
      - "3000:3000"
    environment:
      PORT: "3000"
      DB_HOST: postgres
      DB_PASSWORD: ${DB_PASSWORD:-nocap_prod_password_2025}
    networks:
      - frontend-net                  # PROBLEM 5: API only on frontend-net, not backend-net
    depends_on:
      postgres:
        condition: service_healthy
    labels:
      app: learn-docker-k8s
      world: w02

  worker:
    build: ./worker
    # PROBLEM 2: No memory limit — will consume all host memory
    restart: on-failure
    networks:
      - backend-net
    labels:
      app: learn-docker-k8s
      world: w02

  frontend:
    build: ./frontend
    ports:
      - "8080:80"
    networks:
      - frontend-net
    labels:
      app: learn-docker-k8s
      world: w02

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: cloudbrew
      POSTGRES_USER: brew
      POSTGRES_PASSWORD: ${DB_PASSWORD:-nocap_prod_password_2025}
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - backend-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    labels:
      app: learn-docker-k8s
      world: w02

networks:
  frontend-net:
    labels:
      app: learn-docker-k8s
      world: w02
  backend-net:
    labels:
      app: learn-docker-k8s
      world: w02

volumes:
  db-data:
    labels:
      app: learn-docker-k8s
      world: w02
```

Create a `.env` file:
```
DB_PASSWORD=runtime-secure-password
```

---

## The Five Problems

### Problem 1: API Doesn't Handle SIGTERM (Ch06)
**Symptom:** `docker stop` on the API takes 10 seconds. Deploys are slow.
**Root cause:** Shell form `CMD` in `api/Dockerfile`.
**Requirement:** `docker stop` must complete in under 3 seconds. Logs must show "SIGTERM received."

### Problem 2: Worker Memory Leak (Ch07)
**Symptom:** Worker gets OOMKilled (exit 137) after running for a while.
**Root cause:** No memory limit on the worker service.
**Requirement:** Worker must have a memory limit between 64M and 256M.

### Problem 3: Credentials in Image History (Ch08)
**Symptom:** `docker history learn-boss-api --no-trunc` shows the database password.
**Root cause:** `ENV DB_PASSWORD=...` in `api/Dockerfile`.
**Requirement:** `docker history` must not contain any password or secret values.

### Problem 4: Bloated Frontend Image (Ch02/Ch08)
**Symptom:** Frontend image is over 500 MB. Pulls are slow, disk is filling.
**Root cause:** Uses `ubuntu:24.04` with Apache, PHP, build tools for serving static HTML.
**Requirement:** Frontend image must be under 50 MB. Use an appropriate base image (e.g., `nginx:alpine`).

### Problem 5: Network Misconfiguration (Ch04/Ch05)
**Symptom:** API can't reach Postgres — `ECONNREFUSED` or `ETIMEDOUT`.
**Root cause:** API is on `frontend-net` but Postgres is on `backend-net`. They can't see each other.
**Requirement:** API must be on both networks. `/health` must report `db_configured: true`.

---

## Triage Guidance

Sarah's advice: "Fix what's most visible first."

**Suggested order (but you choose):**
1. **Network (Problem 5)** — Nothing works if services can't communicate
2. **Signal handling (Problem 1)** — Deploys are blocked
3. **Memory limit (Problem 2)** — Worker will crash the host
4. **Credentials (Problem 3)** — Security vulnerability
5. **Image size (Problem 4)** — Performance issue

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The verification script checks all five fixes independently. Partial credit is possible — each fix is verified separately.

---

## Hints

<details>
<summary>Hint Level 1 — General direction for each problem</summary>

1. **Signal handling:** Look at the `CMD` line in `api/Dockerfile`. What form is it?
2. **Memory leak:** The worker needs a `deploy.resources.limits.memory` in Compose.
3. **Credentials:** Remove the `ENV DB_PASSWORD` line from the Dockerfile. Use runtime injection.
4. **Image size:** Replace the `ubuntu` + Apache + PHP stack with `nginx:alpine`.
5. **Network:** The API needs to be on `backend-net` in addition to `frontend-net`.

</details>

<details>
<summary>Hint Level 2 — Specific areas to change</summary>

1. **api/Dockerfile:** Change `CMD node server.js` to `CMD ["node", "server.js"]`
2. **docker-compose.yml, worker service:** Add `deploy: { resources: { limits: { memory: 128M } } }`
3. **api/Dockerfile:** Remove the `ENV DB_PASSWORD=...` line entirely
4. **frontend/Dockerfile:** Rewrite using `FROM nginx:1.25-alpine`, just `COPY index.html /usr/share/nginx/html/`
5. **docker-compose.yml, api service:** Change `networks: [frontend-net]` to `networks: [frontend-net, backend-net]`

</details>

<details>
<summary>Hint Level 3 — Near-complete solutions</summary>

**api/Dockerfile (fixed):**
```dockerfile
FROM node:20-alpine
LABEL app=learn-docker-k8s
LABEL world=w02
WORKDIR /app
COPY server.js .
CMD ["node", "server.js"]
```

**frontend/Dockerfile (fixed):**
```dockerfile
FROM nginx:1.25-alpine
LABEL app=learn-docker-k8s
LABEL world=w02
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

**docker-compose.yml changes:**
```yaml
  api:
    networks:
      - frontend-net
      - backend-net      # ← ADD THIS

  worker:
    deploy:              # ← ADD THIS BLOCK
      resources:
        limits:
          memory: 128M
```

**Create `.dockerignore` in api/ directory:**
```
.env
*.env
```

Rebuild everything: `docker compose up -d --build`

</details>
