# Chapter 5 Quiz: The Symphony of Steam

> "Before we move on, let me make sure things actually stuck. These are the kinds of questions you'll get asked in a job interview — or that you'll wish you knew the answer to at 2 AM."
> — Sarah

---

## Question 1

You have a `docker-compose.yml` with two services: `api` and `postgres`. You add this to the `api` service:

```yaml
depends_on:
  - postgres
```

You run `docker compose up`. On the first run, the `api` crashes with a connection refused error. What is the most likely cause, and what is the correct fix?

A) The `depends_on` syntax is wrong — it should be `depends_on: [postgres]`

B) `depends_on` only waits for the `postgres` container to start, not for the Postgres server inside it to be ready. Fix: add a `healthcheck` to `postgres` and change `depends_on` to use `condition: service_healthy`

C) The `postgres` image doesn't support health checks. Fix: write a custom wait script in the `api` Dockerfile

D) `depends_on` is only for Kubernetes, not Docker Compose

<details>
<summary>Answer</summary>

**B** is correct.

`depends_on` (basic form) only controls container start order. The Postgres *container* may be running while the Postgres *database process* is still initializing and not yet accepting connections. The fix is to add a `healthcheck` to the `postgres` service using `pg_isready`, then update `depends_on` in `api` to use `condition: service_healthy`.

The other options are incorrect: the list syntax `[postgres]` is valid YAML but equivalent to the block form. Many images (including the official Postgres image) support health checks. And `depends_on` is a Docker Compose concept, not Kubernetes.

</details>

---

## Question 2

A teammate runs `docker compose up -d` and then asks: "Why isn't my code change showing up? I edited `server.js` but the old version is still running."

What is the most likely explanation, and what command should they run?

A) They need to restart Docker Desktop

B) Compose cached the image from the last build. They should run `docker compose up -d --build` to force a rebuild

C) They forgot to run `npm install` before starting Compose

D) The `server.js` changes are only visible after running `docker compose restart`

<details>
<summary>Answer</summary>

**B** is correct.

When you use `build:` in a Compose service, Compose builds the image once and caches it. Running `docker compose up -d` again does not rebuild the image unless you pass `--build`. The correct command is:

```bash
docker compose up -d --build
```

This forces Docker to re-run the build, pick up the code changes, create a new image, and restart the container with the updated image.

`docker compose restart` only restarts the container without rebuilding the image, so the change would still not appear.

</details>

---

## Question 3

You are reviewing a pull request. The diff includes this section of `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: Tr0ub4dor&3
      POSTGRES_USER: admin
```

What should your review comment say, and what should the fix be?

A) Looks fine — environment variables in Compose files are always encrypted at rest

B) The password is weak. It should be at least 32 characters

C) The password is hardcoded in plain text in a file that will be committed to the repository. It should be moved to a `.env` file, referenced as `${POSTGRES_PASSWORD}`, and `.env` must be added to `.gitignore`

D) The `POSTGRES_USER` should not be `admin` — it should be `postgres` for compatibility

<details>
<summary>Answer</summary>

**C** is correct.

Hardcoding secrets in `docker-compose.yml` is a security vulnerability. The file will be committed to version control, and anyone who can read the repository — including future contributors, security auditors, or an attacker who gains access to the repo — can see the credentials.

The correct pattern:

1. Create `.env` with `POSTGRES_PASSWORD=Tr0ub4dor&3`
2. Add `.env` to `.gitignore`
3. Create `.env.example` with `POSTGRES_PASSWORD=change-me`
4. In `docker-compose.yml`: `POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}`

Password strength (B) is a separate concern, and the username (D) is irrelevant to the security issue being raised.

</details>

---

## Question 4

You want to add a database administration tool (Adminer) to your Compose file. It should be available when developers run `docker compose --profile dev up`, but should never start in a production deployment that runs just `docker compose up`.

Which configuration achieves this?

**Option A:**
```yaml
adminer:
  image: adminer
  environment:
    RUN_IN: dev
```

**Option B:**
```yaml
adminer:
  image: adminer
  profiles:
    - dev
```

**Option C:**
```yaml
adminer:
  image: adminer
  deploy:
    replicas: 0
```

**Option D:**
```yaml
adminer:
  image: adminer
  restart: "no"
```

<details>
<summary>Answer</summary>

**Option B** is correct.

The `profiles:` key is exactly designed for this use case. Services with a profile only start when that profile is explicitly activated:

```bash
docker compose up -d                   # adminer does NOT start
docker compose --profile dev up -d     # adminer starts
```

