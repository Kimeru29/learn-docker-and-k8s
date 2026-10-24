# Lesson 6.1: PID 1 and Signals

> "Every time we deploy, the containers take 10 seconds to stop. I checked — our graceful shutdown code works perfectly outside Docker. Inside Docker, it's like the app never receives the shutdown signal."
> — You, confused

---

## Why PID 1 Matters

On a regular Linux system, PID 1 is `init` (or `systemd`). It's special:

1. It receives signals from the kernel
2. It reaps orphaned child processes (prevents zombies)
3. It's the parent of all other processes in the system

In a Docker container, whatever process is specified in your `CMD` or `ENTRYPOINT` becomes PID 1. And here's the problem: **most applications are not designed to be PID 1.** They don't handle signals the way PID 1 is expected to. They don't reap zombie children. They weren't built for that job.

This matters because of how `docker stop` works.

---

## What Happens When You Run `docker stop`

```
docker stop <container>
        │
        ▼
  ┌─────────────┐
  │  Send        │
  │  SIGTERM     │──────► PID 1 inside the container
  │  to PID 1    │
  └─────────────┘
        │
        ▼
  ┌─────────────┐
  │  Wait up to  │
  │  10 seconds  │        (configurable with --time flag)
  │  (grace      │
  │   period)    │
  └─────────────┘
        │
        ▼
  ┌─────────────┐
  │  If still    │
  │  running:    │
  │  SIGKILL     │──────► Forcefully terminates the process
  └─────────────┘
```

1. Docker sends **SIGTERM** (signal 15) to PID 1 inside the container
2. It waits up to 10 seconds (the grace period)
3. If PID 1 hasn't exited, Docker sends **SIGKILL** (signal 9) — instant death, no cleanup

If your application handles SIGTERM correctly, it can:
- Finish processing in-flight requests
- Close database connections
- Flush caches and buffers
- Write final log entries
- Exit cleanly

If it *doesn't* handle SIGTERM, Docker waits the full 10 seconds and then kills it. Every. Single. Time.

---

## The Shell Form Problem

Here is the most common cause of the 10-second stop problem. Compare these two Dockerfiles:

### Exec Form (correct)

```dockerfile
CMD ["node", "server.js"]
```

Docker runs: `node server.js` as PID 1.

```
PID 1: node server.js     ← receives SIGTERM directly
```

### Shell Form (problematic)

```dockerfile
CMD node server.js
```

Docker runs: `/bin/sh -c "node server.js"` — it wraps your command in a shell.

```
PID 1: /bin/sh -c "node server.js"    ← receives SIGTERM
PID 7: node server.js                 ← does NOT receive SIGTERM
```

The shell (`/bin/sh`) becomes PID 1. When Docker sends SIGTERM, **the shell receives it, not your application.** And here's the problem: most shells do not forward signals to their child processes. The shell just ignores SIGTERM. Docker waits 10 seconds. Docker sends SIGKILL. Your app is killed without any chance to clean up.

### How to Tell the Difference

```dockerfile
# Exec form — JSON array, no shell wrapper
CMD ["node", "server.js"]
ENTRYPOINT ["python", "app.py"]

# Shell form — plain string, wrapped in /bin/sh -c
CMD node server.js
ENTRYPOINT python app.py
```

The difference is subtle but critical: **brackets = exec form, no brackets = shell form.**

---

## Seeing It In Action

Let's see the difference. Here's an app that handles SIGTERM:

```javascript
// server.js
const http = require('http');

const server = http.createServer((req, res) => {
  res.end('Hello from NoCappuccino\n');
});

server.listen(3000, () => {
  console.log('Server listening on port 3000');
});

// Handle SIGTERM gracefully
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed. Goodbye!');
    process.exit(0);
  });
});
```

**With exec form** (`CMD ["node", "server.js"]`):

```bash
$ docker stop learn-ch06-exec
# Output in container logs:
# SIGTERM received. Shutting down gracefully...
# Server closed. Goodbye!
# Container exits in ~0.5 seconds
```

