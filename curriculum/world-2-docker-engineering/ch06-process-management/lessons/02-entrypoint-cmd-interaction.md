# Lesson 6.2: ENTRYPOINT and CMD Interaction

> "I set CMD to run the API server, but when I pass arguments to `docker run` it runs something completely different. Then I switched to ENTRYPOINT and broke the test suite because `docker compose run backend npm test` stopped working."
> — A new developer, first week on the job

---

## Two Instructions, One Process

Both `ENTRYPOINT` and `CMD` define what runs when the container starts. But they play different roles, and the way they interact is one of the most confusing parts of Docker.

### The Simple Mental Model

| Instruction | Purpose | Overridable? |
|-------------|---------|-------------|
| `ENTRYPOINT` | The **executable** — what program to run | Only with `--entrypoint` |
| `CMD` | The **default arguments** — what to pass to the executable | By any argument after the image name |

Think of it as a command line:

```
ENTRYPOINT  CMD
    │        │
    ▼        ▼
  python   app.py
```

When both are present, Docker concatenates them: the container runs `ENTRYPOINT + CMD`.

---

## The Interaction Matrix

This table covers every combination. Study it — it shows up in interviews.

| ENTRYPOINT | CMD | Container Runs |
|------------|-----|----------------|
| Not set | `["node", "server.js"]` | `node server.js` |
| Not set | `node server.js` | `/bin/sh -c "node server.js"` |
| `["node"]` | `["server.js"]` | `node server.js` |
| `["node"]` | Not set | `node` (exits immediately — no file given) |
| `["node", "server.js"]` | `["--port", "3000"]` | `node server.js --port 3000` |
| `["/entrypoint.sh"]` | `["node", "server.js"]` | `/entrypoint.sh node server.js` |

### Key Rules

1. If only `CMD` is set, it's both the executable and the arguments
2. If both are set, `ENTRYPOINT` is the executable and `CMD` provides default arguments
3. If only `ENTRYPOINT` is set, there are no default arguments
4. Shell form in either instruction wraps in `/bin/sh -c` — **and shell form ENTRYPOINT ignores CMD entirely**

That last rule is the killer. Let's look at it.

---

## Shell Form ENTRYPOINT Ignores CMD

```dockerfile
# Shell form ENTRYPOINT — CMD is IGNORED
ENTRYPOINT python app.py
CMD ["--debug"]               # This is completely ignored!
```

The container runs: `/bin/sh -c "python app.py"`. The `CMD` argument `--debug` is silently dropped.

Why? Because shell form wraps the command in `/bin/sh -c "..."`. The shell doesn't know about CMD — it just runs the string it was given.

```dockerfile
# Exec form ENTRYPOINT — CMD is appended
ENTRYPOINT ["python", "app.py"]
CMD ["--debug"]               # This IS appended
```

The container runs: `python app.py --debug`. ✅

**Rule: Always use exec form for ENTRYPOINT.** Shell form ENTRYPOINT is almost never what you want.

---

## Override Behavior

### Overriding CMD (easy)

Anything after the image name in `docker run` replaces CMD:

```dockerfile
ENTRYPOINT ["python"]
CMD ["app.py"]
```

```bash
# Default: runs python app.py
docker run learn-ch06-app

# Override CMD: runs python test.py
docker run learn-ch06-app test.py

# Override CMD: runs python -c "print('hello')"
docker run learn-ch06-app -c "print('hello')"
```

This is the intended design: ENTRYPOINT is the fixed executable, CMD provides overridable defaults.

### Overriding ENTRYPOINT (explicit)

```bash
# Override ENTRYPOINT: runs /bin/sh instead of python
docker run --entrypoint /bin/sh learn-ch06-app

# Override both: runs bash -c "echo hello"
docker run --entrypoint bash learn-ch06-app -c "echo hello"
```

In Compose:

```yaml
services:
  backend:
    entrypoint: /bin/sh
    command: ["-c", "echo hello"]
```

### In Docker Compose

```yaml
services:
  backend:
    build: ./backend
    # This overrides CMD, not ENTRYPOINT:
    command: ["npm", "test"]
```

The `command:` key in Compose maps to CMD. To override ENTRYPOINT, use `entrypoint:`.

---

## When to Use Which

### CMD Only (most common)

Use for straightforward applications where the user might want to change the command entirely.

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]
```

Override: `docker run myapp npm test` — replaces the entire command.

**Use when:** You have a single-purpose image but want flexibility. Most application images use this pattern.

### ENTRYPOINT + CMD (the "tool" pattern)

Use when the image has a fixed purpose but accepts different arguments.

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .
ENTRYPOINT ["python", "manage.py"]
CMD ["runserver", "0.0.0.0:8000"]
```

