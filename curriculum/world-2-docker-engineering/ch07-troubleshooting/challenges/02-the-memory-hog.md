# Challenge 7.2: The Memory Hog

> "The backend worked fine for an hour, then disappeared. Exit code 137. Docker says OOMKilled. This is the third time this week."
> — You, in the incident channel

---

## The Situation

The NoCappuccino recommendation engine loads coffee data into memory for fast lookups. It's been working fine with a small dataset. But since the marketing campaign launched, the coffee catalog has grown, and the engine is loading more data every time it processes a batch.

The container runs fine for a while, then gets OOMKilled. It restarts (because `restart: on-failure`), loads the data again, runs for a bit, and gets killed again. Classic memory hog pattern.

---

## Setup

Create the following files.

**`leaky.js`** — a process that gradually consumes more memory:

```javascript
const http = require('http');

// Simulating a growing data cache that's never cleaned up
const dataStore = [];

function loadBatch() {
  // Each batch adds ~1MB of data that's never released
  const batch = Buffer.alloc(1024 * 1024, 'coffee-data');
  dataStore.push(batch);
  console.log(`Loaded batch #${dataStore.length} — Total memory: ~${dataStore.length}MB cached`);
}

// Load a batch every 2 seconds
setInterval(loadBatch, 2000);

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'ok',
      cached_batches: dataStore.length,
      approx_memory_mb: dataStore.length
    }));
    return;
  }
  res.writeHead(200);
  res.end(`Recommendation engine — ${dataStore.length} batches cached\n`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  server.close(() => process.exit(0));
});

server.listen(3000, () => {
  console.log('Recommendation engine started on port 3000');
  loadBatch(); // Load first batch immediately
});
```

**`Dockerfile`**:

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY leaky.js .

CMD ["node", "leaky.js"]
```

**`docker-compose.yml`**:

```yaml
name: learn-ch07

services:
  recommender:
    build: .
    ports:
      - "3000:3000"
    restart: on-failure
    labels:
      app: learn-docker-k8s
      world: w02
```

---

## Your Task

1. Build and start the container
2. Watch it with `docker stats` — observe memory climbing
3. Wait for the OOMKill (or apply a memory limit to trigger it faster)
4. Diagnose the problem:
   - Confirm it was OOMKilled
   - Identify the exit code
   - Understand why memory keeps growing
5. Apply a fix:
   - Set an appropriate memory limit (so one container can't take down the host)
   - The limit should be reasonable — enough for normal operation but not unlimited

**Note:** The "real" fix would be fixing the memory leak in the code. For this challenge, your job is to apply resource limits as a safety net — the way you would in production while the development team fixes the underlying bug.

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The script checks:
1. The recommender container is running
2. A memory limit is configured (not unlimited)
3. The memory limit is reasonable (between 64M and 256M)
4. `docker inspect` shows the limit is applied

---

## Hints

<details>
<summary>Hint 1 — Observe the problem</summary>

Start the container and watch memory usage:

```bash
docker compose up -d
docker stats learn-ch07-recommender-1
```

You'll see memory climbing steadily. Without limits, it will consume all available memory on the host.

To trigger OOMKill faster, add a temporary tight limit:

```bash
docker compose down
# Add deploy.resources.limits.memory: 64M to the compose file
docker compose up -d
```

After about 60 seconds, the container will be killed. Check:

```bash
docker inspect learn-ch07-recommender-1 --format '{{.State.OOMKilled}} / exit {{.State.ExitCode}}'
# true / exit 137
```

</details>

<details>
<summary>Hint 2 — Apply resource limits</summary>

Add the `deploy` section to your Compose service:

```yaml
services:
  recommender:
    build: .
    ports:
      - "3000:3000"
    restart: on-failure
    deploy:
      resources:
        limits:
          memory: 128M        # hard cap
    labels:
      app: learn-docker-k8s
      world: w02
```

The memory limit prevents the container from consuming unlimited host memory. When it hits 128M, it will be OOMKilled rather than taking down the entire host.

</details>

<details>
<summary>Hint 3 — Verify the limit</summary>

Check that the limit is applied:

```bash
# Raw bytes (134217728 = 128 MB)
docker inspect learn-ch07-recommender-1 --format '{{.HostConfig.Memory}}'

# Live stats — should show the limit
docker stats --no-stream learn-ch07-recommender-1
# MEM USAGE / LIMIT should show "XXMiB / 128MiB"
```

The container will still eventually be OOMKilled (the leak is still there), but the impact is contained to 128M instead of consuming all host memory.

In production, you'd also:
1. Set up alerting when memory usage exceeds 80% of the limit
2. File a ticket to fix the memory leak in the application
3. Possibly add a restart policy so the container recovers after OOMKill

</details>

---

## Post-Challenge Debrief

**What you did:** Diagnosed an OOMKill (exit code 137), confirmed it with `docker inspect`, watched memory grow with `docker stats`, and applied resource limits to contain the blast radius.

**Why it works:** Resource limits use Linux cgroups to cap how much memory a container can use. The kernel's OOM killer terminates the process when it exceeds the limit. This is a safety net — it doesn't fix the leak, but it prevents one misbehaving container from taking down the entire host.

**Real-world connection:** Memory limits are mandatory in production Kubernetes deployments (`resources.limits.memory`). Without them, a single pod with a leak can starve other pods on the same node. The "noisy neighbor" problem is one of the most common causes of production instability.

**Interview angle:** "What happens when a container is OOMKilled? How do you diagnose it?" Strong answer: exit code 137, `docker inspect .State.OOMKilled`, `docker stats` for memory trends, `docker events` for the timeline. Fix with memory limits and address the root cause in the application.

**Pro tip:** For Node.js, you can set `--max-old-space-size` to limit V8's heap:
```dockerfile
CMD ["node", "--max-old-space-size=200", "server.js"]
```
This lets Node.js gracefully handle memory pressure (garbage collection) instead of being abruptly killed by the OOM killer.
