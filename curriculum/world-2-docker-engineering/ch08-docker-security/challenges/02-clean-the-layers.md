# Challenge 8.2: Clean the Layers

> "Run `docker history` on our image. Layer 4. Right there. `ENV DB_PASSWORD=cloudbrew_production_p@ss`. That's been in every image we've pushed for the last three months."
> — Sarah, very calmly considering the severity

---

## The Situation

An intern wrote the NoCappuccino API Dockerfile six months ago. It works. It deploys. It also has database credentials baked into the image layer history. Anyone who can pull the image (which includes everyone with access to the container registry) can see the password.

The auditor found it in 30 seconds:

```bash
docker history learn-ch08-api --no-trunc | grep -i password
```

Your job: rebuild the image so that no secrets exist in any layer, and the application still works.

---

## Setup

Create the following files.

**`server.js`**:

```javascript
const http = require('http');

const DB_PASSWORD = process.env.DB_PASSWORD;
const DB_HOST = process.env.DB_HOST || 'postgres';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'ok',
      db_configured: !!DB_PASSWORD,
      db_host: DB_HOST
    }));
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API\n');
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});

server.listen(3000, () => {
  console.log('Server listening on port 3000');
  console.log(`Database: ${DB_HOST} / password ${DB_PASSWORD ? 'SET' : 'NOT SET'}`);
});
```

**`secrets.env`** — a file that should NOT be in the image:

```
DB_PASSWORD=cloudbrew_production_p@ss
API_KEY=sk-nocappuccino-12345-secret
JWT_SECRET=super-secret-jwt-key-do-not-share
```

**`Dockerfile`** (the insecure version):

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app

# BUG 1: Secret baked into ENV instruction
ENV DB_PASSWORD=cloudbrew_production_p@ss

# BUG 2: Entire directory copied — includes secrets.env
COPY . .

# BUG 3: Deleting the file doesn't remove it from the previous layer
RUN rm -f secrets.env

EXPOSE 3000
CMD ["node", "server.js"]
```

**`docker-compose.yml`**:

```yaml
name: learn-ch08

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

1. Build the insecure image and verify the secrets are visible:
   ```bash
   docker compose build
   docker history learn-ch08-api --no-trunc | grep -i password
   ```
2. Fix the Dockerfile so that:
   - No secrets appear in `docker history`
   - No secret files exist in any layer
   - The application still receives `DB_PASSWORD` at runtime
3. Create a `.dockerignore` that prevents `secrets.env` from entering the build context
4. Pass the database password through the Compose file using environment variables (from a `.env` file)

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The script checks:
1. The API container is running and `/health` responds
2. `docker history` does NOT contain any password or secret values
3. A `.dockerignore` file exists and includes `secrets.env`
4. The API reports `db_configured: true` (password is set at runtime)
5. The `ENV` instruction in the Dockerfile does NOT set `DB_PASSWORD`

---

## Hints

<details>
<summary>Hint 1 — Identify all the leaks</summary>

There are three separate leaks:

1. `ENV DB_PASSWORD=...` — visible in `docker inspect` and `docker history`
2. `COPY . .` — copies `secrets.env` into the image layer (even though it's deleted later)
3. `RUN rm -f secrets.env` — removes the file from the writable layer, but it still exists in the COPY layer

Check each one:
```bash
# Check ENV
docker inspect learn-ch08-api --format '{{json .Config.Env}}' | grep -i password

# Check history
docker history learn-ch08-api --no-trunc

# Check if secrets.env is in the layers
docker run --rm --entrypoint sh learn-ch08-api -c "cat /app/secrets.env 2>/dev/null || echo 'not found'"
# It might say "not found" but the file is still in an earlier layer!
```

</details>

<details>
<summary>Hint 2 — The fixes</summary>

1. **Remove the `ENV DB_PASSWORD` line** from the Dockerfile entirely. The password should be injected at runtime via Compose.

2. **Create a `.dockerignore` file:**
   ```
   secrets.env
   .env
   .env.*
   *.key
   *.pem
   .git
   node_modules
   ```

3. **Remove the `RUN rm -f secrets.env` line** — it's no longer needed because `.dockerignore` prevents the file from entering the build context.

4. **Inject the password at runtime** through the Compose file:
   ```yaml
   services:
     api:
       build: .
       ports:
         - "3000:3000"
       environment:
         DB_PASSWORD: ${DB_PASSWORD}
   ```

5. **Create a `.env` file** for Compose:
   ```
   DB_PASSWORD=runtime-password-here
   ```

</details>

<details>
<summary>Hint 3 — The complete solution</summary>

**`.dockerignore`:**
```
secrets.env
.env
.env.*
*.key
*.pem
.git
node_modules
```

**`Dockerfile`:**
```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY server.js package.json* ./

USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

Note: no `ENV DB_PASSWORD`, no `COPY . .`, no `RUN rm`. The Dockerfile is clean.

**`.env`** (for Compose — not committed):
```
DB_PASSWORD=runtime-secure-password
```

**`docker-compose.yml`:**
```yaml
name: learn-ch08

services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      DB_PASSWORD: ${DB_PASSWORD}
      DB_HOST: postgres
    labels:
      app: learn-docker-k8s
      world: w02
```

Verify:
```bash
docker compose up -d --build
docker history learn-ch08-api --no-trunc | grep -i password  # should find nothing
curl http://localhost:3000/health  # db_configured: true
```

</details>

---

## Post-Challenge Debrief

**What you did:** Removed database credentials from Docker image layers by eliminating the `ENV` instruction, adding a `.dockerignore`, using selective `COPY`, and injecting secrets at runtime through Compose environment variables.

**Why it works:** Docker image layers are immutable. Once a secret enters a layer (via `ENV`, `COPY`, or `RUN`), it's permanently accessible to anyone who can pull the image. The only fix is to prevent secrets from entering layers in the first place: use `.dockerignore` to block files, remove `ENV` for secrets, and inject credentials at runtime.

**Real-world connection:** Secret leakage through Docker layers is a recurring finding in security audits and bug bounty programs. AWS, Azure, and GCP container registries are full of images with accidentally baked-in credentials. This is why secret scanning is part of every mature CI/CD pipeline.

**Interview angle:** "How do you prevent secrets from leaking into Docker images?" Strong answer: never use `ENV` for secrets, use `.dockerignore`, multi-stage builds as a boundary, BuildKit secret mounts for build-time secrets, and inject runtime secrets via environment variables or secret managers.

**Pro tip:** Run `docker history <image> --no-trunc | grep -iE "password|secret|key|token"` on every image before pushing it to a registry. Add this check to your CI pipeline. Tools like Trivy and Docker Scout also scan for leaked secrets automatically.
