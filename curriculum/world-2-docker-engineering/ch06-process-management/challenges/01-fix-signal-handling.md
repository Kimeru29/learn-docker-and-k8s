# Challenge 6.1: Fix Signal Handling

> "Every deployment takes an extra 10 seconds per container because `docker stop` never shuts down gracefully. Multiply that by 8 containers, three deploys a day... that's 4 minutes of unnecessary downtime daily."
> — Sarah, doing the math on a napkin

---

## The Situation

The NoCappuccino recommendation worker processes coffee orders in the background. It's a Node.js app that runs in a container. The Dockerfile was written by an intern who has since graduated.

The problem: every time you deploy, `docker stop` takes exactly 10 seconds before the container finally dies. The app has SIGTERM handling code, but it never fires. Something is wrong with how the container runs the process.

---

## Setup

Create the following files for this challenge.

**`worker.js`** — a worker that handles SIGTERM correctly (in theory):

```javascript
console.log(`Worker started (PID: ${process.pid})`);

// Simulate background work
const interval = setInterval(() => {
  console.log(`[${new Date().toISOString()}] Processing recommendations...`);
}, 2000);

// Graceful shutdown handler
process.on('SIGTERM', () => {
  console.log('SIGTERM received! Cleaning up...');
  clearInterval(interval);
  console.log('Worker shut down gracefully.');
  process.exit(0);
});

console.log('Worker ready. SIGTERM handler registered.');
```

**`Dockerfile`** (the broken version):

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY worker.js .

CMD node worker.js
```

**`docker-compose.yml`**:

```yaml
name: learn-ch06

services:
  worker:
    build: .
    labels:
      app: learn-docker-k8s
      world: w02
```

---

## Your Task

1. Build and start the container
2. Observe the problem: run `docker stop` and time it — it should take ~10 seconds
3. Diagnose the root cause: why isn't the SIGTERM handler firing?
4. Fix the Dockerfile so the container stops in under 2 seconds

**Do not modify `worker.js`** — the application code is correct. The problem is in the Dockerfile.

---

## Success Criteria

Run the verification script:

```bash
bash challenges/verify.sh
```

The script checks:
1. The worker container is running
2. `docker stop` completes in under 3 seconds
3. The container logs show "SIGTERM received" and "shut down gracefully"

---

## Hints

<details>
<summary>Hint 1 — Where to look</summary>

The worker.js code is fine — it registers a SIGTERM handler. The problem is in the Dockerfile. Look at the `CMD` line. What form is it using? What does that mean for how Docker runs the process?

Run `docker top` on the running container and look at what PID 1 actually is.

</details>

<details>
<summary>Hint 2 — The shell form problem</summary>

`CMD node worker.js` (without brackets) is **shell form**. Docker wraps it as `/bin/sh -c "node worker.js"`. The shell becomes PID 1, and your Node.js process becomes a child at PID 7 or similar.

When `docker stop` sends SIGTERM, it goes to PID 1 (the shell). The shell doesn't forward signals to children. Your app never receives SIGTERM.

Check with:
```bash
docker top <container_name>
```

You should see `/bin/sh -c "node worker.js"` as PID 1.

</details>

<details>
<summary>Hint 3 — The fix</summary>

Change the CMD to **exec form** — a JSON array:

```dockerfile
CMD ["node", "worker.js"]
```

This runs `node worker.js` directly as PID 1, without a shell wrapper. SIGTERM is delivered to the Node.js process, which triggers the signal handler.

Rebuild and test:
```bash
docker compose build && docker compose up -d
time docker compose stop worker
```

The stop should now complete in under 1 second, and the logs should show the graceful shutdown messages.

</details>

---

## Post-Challenge Debrief

**What you did:** Changed `CMD node worker.js` (shell form) to `CMD ["node", "worker.js"]` (exec form), eliminating the `/bin/sh` wrapper that was eating SIGTERM signals.

**Why it works:** Exec form runs the process directly as PID 1. Shell form wraps it in `/bin/sh -c`, which doesn't forward signals. With exec form, `docker stop` sends SIGTERM directly to your application, which handles it and exits cleanly.

**Real-world connection:** In Kubernetes, the default `terminationGracePeriodSeconds` is 30 seconds. If your container doesn't handle SIGTERM, every pod termination waits 30 seconds and then hard-kills. During rolling updates, this multiplies across all replicas. Shell form in CMD is one of the most common causes of slow deployments.

**Interview angle:** "What's the difference between `CMD node server.js` and `CMD ["node", "server.js"]` in a Dockerfile?" This is a favorite interview question for DevOps/SRE roles. The answer involves PID 1, signal handling, and the 10-second kill timeout.

**Pro tip:** Search your codebase with `grep -rn "^CMD [^[]" */Dockerfile` to find all Dockerfiles using shell form CMD. Each one is potentially a 10-second deploy penalty.
