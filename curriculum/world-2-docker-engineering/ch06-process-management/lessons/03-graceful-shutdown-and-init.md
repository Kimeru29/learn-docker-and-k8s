# Lesson 6.3: Graceful Shutdown and Init Processes

> "The recommendation worker keeps accumulating zombie processes. After a few hours, `docker top` shows dozens of `[defunct]` entries. The CPU usage keeps climbing. Dave suggested rebooting the server. I suggested fixing the actual problem."
> — Sarah

---

## Zombie Processes: What and Why

A zombie process is a child process that has finished executing but whose parent hasn't collected its exit status. On a normal Linux system, `init` (PID 1) automatically reaps orphaned zombies. In a container, your application is PID 1 — and most applications don't reap child processes.

### How Zombies Are Born

```
1. Parent process (PID 1) spawns a child
2. Child finishes its work and exits
3. Child becomes a "zombie" — it's done, but its entry remains in the process table
4. Parent is supposed to call wait() to collect the exit status and remove the entry
5. If parent never calls wait(), the zombie stays forever
```

In diagram form:

```
Container Process Tree:

PID 1: node worker.js        ← spawns child processes for tasks
  PID 7: node task-1.js      ← finished, but parent didn't call wait()
  PID 8: [defunct]            ← ZOMBIE 🧟 — task-2 finished, not reaped
  PID 9: [defunct]            ← ZOMBIE 🧟
  PID 10: node task-4.js     ← still running
  PID 11: [defunct]           ← ZOMBIE 🧟
```

### Why Zombies Matter

Each zombie consumes a slot in the kernel's process table. On most systems, the table has a limit (usually 32,768 or higher). In practice, you'll see resource degradation (increased memory for process table management, slower process listing) long before you hit the hard limit. But the real problem is diagnostic noise — a container full of zombies obscures what's actually running.

### How to Spot Zombies

```bash
# See all processes including zombies
docker top learn-ch06-worker

# Count zombies
docker exec learn-ch06-worker sh -c 'ps aux | grep -c defunct'

# Or from outside
docker exec learn-ch06-worker ps -eo pid,stat,cmd | grep Z
```

Zombies show up with status `Z` or `Z+` in `ps` output, and `[defunct]` in the CMD column.

---

## The PID 1 Reaping Problem

On a normal Linux host, if a parent process dies, its children are reparented to PID 1 (`init`/`systemd`), which automatically reaps them.

In a container, if your app is PID 1 and spawns children (directly or indirectly), it must also reap them. Most application runtimes (Node.js, Python, Java) don't do this automatically — they're not designed to be PID 1.

This becomes a problem when:

1. Your app spawns child processes (worker pools, shell commands, image processing)
2. Your app uses libraries that spawn subprocesses
3. An entrypoint script starts background processes before the main app

---

## Solution 1: Application-Level Reaping

If your app spawns children, handle `SIGCHLD` and call `wait()`:

### Node.js

```javascript
const { spawn } = require('child_process');

// Spawn a child
const child = spawn('process-image', ['input.jpg']);

// Collect exit status when done — prevents zombie
child.on('exit', (code) => {
  console.log(`Child exited with code ${code}`);
});
```

### Python

```python
import subprocess
import os, signal

# Option 1: Use subprocess properly (auto-reaps)
result = subprocess.run(['process-image', 'input.jpg'])

# Option 2: Handle SIGCHLD for background processes
def reap_children(signum, frame):
    while True:
        try:
            pid, status = os.waitpid(-1, os.WNOHANG)
            if pid == 0:
                break
        except ChildProcessError:
            break

signal.signal(signal.SIGCHLD, reap_children)
```

This works if you control the code. But sometimes you can't modify the application, or the zombie-creating behavior comes from a library. Enter init processes.

---

## Solution 2: Init Processes (tini / dumb-init)

An init process is a small, purpose-built PID 1 that:

1. **Forwards signals** to child processes (SIGTERM → your app)
2. **Reaps zombie processes** automatically
3. **Adds minimal overhead** (~1 MB, negligible CPU)

### tini

