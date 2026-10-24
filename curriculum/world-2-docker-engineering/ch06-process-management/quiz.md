# Chapter 6 Quiz: The Zombie Barista

> "PID 1 doesn't sound important until it costs you 10 seconds per deploy across 50 containers. Let's make sure you really get this."
> — Sarah

---

## Question 1

You have a Dockerfile with:

```dockerfile
CMD node server.js
```

You run `docker stop` on the container and it takes exactly 10 seconds before exiting. What is happening, and what's the fix?

A) Node.js doesn't support SIGTERM. Use `docker kill` instead.

B) The `CMD` is in shell form, so Docker wraps it as `/bin/sh -c "node server.js"`. The shell becomes PID 1 and doesn't forward SIGTERM to the Node.js process. Docker waits 10 seconds, then sends SIGKILL. Fix: use exec form `CMD ["node", "server.js"]`.

C) The 10-second wait is Docker rebuilding the image layer cache. Add `--no-cache` to `docker stop`.

D) SIGTERM is only supported on Linux. On macOS, Docker uses a different signal.

<details>
<summary>Answer</summary>

**B** is correct.

Shell form (`CMD node server.js`) wraps the command in `/bin/sh -c "node server.js"`. The shell becomes PID 1 and receives SIGTERM from `docker stop`, but `/bin/sh` doesn't forward signals to child processes. The Node.js process never receives the signal. After 10 seconds (the default grace period), Docker sends SIGKILL to forcefully terminate the container.

The fix is exec form: `CMD ["node", "server.js"]`, which runs Node.js directly as PID 1 and ensures it receives SIGTERM.

</details>

---

## Question 2

An entrypoint script has this at the end:

```bash
#!/bin/sh
echo "Running migrations..."
# migration logic here
node server.js
```

What's wrong, and what would you change?

A) Nothing — this is the correct pattern for entrypoint scripts

B) The script should use `exec node server.js` instead of `node server.js`. Without `exec`, the shell remains as PID 1 and the Node.js process is a child — it won't receive SIGTERM directly.

C) The `#!/bin/sh` should be `#!/bin/bash` for signal support

D) The migration logic should be in a separate container, not the entrypoint

<details>
<summary>Answer</summary>

**B** is correct.

Without `exec`, the process tree looks like:
```
PID 1: /bin/sh /entrypoint.sh     ← shell stays running
PID 7: node server.js             ← child process
```

SIGTERM goes to PID 1 (the shell), which doesn't forward it. With `exec node server.js`, the shell is replaced by the Node.js process:
```
PID 1: node server.js             ← directly receives SIGTERM
```

Option D mentions a valid pattern (init containers in Kubernetes), but isn't what's wrong with the current script. The `exec` keyword is the specific fix needed.

</details>

---

## Question 3

You run `docker top` on a container and see:

```
PID   PPID   STAT   CMD
1     0      Ss     node worker.js
15    1      Z      [task-1] <defunct>
23    1      Z      [task-2] <defunct>
31    1      Z      [task-3] <defunct>
```

What are the `Z` / `[defunct]` entries, and how do you fix them?

A) They are crashed processes. Restart the container to clean them up.

B) They are zombie processes — finished children whose exit status hasn't been collected. Fix by adding an init process (e.g., `init: true` in Compose or install tini), or by modifying the application to properly reap children with `wait()`.

C) They are system processes Docker needs to run. They're normal and harmless.

D) The container is running out of memory and processes are being killed.

<details>
<summary>Answer</summary>

**B** is correct.

Zombie processes (stat `Z`, shown as `[defunct]`) are child processes that have finished execution but whose parent (PID 1, `node worker.js`) hasn't called `wait()` to collect their exit status. They consume a slot in the process table and accumulate over time.

Solutions:
1. **Init process:** Add `init: true` in Compose or use tini/dumb-init as ENTRYPOINT — the init process automatically reaps zombies
2. **Application fix:** Handle `SIGCHLD` and call `wait()` in the application code
3. **Docker --init flag:** `docker run --init ...` uses Docker's built-in tini

Option A (restart) temporarily clears them but they'll accumulate again. The root cause needs to be addressed.

</details>

---

## Question 4

A Dockerfile has:

```dockerfile
ENTRYPOINT python app.py
CMD ["--debug"]
```

What does the container run when started with `docker run myimage`?

A) `python app.py --debug`

B) `python app.py` — the `CMD ["--debug"]` is silently ignored because ENTRYPOINT is in shell form

C) `--debug` only — CMD overrides ENTRYPOINT

D) An error — you can't use both ENTRYPOINT and CMD

<details>
<summary>Answer</summary>

**B** is correct.

When ENTRYPOINT is in **shell form** (no brackets), Docker wraps it as:
```
/bin/sh -c "python app.py"
```

The shell runs the exact string `"python app.py"` and ignores CMD entirely. The `--debug` flag is silently dropped.

For CMD to be appended to ENTRYPOINT, ENTRYPOINT must be in **exec form**:
```dockerfile
ENTRYPOINT ["python", "app.py"]
CMD ["--debug"]
```

This runs: `python app.py --debug`.

**Rule:** Always use exec form for ENTRYPOINT. Shell form ENTRYPOINT + CMD is a common source of silent bugs.

</details>

---

## Question 5

In Docker Compose, what does `init: true` do?

A) It runs `docker init` to create a Dockerfile for the service

B) It adds a lightweight init process (tini) as PID 1 that forwards signals to the main process and reaps zombie child processes

C) It initializes the container's filesystem with default files

D) It forces the container to wait for all dependencies to be initialized before starting

<details>
<summary>Answer</summary>

**B** is correct.

`init: true` is equivalent to `docker run --init`. It uses Docker's built-in tini binary as PID 1. tini does two critical things:

1. **Forwards signals:** When `docker stop` sends SIGTERM, tini forwards it to the main process
2. **Reaps zombies:** tini automatically calls `wait()` for any orphaned child processes, preventing zombie accumulation

The process tree with `init: true`:
```
PID 1: /sbin/tini -- node worker.js    ← tini (reaps + forwards)
PID 7: node worker.js                  ← your app (gets SIGTERM via tini)
```

Use it when your application spawns child processes and doesn't handle zombie reaping itself.

</details>
