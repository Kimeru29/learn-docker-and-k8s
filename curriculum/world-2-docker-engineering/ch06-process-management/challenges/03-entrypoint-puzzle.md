# Challenge 6.3: The ENTRYPOINT Puzzle

> "The intern's Dockerfile looked fine until we tried to run the tests. `docker compose run backend npm test` doesn't work. The migrations don't run either. Something is very wrong with how ENTRYPOINT and CMD are set up."
> — Sarah

---

## The Situation

A junior developer wrote a Dockerfile for the NoCappuccino API. It works for running the server, but:

1. `docker compose run api npm test` doesn't run the tests — it still starts the server
2. The entrypoint script is supposed to run database migrations before starting the app, but the migrations never execute
3. The container can't be stopped gracefully (10-second SIGKILL again)

There are multiple problems with the Dockerfile. Your job is to find and fix them all.

---

## Setup

Create the following files.

**`entrypoint.sh`** — supposed to run setup before the main command:

```bash
#!/bin/sh
echo "=== Entrypoint ==="
echo "Running database migrations..."
# Simulate migration
echo "CREATE TABLE IF NOT EXISTS coffees..." > /dev/null
echo "Migrations complete."

echo "Starting: $@"
$@
```

**`server.js`** — a simple API server:

```javascript
const http = require('http');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API\n');
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  server.close(() => {
    console.log('Server closed gracefully');
    process.exit(0);
  });
});

server.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});
```

**`Dockerfile`** (the broken version):

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY entrypoint.sh .
COPY server.js .

RUN chmod +x entrypoint.sh

ENTRYPOINT ./entrypoint.sh
CMD node server.js
```

**`docker-compose.yml`**:

```yaml
name: learn-ch06

services:
  api:
    build: .
    ports:
      - "3000:3000"
    labels:
      app: learn-docker-k8s
      world: w02
```

---

## Your Task

Build the image and investigate. You should find multiple problems:

1. **The migration script doesn't run** — check the logs for the "Running database migrations..." message
2. **CMD is being ignored** — the `CMD node server.js` line has no effect
3. **Command override doesn't work** — `docker compose run api echo hello` should print "hello" but does something else
4. **Graceful shutdown fails** — the container takes 10 seconds to stop

Find the root causes and fix both `entrypoint.sh` and the `Dockerfile` so that:

- The entrypoint script runs migrations before the main command
- The default CMD starts the server
- `docker compose run api echo hello` prints "=== Entrypoint ===" then "hello"
- `docker stop` completes in under 2 seconds

---

## Success Criteria

Run the verification script:

```bash
bash challenges/verify.sh
```

The script checks:
1. The API container is running and responding on port 3000
2. Container logs show the migration messages ("Running database migrations...")
3. `docker stop` completes in under 3 seconds
4. CMD can be overridden (the image supports `docker run <image> echo test`)

---

## Hints

<details>
<summary>Hint 1 — How many bugs are there?</summary>

There are three bugs, all related to ENTRYPOINT/CMD form:

1. The `ENTRYPOINT` is in **shell form** (`ENTRYPOINT ./entrypoint.sh` without brackets)
2. The `entrypoint.sh` script uses `$@` instead of `exec "$@"`
3. Shell form ENTRYPOINT causes CMD to be ignored entirely

Start by checking what actually runs as PID 1:
```bash
docker top learn-ch06-api-1
```

You'll see `/bin/sh -c "./entrypoint.sh"` as PID 1 — not the entrypoint script, not node.

</details>

<details>
<summary>Hint 2 — Shell form ENTRYPOINT and CMD interaction</summary>

When ENTRYPOINT is shell form, Docker wraps it as:
```
/bin/sh -c "./entrypoint.sh"
```

This means:
- CMD is **completely ignored** (the shell runs only the string it was given)
- The shell is PID 1, so signals go to the shell
- Your entrypoint script is a child of the shell, and your app is a grandchild

The fix for the Dockerfile: use exec form for ENTRYPOINT:
```dockerfile
ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]
```

Now CMD is appended to ENTRYPOINT: `./entrypoint.sh node server.js`

</details>

<details>
<summary>Hint 3 — The exec in the entrypoint script</summary>

Even with exec form ENTRYPOINT, there's still a problem. The entrypoint script runs `$@` (the CMD arguments), but without `exec`:

```bash
# BAD: script stays as a parent process
$@

# GOOD: exec replaces the script with the CMD process
exec "$@"
```

Without `exec`, the process tree is:
```
PID 1: ./entrypoint.sh          ← shell script is PID 1
PID 7: node server.js           ← app is a child, doesn't get SIGTERM
```

With `exec "$@"`:
```
PID 1: node server.js           ← app IS PID 1, gets SIGTERM directly
```

Also note: `$@` (unquoted) splits on spaces in arguments. `"$@"` (quoted) preserves argument boundaries. Always quote it.

The fixed entrypoint.sh:
```bash
#!/bin/sh
echo "=== Entrypoint ==="
echo "Running database migrations..."
echo "CREATE TABLE IF NOT EXISTS coffees..." > /dev/null
echo "Migrations complete."

echo "Starting: $@"
exec "$@"
```

The fixed Dockerfile:
```dockerfile
ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]
```

</details>

---

## Post-Challenge Debrief

**What you did:** Fixed three interrelated bugs: shell form ENTRYPOINT (which silently drops CMD), missing `exec` in the entrypoint script (which prevents signal delivery), and unquoted `$@` (which breaks multi-word arguments).

**Why it works:** Exec form ENTRYPOINT allows CMD to be appended as arguments. The `exec "$@"` in the entrypoint script replaces the shell with the actual application process, making it PID 1 and enabling direct signal delivery.

**Real-world connection:** The ENTRYPOINT + CMD + entrypoint script pattern is used by almost every official Docker image (PostgreSQL, Redis, Nginx, Node). Understanding how they interact is essential for debugging why containers behave differently than expected — especially when using `docker run <image> <custom-command>`.

**Interview angle:** "Walk me through what happens when a Docker container starts with an ENTRYPOINT script." The interviewer wants to hear: the script runs first, does initialization, then `exec`s the CMD to replace itself with the main process. Bonus points for explaining why `exec` matters for signal handling.

**Pro tip:** You can inspect any official Docker image's entrypoint script to learn patterns:
```bash
docker run --rm --entrypoint cat postgres:16 /usr/local/bin/docker-entrypoint.sh
```
The official Postgres entrypoint is a masterclass in initialization, configuration, and signal handling.
