# Lesson 7.1: The Diagnostic Workflow

> "When something breaks at 3 AM and you're running on coffee fumes, you need a process. Not inspiration. Not luck. A repeatable, step-by-step process that works when your brain doesn't."
> — Sarah

---

## The 6-Step Debugging Ladder

Every container problem can be approached with the same six steps. You climb the ladder until you find the issue. Most problems are caught in the first three steps.

```
    ┌─────────────────────────────────────────┐
 6. │  Examine the Image                      │  ← build-time issues
    ├─────────────────────────────────────────┤
 5. │  Test Connectivity                      │  ← network/DNS issues
    ├─────────────────────────────────────────┤
 4. │  Check Resources                        │  ← CPU, memory, disk
    ├─────────────────────────────────────────┤
 3. │  Inspect Configuration                  │  ← env vars, mounts, cmd
    ├─────────────────────────────────────────┤
 2. │  Read the Logs                          │  ← application output
    ├─────────────────────────────────────────┤
 1. │  Check Status                           │  ← is it even running?
    └─────────────────────────────────────────┘
```

---

## Step 1: Check Status

Before anything else, find out what state the container is in.

```bash
# What's running?
docker ps

# What's running AND what recently stopped?
docker ps -a

# For Compose stacks:
docker compose ps
```

What to look for:

| Status | Meaning | Next Step |
|--------|---------|-----------|
| `Up (healthy)` | Running and health check passing | Problem is elsewhere — check the app behavior, not the container |
| `Up X seconds` | Running but no health check or recently restarted | Could be a restart loop. Check restart count. |
| `Restarting (X)` | Crash loop — exits and restarts repeatedly | Go to Step 2 (logs) and check exit code |
| `Exited (0)` | Stopped normally | Expected? If not, check if the CMD finished or was wrong |
| `Exited (1)` | Application error | Go to Step 2 (logs) — app-level crash |
| `Exited (127)` | Command not found | Go to Step 3 (config) — wrong CMD or missing binary |
| `Exited (137)` | OOMKilled or SIGKILL | Go to Step 4 (resources) — likely out of memory |
| `Exited (143)` | SIGTERM (graceful stop) | Expected after `docker stop` — normal behavior |
| `Created` | Container exists but never started | Check for startup errors in events |

```bash
# Quick health summary for labeled resources
docker ps -a --filter "label=app=learn-docker-k8s" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## Step 2: Read the Logs

The most common place to find the answer. Always check logs before going deeper.

```bash
# Full logs
docker logs <container>

# Last 50 lines
docker logs --tail 50 <container>

# Follow (stream) new output
docker logs -f <container>

# With timestamps
docker logs -t <container>

# Logs since a specific time
docker logs --since 5m <container>
docker logs --since 2025-01-15T10:00:00 <container>
```

### What You're Looking For

- **Stack traces** — the application crashed with an unhandled exception
- **Connection errors** — `ECONNREFUSED`, `ETIMEDOUT`, `getaddrinfo ENOTFOUND` (DNS failure)
- **Permission errors** — `EACCES`, `Permission denied`, `cannot open file`
- **Missing configuration** — `undefined`, `not set`, `required environment variable`
- **Startup failures** — errors in the first few lines of output

### When Logs Are Empty

If `docker logs` shows nothing:

1. The container might have exited before writing any output
2. The application might be writing to a log file instead of stdout/stderr
3. The logging driver might be configured to send logs elsewhere

Check if the app writes to files:
```bash
docker exec <container> find /var/log -type f 2>/dev/null
docker exec <container> cat /app/logs/error.log 2>/dev/null
```

### The Container Logging Rule

Docker captures stdout and stderr from PID 1. That's it. This is why well-designed containerized applications follow the **12-Factor App** logging pattern: they write logs as event streams to stdout/stderr, not to files inside the container.

This matters for three reasons:
1. `docker logs` only works with stdout/stderr — file-based logs are invisible to Docker
2. Log aggregation systems (EFK, Loki, CloudWatch) read from the Docker log driver, which captures stdout/stderr
3. Container filesystems are ephemeral — logs written to files inside the container are lost when it's removed

If you encounter an app that writes to `/var/log/app.log` inside the container, the fix is usually to reconfigure the app to log to stdout, or to symlink the log file to `/dev/stdout`:

```dockerfile
# Common pattern: redirect log files to stdout
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log
```

This is a key 12-Factor principle: **treat logs as event streams**, not files. The container doesn't know or care where the logs end up — the platform handles routing.

---

## Step 3: Inspect Configuration

The container is misconfigured — wrong environment variables, wrong command, wrong mounts.

```bash
# Full inspection (JSON output)
docker inspect <container>

# Specific fields:
docker inspect <container> --format '{{.Config.Cmd}}'
docker inspect <container> --format '{{json .Config.Env}}' | python3 -m json.tool
docker inspect <container> --format '{{json .Mounts}}' | python3 -m json.tool
docker inspect <container> --format '{{.Config.Entrypoint}}'
docker inspect <container> --format '{{.State.ExitCode}}'
docker inspect <container> --format '{{.State.OOMKilled}}'
docker inspect <container> --format '{{.RestartCount}}'
```

### Common Configuration Problems

| Problem | What to Check | Command |
|---------|--------------|---------|
| Wrong database URL | `DATABASE_URL` env var | `docker inspect --format '{{json .Config.Env}}'` |
| Missing config file | Volume mounts | `docker inspect --format '{{json .Mounts}}'` |
| Wrong startup command | CMD / Entrypoint | `docker inspect --format '{{.Config.Cmd}} {{.Config.Entrypoint}}'` |
| Wrong working directory | Workdir | `docker inspect --format '{{.Config.WorkingDir}}'` |
| Port not exposed | Port config | `docker inspect --format '{{json .NetworkSettings.Ports}}'` |

### Interactive Inspection

If the container is running, you can `exec` into it:

```bash
# Open a shell
docker exec -it <container> /bin/sh
# or
docker exec -it <container> /bin/bash