Option A would start Adminer every time — the `environment` key has no effect on whether a service starts.

Option C uses `deploy.replicas` which is a Docker Swarm concept and does not control startup behavior in standalone Compose.

Option D (`restart: "no"`) means the container will not be automatically restarted if it stops, but it would still start initially with `docker compose up`.

</details>

---

## Question 5

Your `docker-compose.yml` has a backend service with `ports: ["3000:3000"]`. You try to scale it:

```bash
docker compose up -d --scale backend=3
```

It fails with an error about port 3000 already being in use. What's happening and what's the correct fix?

A) Docker Compose doesn't support scaling — you need Docker Swarm for that

B) Each scaled instance tries to bind the same host port 3000. Fix: remove the host port mapping and use a reverse proxy, or use `expose` instead of `ports`

C) The backend service needs `deploy.replicas: 3` instead of `--scale`

D) You need to add `network_mode: host` for scaling to work

<details>
<summary>Answer</summary>

**B** is correct.

When you use `ports: ["3000:3000"]`, the host port 3000 is a fixed mapping. Only one container can bind to a specific host port. When you scale to 3 instances, the second and third instances fail because port 3000 is already taken by the first.

The fixes:
1. Use `expose: ["3000"]` (internal only) and put a reverse proxy (Nginx, Traefik) in front
2. Use `ports: ["3000"]` (no host port specified) — Docker assigns random host ports
3. Use a port range: `ports: ["3000-3002:3000"]`

Option A is wrong — Compose supports `--scale`. Option C is partially valid (`deploy.replicas` works) but doesn't fix the port conflict. Option D (`network_mode: host`) would make things worse.

</details>

---

## Question 6

You have a base `docker-compose.yml` and a `docker-compose.override.yml`. The base file contains:

```yaml
services:
  backend:
    environment:
      NODE_ENV: production
      PORT: "3000"
```

The override file contains:

```yaml
services:
  backend:
    environment:
      NODE_ENV: development
      LOG_LEVEL: debug
```

What environment variables will the backend container have when you run `docker compose up`?

A) Only `NODE_ENV=development` and `LOG_LEVEL=debug` — the override replaces the entire environment block

B) `NODE_ENV=development`, `PORT="3000"`, and `LOG_LEVEL=debug` — the override merges with the base

C) `NODE_ENV=production`, `PORT="3000"`, and `LOG_LEVEL=debug` — base values take precedence

D) An error — you can't define environment in both files

<details>
<summary>Answer</summary>

**B** is correct.

When Compose merges files, `environment` is treated as a map (key-value pairs). Maps are merged, not replaced:

- `NODE_ENV`: both files define it → override wins → `development`
- `PORT`: only in base → kept → `"3000"`
- `LOG_LEVEL`: only in override → added → `debug`

This is a critical distinction: **maps merge, scalars replace**. If `command:` were overridden, the base command would be completely replaced. But `environment` and `labels` are maps, so they merge with override values winning on conflicts.

You can verify with `docker compose config` to see the resolved configuration.

</details>

---

## Question 7

A container in your Compose stack has `deploy.resources.limits.memory: 256M`. You notice the container keeps getting killed with exit code 137. `docker inspect` shows `OOMKilled: true`. What's happening?

A) The 256M limit is a soft limit — Docker only logs a warning, it doesn't enforce it

B) The container's application is using more than 256 MB of memory. The Linux kernel's OOM killer terminates the process when it exceeds the hard limit. You need to either increase the limit or fix the memory usage.

C) Exit code 137 means the container received SIGTERM — it's a graceful shutdown, not OOM

D) The `deploy.resources` section only works with Docker Swarm, not standalone Compose

<details>
<summary>Answer</summary>

**B** is correct.

`deploy.resources.limits.memory` sets a hard cap enforced by Linux cgroups. When a container's memory usage exceeds this limit, the kernel's OOM (Out of Memory) killer terminates the process with SIGKILL (signal 9). The exit code 137 = 128 + 9 (SIGKILL).

The fix depends on the cause:
- If the app has a memory leak → fix the app
- If the app legitimately needs more memory → increase the limit
- If you're unsure → use `docker stats` to watch memory usage over time

Option A is wrong — `limits` is a hard cap (unlike `reservations`, which is a soft guarantee). Option C is wrong — exit code 137 is SIGKILL, not SIGTERM (which would be 143 = 128 + 15). Option D is wrong — `deploy.resources` works in standalone Compose with modern Docker versions.

</details>
