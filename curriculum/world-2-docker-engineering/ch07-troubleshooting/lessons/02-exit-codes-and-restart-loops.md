# Lesson 7.2: Exit Codes and Restart Loops

> "Exit code 137. That's all the alert said. No stack trace, no error message. Just 137. The junior dev asked me 'what does 137 mean?' and I told him: 'Something killed your container. Something angry.'"
> — Sarah

---

## Exit Code Anatomy

When a container stops, the process inside exits with a numeric code. This code tells you *how* it died.

```bash
# Check exit code
docker inspect <container> --format '{{.State.ExitCode}}'

# Or see it in the status column
docker ps -a --format "table {{.Names}}\t{{.Status}}"
```

### The Exit Code Map

| Code | Meaning | Common Cause | First Action |
|------|---------|-------------|--------------|
| **0** | Success — clean exit | App finished its task, or `docker stop` with SIGTERM handled | Expected behavior. Check if the app should keep running. |
| **1** | General application error | Unhandled exception, failed assertion, missing dependency | Check `docker logs` — the error is in the output |
| **2** | Shell misuse | Invalid arguments to a shell builtin | Check CMD/ENTRYPOINT for syntax errors |
| **126** | Command not executable | File exists but lacks execute permission | `chmod +x` in Dockerfile |
| **127** | Command not found | Typo in CMD, binary not installed, wrong PATH | Check `docker inspect --format '{{.Config.Cmd}}'` |
| **137** | SIGKILL (128 + 9) | OOMKilled, `docker kill`, or force timeout | Check `docker inspect --format '{{.State.OOMKilled}}'` |
| **139** | SIGSEGV (128 + 11) | Segmentation fault — app crashed | Application bug — check core dumps and app logs |
| **143** | SIGTERM (128 + 15) | `docker stop` — graceful shutdown | Expected after `docker stop`. App handled SIGTERM. |

### The Signal Code Formula

Exit codes above 128 indicate the process was killed by a signal:

```
exit code = 128 + signal number
```

Examples:
- 137 = 128 + 9 (SIGKILL)
- 143 = 128 + 15 (SIGTERM)
- 139 = 128 + 11 (SIGSEGV)

---

## OOMKilled — Exit Code 137

The most dreaded exit code in containerland. Your container used more memory than its limit allows, and the Linux kernel's OOM (Out of Memory) killer terminated it.

### How to Confirm OOMKill

```bash
# Quick check
docker inspect <container> --format '{{.State.OOMKilled}}'
# true = confirmed OOMKill

# Detailed state
docker inspect <container> --format '{{json .State}}' | python3 -m json.tool
```

### Why OOMKill Happens

```
                Memory Usage Over Time
    
    Limit ─────────────────────────── X OOMKilled!
    │                              ╱
    │                           ╱
    │                        ╱
    │                     ╱
    │                  ╱          ← gradual leak
    │               ╱
    │            ╱
    │         ╱
    │      ╱
    │   ╱
    └──────────────────────────── Time
```

Common causes:
1. **Memory leak** — app allocates memory and never frees it
2. **Large dataset loaded into memory** — query returns 1M rows without streaming
3. **Limit too low** — the app legitimately needs more memory than allocated
4. **Fork bomb or runaway child processes** — each child consumes memory

### Monitoring Memory Before the Kill

```bash
# Watch memory usage live
docker stats <container>

# One-shot snapshot
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

If `MEM USAGE` approaches `LIMIT`, an OOMKill is imminent.

---

## Restart Loops

A restart loop happens when a container crashes on startup, gets restarted by the restart policy, crashes again, gets restarted again, and so on.

### Identifying a Restart Loop

```bash
$ docker ps
NAME              STATUS
learn-api-1       Restarting (1) 3 seconds ago

# Check restart count
docker inspect <container> --format '{{.RestartCount}}'
# 47 ← has restarted 47 times
```

### The Restart Policy Spectrum

```
                    ┌────────────────────────────┐
    "no"            │ Crash → dead. No restart.  │
                    └────────────────────────────┘
                    ┌────────────────────────────┐
    "on-failure"    │ Crash → restart            │
                    │ Clean exit → stay stopped   │
                    └────────────────────────────┘
                    ┌────────────────────────────┐
    "always"        │ Crash → restart            │
                    │ Clean exit → restart        │
                    │ Docker restart → restart    │
                    └────────────────────────────┘
                    ┌────────────────────────────┐
    "unless-stopped"│ Like "always", but stays   │
                    │ stopped after manual stop   │
                    └────────────────────────────┘