**With shell form** (`CMD node server.js`):

```bash
$ docker stop learn-ch06-shell
# ... 10 seconds of silence ...
# Container killed with SIGKILL
# No graceful shutdown message
# No cleanup happened
```

Same application code. Different Dockerfile instruction. Completely different behavior.

---

## Signal Reference

| Signal | Number | Default Behavior | Sent By |
|--------|--------|-----------------|---------|
| SIGTERM | 15 | Terminate (can be caught) | `docker stop`, Kubernetes, orchestrators |
| SIGKILL | 9 | Kill immediately (cannot be caught) | Docker after grace period, OOM killer |
| SIGINT | 2 | Interrupt (Ctrl+C) | `docker run` in foreground + Ctrl+C |
| SIGHUP | 1 | Hangup / reload config | Manual signal, some orchestrators |
| SIGUSR1/2 | 10/12 | User-defined | Application-specific (e.g., log rotation) |

The key insight: **SIGTERM is a request. SIGKILL is an order.** Your app can catch and handle SIGTERM. It cannot catch SIGKILL. This is why graceful shutdown code must respond to SIGTERM — once SIGKILL arrives, it's too late.

---

## Common Signal Handlers

### Node.js

```javascript
process.on('SIGTERM', () => {
  console.log('SIGTERM received');
  // Close server, DB connections, etc.
  server.close(() => process.exit(0));
});
```

### Python

```python
import signal, sys

def handle_sigterm(signum, frame):
    print("SIGTERM received")
    # Cleanup logic here
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_sigterm)
```

### Go

```go
sigChan := make(chan os.Signal, 1)
signal.Notify(sigChan, syscall.SIGTERM)

go func() {
    <-sigChan
    log.Println("SIGTERM received")
    // Cleanup logic
    server.Shutdown(context.Background())
}()
```

### Bash

```bash
trap 'echo "SIGTERM received"; cleanup; exit 0' SIGTERM

cleanup() {
  # Stop background processes, flush files, etc.
  kill $(jobs -p) 2>/dev/null
  wait
}
```

---

## The `STOPSIGNAL` Instruction

Some applications use a different signal for graceful shutdown. You can change which signal `docker stop` sends:

```dockerfile
# Nginx uses SIGQUIT for graceful shutdown
STOPSIGNAL SIGQUIT

# Default is SIGTERM for most images
STOPSIGNAL SIGTERM
```

You can also override at runtime:

```bash
docker stop --signal SIGQUIT learn-ch06-nginx
```

---

## Diagnosing Signal Issues

### Check what PID 1 actually is

```bash
docker top learn-ch06-worker
```

If PID 1 is `/bin/sh -c "..."`, you have the shell form problem.

### Time the stop

```bash
time docker stop learn-ch06-worker
```

If it consistently takes ~10 seconds, the signal isn't being handled.

### Change the grace period

```bash
# Give it 30 seconds instead of 10
docker stop --time 30 learn-ch06-worker

# Or in docker-compose.yml:
services:
  worker:
    stop_grace_period: 30s
```

This doesn't fix the root cause — it just gives your app more time. The real fix is proper signal handling.

---

## Summary

- PID 1 in a container receives signals from `docker stop` (SIGTERM, then SIGKILL)
- **Shell form** (`CMD node server.js`) wraps the command in `/bin/sh`, which does not forward signals — your app never gets SIGTERM
- **Exec form** (`CMD ["node", "server.js"]`) runs the app directly as PID 1 — signals are delivered correctly
- If `docker stop` consistently takes 10 seconds, you likely have a shell form problem or missing signal handler
- Use `docker top` to check what PID 1 actually is
- Always implement SIGTERM handlers in your application for graceful shutdown
- `SIGTERM` is a request (catchable); `SIGKILL` is an order (uncatchable)

Next: ENTRYPOINT and CMD look similar, but they interact in ways that surprise almost everyone.