# Check if the expected files exist
docker exec <container> ls -la /app/

# Check environment variables
docker exec <container> env

# Check if a port is listening
docker exec <container> netstat -tlnp
# or
docker exec <container> ss -tlnp
```

---

## Step 4: Check Resources

The container might be starved of CPU, memory, or disk space.

```bash
# Live resource usage for all containers
docker stats

# One-shot (no streaming)
docker stats --no-stream

# Specific container
docker stats <container>
```

Output columns:

| Column | What It Means |
|--------|--------------|
| CPU % | CPU usage (can exceed 100% on multi-core) |
| MEM USAGE / LIMIT | Current memory / maximum allowed |
| MEM % | Percentage of limit used |
| NET I/O | Network bytes in/out |
| BLOCK I/O | Disk bytes read/written |

### Danger Signs

- **MEM USAGE near LIMIT** — the container is about to be OOMKilled
- **CPU at 100%** — the container is CPU-throttled; might be an infinite loop or high load
- **NET I/O at 0** — the container might have no network connectivity

### Disk Space

```bash
# Docker disk usage summary
docker system df

# Detailed breakdown
docker system df -v
```

If Docker is running low on disk space, containers can fail to start, images can't be pulled, and volumes can't grow.

---

## Step 5: Test Connectivity

The container runs but can't reach other services.

```bash
# Check which networks the container is on
docker inspect <container> --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool

# DNS resolution from inside the container
docker exec <container> nslookup <service-name>
docker exec <container> getent hosts <service-name>

# Connectivity test
docker exec <container> ping -c 3 <service-name>
docker exec <container> wget -qO- http://<service-name>:<port>/health
docker exec <container> curl -sf http://<service-name>:<port>/health

# Check what the container can see
docker exec <container> cat /etc/resolv.conf
```

### Common Network Problems

| Symptom | Likely Cause | Check |
|---------|-------------|-------|
| `getaddrinfo ENOTFOUND` | Wrong service name or not on same network | `docker network inspect <network>` |
| `ECONNREFUSED` | Target service not running or wrong port | `docker ps` on the target |
| `ETIMEDOUT` | Firewall, wrong network, or service overloaded | Network membership, `docker stats` on target |
| Works by IP but not name | DNS issue — probably on default bridge | Must be on user-defined network |

---

## Step 6: Examine the Image

The problem might be in how the image was built, not how the container is configured.

```bash
# Image layer history
docker history <image>
docker history <image> --no-trunc    # full commands

# What files changed since the image was built?
docker diff <container>

# Inspect image metadata
docker inspect <image> --format '{{json .Config.Cmd}}'
docker inspect <image> --format '{{json .Config.Env}}'
```

### `docker diff` Output

`docker diff` shows files that were added (`A`), changed (`C`), or deleted (`D`) in the container's writable layer since it started:

```bash
$ docker diff learn-ch07-api-1
C /app
A /app/logs/error.log
C /tmp
A /tmp/something-unexpected
```

This is useful for detecting:
- Files the app created at runtime that shouldn't be there
- Configuration files that were modified unexpectedly
- Temp files consuming disk space

---

## The Full Workflow in Practice

Here's how Sarah debugs a crashing container:

```bash
# 1. Status — what's happening?
docker compose ps
# → backend: Restarting (1)

# 2. Logs — what does the app say?
docker compose logs --tail 30 backend
# → "Error: ECONNREFUSED 172.18.0.5:5432"

# 3. Inspect — is the config right?
docker inspect learn-ch07-backend-1 --format '{{json .Config.Env}}' | python3 -m json.tool
# → DATABASE_URL looks correct...

# 4. Resources — is something starved?
docker stats --no-stream
# → postgres: 512M / 512M ← OOMKilled!

# 5. Connectivity — can it reach postgres?
docker exec learn-ch07-backend-1 ping -c 1 postgres
# → (can't exec — container keeps restarting)

# 6. Image — was it built correctly?
docker history learn-ch07-backend
# → looks fine

# Root cause: Postgres was OOMKilled (512M limit hit), so the backend
# can't connect. Fix: increase postgres memory limit or fix the query
# that's consuming all the memory.
```

---

## Summary

The 6-Step Debugging Ladder:

1. **Check Status** — `docker ps -a`, `docker compose ps`
2. **Read Logs** — `docker logs`, `docker compose logs`
3. **Inspect Config** — `docker inspect`, env vars, mounts, CMD
4. **Check Resources** — `docker stats`, `docker system df`
5. **Test Connectivity** — DNS, ping, curl from inside the container
6. **Examine Image** — `docker history`, `docker diff`

Most problems are found in steps 1–3. Steps 4–6 are for trickier issues. The key is to work systematically, not randomly.

Next: exit codes tell you *how* a container died. Let's learn to read them.
