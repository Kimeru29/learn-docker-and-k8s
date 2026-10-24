# Challenge 7.1: The Silent Crash

> "The API container exits immediately. Exit code 1. But the logs just say 'Starting server...' and then nothing. No error, no stack trace. It was working on Friday."
> — Junior developer, 9:30 AM Monday

---

## The Situation

A junior developer deployed a config change on Friday afternoon (always a great idea). They went home for the weekend. On Monday morning, the API container won't start. It exits with code 1, but the logs show no error — just the startup message and then silence.

The developer's commit message says: "cleaned up config files." Ominous.

---

## Setup

Create the following files.

**`server.js`** — reads configuration from a file at startup:

```javascript
const http = require('http');
const fs = require('fs');
const path = require('path');

console.log('Starting server...');

// Read config file
const configPath = process.env.CONFIG_PATH || '/app/config/app.json';

let config;
try {
  const raw = fs.readFileSync(configPath, 'utf8');
  config = JSON.parse(raw);
  console.log(`Config loaded from ${configPath}`);
} catch (err) {
  // The bug: this logs to stderr, but some log setups miss stderr
  process.stderr.write(`Fatal: Cannot read config: ${err.message}\n`);
  process.exit(1);
}

const PORT = config.port || 3000;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', port: PORT }));
    return;
  }
  res.writeHead(200);
  res.end(`NoCappuccino API v${config.version}\n`);
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});

server.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
```

**`Dockerfile`**:

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY server.js .

# The config directory exists but is empty after the "cleanup"
RUN mkdir -p /app/config

CMD ["node", "server.js"]
```

**`docker-compose.yml`**:

```yaml
name: learn-ch07

services:
  api:
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

1. Build and start the container — observe that it exits immediately
2. Follow the 6-step debugging ladder to find the root cause
3. Fix the problem so the API starts and responds on `/health`

The container should run and respond to health checks. You need to figure out *why* it's crashing and provide the missing piece.

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The script checks:
1. The API container is running (not in a restart loop)
2. The `/health` endpoint responds on port 3000
3. The container has been running for more than 10 seconds (not crash-looping)

---

## Hints

<details>
<summary>Hint 1 — Follow the ladder</summary>

Step 1: Check status → `docker compose ps` — what exit code?
Step 2: Read logs → `docker compose logs api` — what does it say?

The logs show "Starting server..." but no error after that. The error is written to **stderr**, not stdout. Try:

```bash
docker compose logs api 2>&1
```

Or look more carefully — Docker captures both stdout and stderr by default. The error might be there but easy to miss in a sea of restart output.

</details>

<details>
<summary>Hint 2 — The missing piece</summary>

The server tries to read `/app/config/app.json`. The Dockerfile creates the `/app/config` directory but never puts a config file in it. The junior developer's "cleanup" removed the config file from the image.

Check what's in the config directory:

```bash
# If the container is crash-looping, override the command to keep it alive:
docker run --rm -it --entrypoint sh learn-ch07-api -c "ls -la /app/config/"
```

The directory is empty — no `app.json`.

</details>

<details>
<summary>Hint 3 — The fix</summary>

Create the missing config file. You have several valid options:

**Option A:** Create the config file in the Dockerfile:
```dockerfile
RUN mkdir -p /app/config
RUN echo '{"port": 3000, "version": "1.0.0"}' > /app/config/app.json
```

**Option B:** Mount a config file via Compose:
```yaml
services:
  api:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - ./config/app.json:/app/config/app.json:ro
```

(Create `./config/app.json` with `{"port": 3000, "version": "1.0.0"}`)

**Option C:** Use an environment variable to set the config path to a file that exists, or change the default in the code.

Any solution that provides a valid JSON config file at `/app/config/app.json` (or changes CONFIG_PATH) will work.

</details>

---

## Post-Challenge Debrief

**What you did:** Debugged a container that exited with code 1 and seemingly no error output. The root cause was a missing config file — the error was written to stderr and easy to overlook in restart loop noise.

**Why it works:** The 6-step ladder led you from "it's crashing" to "it's missing a config file" in a systematic way. Step 2 (logs) was the key — but you had to look carefully because the error was on stderr, which can be visually mixed with startup output.

**Real-world connection:** "It was working on Friday" is the most common incident report in software. The cause is almost always a config change, an environment variable change, or a missing file. The debugging skill is knowing where to look, not what the specific error is.

**Interview angle:** "A container exits with code 1 but the logs seem empty. How do you debug it?" The strong answer: check `docker logs` (includes stderr by default), `docker inspect` for the full state, and if the container exits too fast, override the entrypoint to keep it alive while you investigate.

**Pro tip:** Add a health check that validates critical config at startup. Instead of silently crashing, the container would start and immediately be marked unhealthy — which is much more visible in `docker compose ps` than a restart loop.