[tini](https://github.com/krallin/tini) is the most widely used container init. It's included in Docker itself.

```dockerfile
# Option 1: Use Docker's built-in init (recommended for most cases)
# No Dockerfile change needed — use the --init flag at runtime:
# docker run --init learn-ch06-worker

# Option 2: Install tini in the image
FROM node:20-alpine
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "worker.js"]
```

With tini:

```
PID 1: /sbin/tini -- node worker.js    ← tini is PID 1 (reaps zombies, forwards signals)
PID 7: node worker.js                  ← your app (receives forwarded SIGTERM)
PID 15: [child process]                ← tini will reap this when it exits
```

### dumb-init

[dumb-init](https://github.com/Yelp/dumb-init) is an alternative from Yelp with similar functionality:

```dockerfile
FROM python:3.12-slim
RUN apt-get update && apt-get install -y dumb-init && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["dumb-init", "--"]
CMD ["python", "worker.py"]
```

### Docker's Built-In `--init`

Docker ships with a bundled tini. You can enable it without modifying the image:

```bash
docker run --init learn-ch06-worker
```

In Compose:

```yaml
services:
  worker:
    build: ./worker
    init: true                    # uses Docker's built-in tini
    labels:
      app: learn-docker-k8s
      world: w02
```

**When to use `--init`:**
- Your app spawns child processes
- You can't easily modify the app to handle SIGCHLD
- You're using third-party images that you don't control
- You want an easy safety net against zombies

**When you might NOT need it:**
- Single-process containers (most web servers)
- Your app already properly handles SIGCHLD
- You're using exec form CMD with no child processes

---

## Graceful Shutdown in Practice

A production-grade graceful shutdown handles multiple concerns:

```javascript
// server.js — production shutdown pattern
const http = require('http');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const server = http.createServer(handleRequest);

let isShuttingDown = false;

// Reject new requests during shutdown
function handleRequest(req, res) {
  if (isShuttingDown) {
    res.writeHead(503, { 'Connection': 'close' });
    res.end('Service shutting down');
    return;
  }
  // ... normal request handling
}

async function gracefulShutdown(signal) {
  console.log(`${signal} received. Starting graceful shutdown...`);
  isShuttingDown = true;

  // 1. Stop accepting new connections
  server.close(() => {
    console.log('HTTP server closed');
  });

  // 2. Wait for in-flight requests (with timeout)
  const forceTimeout = setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 15000); // 15s safety net

  try {
    // 3. Close database connections
    await pool.end();
    console.log('Database pool closed');

    // 4. Exit cleanly
    clearTimeout(forceTimeout);
    console.log('Graceful shutdown complete');
    process.exit(0);
  } catch (err) {
    console.error('Error during shutdown:', err);
    process.exit(1);
  }
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

server.listen(3000);
```

### The Shutdown Sequence

```
1. Receive SIGTERM
2. Set "shutting down" flag (reject new work)
3. Stop accepting new connections
4. Wait for in-flight requests to complete
5. Close database connections and caches
6. Flush buffers and logs
7. Exit with code 0
```

### The Safety Timeout

Always include a forced shutdown timeout. If cleanup takes longer than expected (stuck database connections, unresponsive external services), you don't want to hang forever. The timeout should be shorter than Docker's grace period:

```
Docker grace period:    10s (default)
App safety timeout:     8s (less than Docker's grace)
```

If your app needs more than 10 seconds for cleanup, increase Docker's grace period:

```yaml
services:
  backend:
    stop_grace_period: 30s     # give the app 30 seconds
```

---

## Restart Policies and Their Impact

Restart policies interact with process management in important ways:

| Policy | Behavior | When to Use |
|--------|----------|-------------|
| `no` | Never restart | One-shot tasks (migrations, test runners) |
| `on-failure` | Restart only on non-zero exit | Apps during development (surface bugs) |
| `always` | Always restart, even after `docker stop` | Production services (usually) |
| `unless-stopped` | Like `always`, but not after manual stop | Development databases and caches |

### The Restart Loop Trap

```yaml
services:
  backend:
    restart: always          # will restart even if it crashes on startup
```

If the app crashes immediately on startup (missing config, wrong DB password), `restart: always` creates an infinite restart loop. The container starts, crashes, starts, crashes — consuming CPU and filling logs.

Watch for it:

```bash
docker compose ps
# STATUS: Restarting (1) — 2 seconds ago
```

Docker applies exponential backoff to restarts (doubling the delay between attempts), but the loop continues indefinitely. This is why `on-failure` is often better during development — it restarts on crashes but not on clean exits.

---

## Health Checks vs. Liveness vs. Process Status

Three different concepts that get confused:

| Check | What It Answers | Who Uses It |
|-------|-----------------|-------------|
| **Process running** | Is the container process alive? | Docker (`docker ps` shows "running") |
| **Health check** | Is the app ready to serve traffic? | Docker health system, `depends_on` conditions |
| **Liveness probe** (K8s) | Has the app deadlocked? | Kubernetes (restarts pod if failing) |

A container can be "running" (process exists) but not "healthy" (app hasn't finished initialization or is deadlocked). This is why health checks matter — they test actual application readiness, not just process existence.

```yaml
services:
  backend:
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:3000/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 15s
```

---

## Summary

- **Zombie processes** are finished children whose exit status hasn't been collected
- PID 1 is responsible for reaping orphans — most apps don't do this
- **tini** or **dumb-init** acts as a proper PID 1: reaps zombies, forwards signals
- Use `init: true` in Compose or `--init` flag for easy zombie protection
- **Graceful shutdown** should: stop accepting work, drain in-flight requests, close connections, exit
- Always include a **safety timeout** shorter than Docker's grace period
- `restart: always` can create infinite restart loops — use `on-failure` during development
- **Health checks** verify app readiness, not just process existence

You now understand what happens inside your containers at the process level — from PID 1 to graceful shutdown to zombie cleanup. Time to put it into practice.
