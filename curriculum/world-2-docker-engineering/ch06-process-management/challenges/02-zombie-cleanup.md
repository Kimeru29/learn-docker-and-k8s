# Challenge 6.2: Zombie Cleanup

> "I just ran `docker top` on the recommendation worker and there are 15 processes marked `[defunct]`. They're zombies. The container has been running for 6 hours and they're accumulating. What is going on?"
> — You, to Sarah, over coffee

---

## The Situation

The NoCappuccino recommendation engine spawns child processes to process coffee orders. Each order is handled by a short-lived subprocess. The problem: after the subprocess finishes, it becomes a zombie. No one is collecting the exit status.

After a few hours, `docker top` shows dozens of `[defunct]` entries. The container's resource usage creeps up. Dave's response: "Just restart it every 4 hours with a cron job." Sarah's response: "No."

---

## Setup

Create the following files for this challenge.

**`spawner.sh`** — a script that simulates spawning child processes:

```bash
#!/bin/sh
echo "Spawner started (PID: $$)"

process_order() {
  local order_id=$1
  echo "Processing order $order_id..."
  sleep 1
  echo "Order $order_id complete."
}

# Spawn child processes in the background
counter=0
while true; do
  counter=$((counter + 1))
  process_order "$counter" &
  sleep 3
done
```

**`Dockerfile`**:

```dockerfile
FROM alpine:3.21

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY spawner.sh .
RUN chmod +x spawner.sh

CMD ["./spawner.sh"]
```

**`docker-compose.yml`**:

```yaml
name: learn-ch06

services:
  spawner:
    build:
      context: .
      dockerfile: Dockerfile
    labels:
      app: learn-docker-k8s
      world: w02
```

---

## Your Task

1. Build and start the container
2. Wait about 30 seconds, then check for zombies:
   ```bash
   docker top learn-ch06-spawner-1
   docker exec learn-ch06-spawner-1 ps aux | grep defunct
   ```
3. Diagnose: why are zombie processes accumulating?
4. Fix the problem so that child processes are properly reaped

The zombie problem has multiple valid solutions. Choose the one you think is most appropriate.

---

## Success Criteria

Run the verification script:

```bash
bash challenges/verify.sh
```

The script checks:
1. The spawner container is running
2. After 30 seconds of operation, there are zero (or near-zero) zombie processes
3. The spawner is still correctly processing orders (log output shows new orders being processed)

---

## Hints

<details>
<summary>Hint 1 — Understanding the problem</summary>

The `spawner.sh` script uses `&` to run child processes in the background. When a background child finishes, its parent (the shell script) needs to call `wait` to collect its exit status. Without `wait`, the finished child becomes a zombie.

Check the current state:
```bash
docker exec learn-ch06-spawner-1 ps aux
```

Look for entries with `Z` status or `[defunct]` in the command. Each one is a zombie.

</details>

<details>
<summary>Hint 2 — Two approaches</summary>

**Approach A: Fix the script.** Add `wait` calls in the shell script to reap background children. You could use `trap` with `SIGCHLD` or periodically call `wait -n` (bash) or just `wait`.

**Approach B: Use an init process.** Add `init: true` to the Compose file (or use tini in the Dockerfile). An init process running as PID 1 automatically reaps zombies, regardless of what the script does.

Both are valid. Approach B is simpler and more robust when you don't control the application code.

</details>

<details>
<summary>Hint 3 — The simplest fix</summary>

Add `init: true` to the Compose service:

```yaml
services:
  spawner:
    build: .
    init: true                    # Docker's built-in tini handles zombie reaping
    labels:
      app: learn-docker-k8s
      world: w02
```

Or install tini in the Dockerfile:

```dockerfile
FROM alpine:3.21
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./spawner.sh"]
```

Both add a proper init process as PID 1 that reaps zombies automatically.

Alternatively, fix the script by adding `wait` to reap children:

```bash
#!/bin/sh
trap 'wait' SIGCHLD

counter=0
while true; do
  counter=$((counter + 1))
  process_order "$counter" &
  # Reap any finished children
  wait -n 2>/dev/null || true
  sleep 3
done
```

</details>

---

## Post-Challenge Debrief

**What you did:** Fixed a container that was accumulating zombie processes by either adding a proper init process (tini) or fixing the shell script to reap children.

**Why it works:** On a normal Linux system, `init` (PID 1) automatically reaps orphaned child processes. In a container, your application is PID 1 — and most applications don't reap children. tini acts as a minimal, purpose-built PID 1 that handles zombie reaping and signal forwarding.

**Real-world connection:** Zombie processes are common in containers that spawn worker subprocesses (image processing, video encoding, data pipelines). They're also common when using shell scripts as entrypoints that launch background processes. The `init: true` flag in Compose (or `--init` in `docker run`) is a zero-effort fix.

**Interview angle:** "What are zombie processes and how do they appear in containers?" tests understanding of Unix process management and container internals. The strong answer: "A zombie is a finished process whose parent hasn't called wait(). In containers, the app is PID 1 and may not reap children. Fix with tini or Docker's --init flag."

**Pro tip:** In Kubernetes, the equivalent is `shareProcessNamespace: true` on the pod spec combined with a proper init process. Some base images (like the official Python and Node.js images) already handle this well for direct children, but not for grandchildren or orphaned processes from third-party libraries.