```

### The Restart Loop Problem

With `restart: always`, a container that crashes on startup enters an infinite loop:

```
Start → crash (exit 1) → restart (100ms delay) →
Start → crash (exit 1) → restart (200ms delay) →
Start → crash (exit 1) → restart (400ms delay) →
...
```

Docker applies exponential backoff (doubling the delay each time, up to ~1 minute), but the loop never stops. Meanwhile:
- Logs fill up with repeated crash output
- CPU is wasted on constant restarts
- The container never becomes healthy

### Breaking Out of a Restart Loop

```bash
# Stop the container (breaks the loop)
docker stop <container>

# Now you can safely read the logs
docker logs --tail 50 <container>

# Fix the root cause, then restart
docker start <container>
```

---

## Docker Events

`docker events` gives you a timeline of everything Docker is doing. It's invaluable for understanding the sequence of events during a failure.

```bash
# Stream events (live)
docker events

# Events from the last hour
docker events --since 1h

# Filter to specific container
docker events --filter container=learn-ch07-api-1

# Filter by event type
docker events --filter event=die
docker events --filter event=oom
docker events --filter event=health_status

# Compact format
docker events --format '{{.Time}} {{.Action}} {{.Actor.Attributes.name}}'
```

### Key Events to Watch For

| Event | Meaning |
|-------|---------|
| `create` | Container created |
| `start` | Container started |
| `die` | Container process exited (check `exitCode` attribute) |
| `kill` | Signal sent to container (check `signal` attribute) |
| `oom` | Container hit memory limit |
| `restart` | Container restarted by policy |
| `health_status: healthy` | Health check passing |
| `health_status: unhealthy` | Health check failing |

### Reading an OOMKill in Events

```bash
$ docker events --since 5m --filter container=learn-ch07-api-1
2025-01-15T03:17:00 container oom learn-ch07-api-1     ← memory limit hit
2025-01-15T03:17:00 container die learn-ch07-api-1 (exitCode=137)  ← killed
2025-01-15T03:17:01 container start learn-ch07-api-1   ← restart policy kicks in
```

### Reading a Crash Loop in Events

```bash
$ docker events --since 5m --filter container=learn-ch07-api-1
2025-01-15T03:17:00 container start learn-ch07-api-1
2025-01-15T03:17:01 container die learn-ch07-api-1 (exitCode=1)
2025-01-15T03:17:01 container restart learn-ch07-api-1
2025-01-15T03:17:02 container start learn-ch07-api-1
2025-01-15T03:17:03 container die learn-ch07-api-1 (exitCode=1)
2025-01-15T03:17:04 container restart learn-ch07-api-1
...
```

The rapid `start → die → restart` cycle is a crash loop.

---

## The `docker inspect` State Section

The `.State` section of `docker inspect` is the most information-dense diagnostic tool:

```bash
docker inspect <container> --format '{{json .State}}' | python3 -m json.tool
```

```json
{
  "Status": "exited",
  "Running": false,
  "Paused": false,
  "Restarting": false,
  "OOMKilled": true,
  "Dead": false,
  "Pid": 0,
  "ExitCode": 137,
  "Error": "",
  "StartedAt": "2025-01-15T03:17:00.000Z",
  "FinishedAt": "2025-01-15T03:17:42.000Z"
}
```

Key fields:
- `OOMKilled: true` — kernel killed it for memory
- `ExitCode: 137` — confirms SIGKILL
- `StartedAt` / `FinishedAt` — how long it ran before dying
- `Restarting: true` — currently in a restart loop
- `Error` — sometimes has extra context from Docker

---

## Summary

- **Exit codes tell a story:** 0 = success, 1 = app error, 127 = missing command, 137 = OOMKill, 143 = graceful SIGTERM
- Codes above 128 mean the process was killed by a signal: `exit code = 128 + signal number`
- **OOMKilled** = container exceeded its memory limit → check `docker stats` and `docker inspect .State.OOMKilled`
- **Restart loops** happen when a crash + `restart: always` creates an infinite cycle
- Break restart loops with `docker stop`, then read logs and fix the root cause
- **`docker events`** gives you a timeline of container lifecycle events — essential for understanding sequences
- The **`.State` section** of `docker inspect` is the most useful single command for diagnosis

Next: beyond logs and exit codes — advanced inspection tools for when the obvious checks don't reveal the problem.