Default: `python manage.py runserver 0.0.0.0:8000`
Override: `docker run myapp migrate` → `python manage.py migrate`
Override: `docker run myapp shell` → `python manage.py shell`

**Use when:** The executable is always the same, but subcommands or arguments vary.

### ENTRYPOINT Only (rare for applications)

Use for wrapper scripts that do setup before running the actual command.

```dockerfile
ENTRYPOINT ["/entrypoint.sh"]
# No CMD — the entrypoint script handles everything
```

**Use when:** You need initialization logic before the main process. But even then, you usually pair it with CMD.

---

## The Entrypoint Script Pattern

Many production images use an entrypoint script that does setup work and then `exec`s the main process:

```bash
#!/bin/sh
# /entrypoint.sh

# Wait for database
echo "Waiting for database..."
until pg_isready -h postgres -U brew; do
  sleep 1
done

# Run migrations
echo "Running migrations..."
python manage.py migrate

# Execute the CMD (passed as arguments to this script)
echo "Starting application..."
exec "$@"
```

```dockerfile
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

### The Critical `exec "$@"`

The `exec "$@"` at the end of the script is crucial:

- `"$@"` expands to all the arguments passed to the script (which is the CMD)
- `exec` replaces the shell process with the new command
- After `exec`, the main application **becomes PID 1** — it receives signals directly

Without `exec`:

```
PID 1: /bin/sh /entrypoint.sh       ← shell is PID 1 (bad)
PID 7: python manage.py runserver   ← app is a child process
```

With `exec`:

```
PID 1: python manage.py runserver   ← app IS PID 1 (good)
```

**Always use `exec "$@"` at the end of entrypoint scripts.**

---

## Common Mistakes

### Mistake 1: Shell form with arguments

```dockerfile
# BAD: shell form ENTRYPOINT, CMD ignored
ENTRYPOINT python app.py
CMD ["--port", "8000"]
# Actually runs: /bin/sh -c "python app.py" — port flag silently dropped

# GOOD: exec form, CMD appended
ENTRYPOINT ["python", "app.py"]
CMD ["--port", "8000"]
# Runs: python app.py --port 8000
```

### Mistake 2: Forgetting `exec` in entrypoint scripts

```bash
# BAD: no exec — shell stays as PID 1
#!/bin/sh
setup_stuff
node server.js   # shell is PID 1, node is a child

# GOOD: exec replaces shell with node
#!/bin/sh
setup_stuff
exec node server.js   # node becomes PID 1
```

### Mistake 3: Overriding the wrong thing in Compose

```yaml
# BAD: trying to change entrypoint with command
services:
  worker:
    command: ["python", "worker.py"]
    # If ENTRYPOINT is set in Dockerfile, this becomes arguments to ENTRYPOINT

# GOOD: explicitly override what you mean
services:
  worker:
    entrypoint: ["python"]         # override ENTRYPOINT
    command: ["worker.py"]         # override CMD
```

### Mistake 4: Multiple CMD/ENTRYPOINT in one Dockerfile

```dockerfile
# BAD: only the LAST one wins
CMD ["node", "api.js"]
CMD ["node", "worker.js"]       # this one wins, api.js never runs

# Same rule applies to ENTRYPOINT
ENTRYPOINT ["python"]
ENTRYPOINT ["node"]             # this one wins
```

---

## Inspecting ENTRYPOINT and CMD

```bash
# See what ENTRYPOINT and CMD are set to
docker inspect learn-ch06-app \
  --format 'ENTRYPOINT: {{json .Config.Entrypoint}}
CMD: {{json .Config.Cmd}}'
```

Output:
```
ENTRYPOINT: ["python","manage.py"]
CMD: ["runserver","0.0.0.0:8000"]
```

If ENTRYPOINT is `null`, the image uses CMD only.

---

## Summary

- `ENTRYPOINT` = the executable (fixed); `CMD` = default arguments (overridable)
- When both are set, Docker runs `ENTRYPOINT + CMD`
- Shell form ENTRYPOINT **ignores CMD entirely** — always use exec form
- `docker run myimage arg1 arg2` overrides CMD, not ENTRYPOINT
- Use `--entrypoint` to override ENTRYPOINT explicitly
- Entrypoint scripts should end with `exec "$@"` so the main process becomes PID 1
- In Compose, `command:` overrides CMD; `entrypoint:` overrides ENTRYPOINT
- Only the last `CMD` or `ENTRYPOINT` in a Dockerfile takes effect

Next: your app handles SIGTERM and ENTRYPOINT/CMD are correct. But what about zombie processes, restart policies, and apps that really shouldn't be PID 1?
