# Challenge 7.3: The Network Black Hole

> "The backend is running. Postgres is running. But the backend can't connect to Postgres. I checked — the credentials are correct. It just times out. Every time."
> — Junior developer, 2 PM

---

## The Situation

A new developer set up the NoCappuccino stack for local development. Everything starts. All containers show as "running." But the backend logs show:

```
Error: connect ETIMEDOUT 172.18.0.4:5432
```

The developer swears they followed the setup guide exactly. The database credentials are correct. Postgres is accepting connections (they verified with `docker exec`). But the backend can't reach it.

Something is wrong with the network configuration.

---

## Setup

Create the following files.

**`server.js`** — a simple backend that connects to Postgres:

```javascript
const http = require('http');
const { Pool } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL;
console.log(`Connecting to database: ${DATABASE_URL ? 'configured' : 'NOT SET'}`);

const pool = DATABASE_URL ? new Pool({ connectionString: DATABASE_URL, connectionTimeoutMillis: 5000 }) : null;

const server = http.createServer(async (req, res) => {
  if (req.url === '/health') {
    try {
      if (pool) {
        await pool.query('SELECT 1');
        res.writeHead(200);
        res.end(JSON.stringify({ status: 'ok', database: 'connected' }));
      } else {
        res.writeHead(503);
        res.end(JSON.stringify({ status: 'error', database: 'no DATABASE_URL' }));
      }
    } catch (err) {
      res.writeHead(503);
      res.end(JSON.stringify({ status: 'error', database: err.message }));
    }
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API\n');
});

process.on('SIGTERM', () => {
  server.close(() => {
    if (pool) pool.end();
    process.exit(0);
  });
});

server.listen(3000, () => {
  console.log('Backend listening on port 3000');
});
```

**`package.json`**:

```json
{
  "name": "ch07-backend",
  "version": "1.0.0",
  "dependencies": {
    "pg": "^8.11.3"
  }
}
```

**`Dockerfile`**:

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY server.js .

CMD ["node", "server.js"]
```

**`docker-compose.yml`** (the broken version):

```yaml
name: learn-ch07

services:
  backend:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://brew:brewpass@postgres:5432/cloudbrew
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
      POSTGRES_PASSWORD: brewpass
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
```

---

## Your Task

1. Build and start the stack — `docker compose up -d`
2. Check the backend logs — you'll see connection timeouts to Postgres
3. Diagnose the network problem using the debugging tools you've learned
4. Fix the `docker-compose.yml` so the backend can reach Postgres

The backend should be able to connect to Postgres and the `/health` endpoint should return `{"status":"ok","database":"connected"}`.

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The script checks:
1. Both backend and postgres containers are running
2. Postgres is healthy
3. The backend's `/health` endpoint returns database "connected"
4. The backend can resolve the hostname "postgres"

---

## Hints

<details>
<summary>Hint 1 — The debugging approach</summary>

Start with Step 5 of the debugging ladder — Test Connectivity:

```bash
# What networks is the backend on?
docker inspect learn-ch07-backend-1 --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

# What networks is postgres on?
docker inspect learn-ch07-postgres-1 --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
```

Compare the two outputs. Are they on the same network?

Try DNS resolution from the backend:
```bash
docker exec learn-ch07-backend-1 nslookup postgres
```

</details>

<details>
<summary>Hint 2 — The root cause</summary>

The backend is on `frontend-net`. Postgres is on `backend-net`. They're on **different networks** — they can't see each other.

Docker DNS resolution only works within the same user-defined network. A container on `frontend-net` cannot resolve hostnames of containers on `backend-net`.

The `DATABASE_URL` uses hostname `postgres`, which resolves within the network where the Postgres service is. Since the backend isn't on that network, the DNS lookup fails or times out.

</details>

<details>
<summary>Hint 3 — The fix</summary>

The backend needs to be on the `backend-net` network (where Postgres is). It can be on both networks if needed:

```yaml
services:
  backend:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://brew:brewpass@postgres:5432/cloudbrew
    networks:
      - frontend-net
      - backend-net        # ← add this
    labels:
      app: learn-docker-k8s
      world: w02
```

Or put both services on the same network. The simplest fix is adding the backend to `backend-net`.

After the fix:
```bash
docker compose down && docker compose up -d
curl http://localhost:3000/health
# {"status":"ok","database":"connected"}
```

</details>

---

## Post-Challenge Debrief

**What you did:** Diagnosed a network connectivity issue where two containers were on separate Docker networks and couldn't resolve each other's hostnames. Fixed by adding the backend to the same network as Postgres.

**Why it works:** Docker DNS resolution only works within user-defined networks. Containers on different networks are isolated — they can't see each other by name or by IP (unless the networks are explicitly connected). This isolation is a security feature, but it becomes a bug when services that need to communicate are accidentally separated.

**Real-world connection:** Network segmentation is a best practice — you want your database on a private network, not exposed to the frontend. But the backend needs to bridge both networks. This is the two-tier network pattern: `frontend-net` (public-facing) and `backend-net` (data tier). The backend sits on both.

**Interview angle:** "A container can reach the internet but can't reach another container by hostname. What do you check?" Strong answer: verify both containers are on the same user-defined network, check DNS resolution with `nslookup` from inside the container, and verify the target service is running and healthy.

**Pro tip:** `docker network inspect <network>` shows all containers on a network and their IP addresses. It's the fastest way to verify network membership without inspecting each container individually.
