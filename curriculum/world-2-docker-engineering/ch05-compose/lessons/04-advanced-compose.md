# Lesson 5.4: Advanced Compose

> "The dev setup works great. But staging keeps falling over because someone's test container ate 4 GB of RAM and took down the database. We need guardrails."
> — Sarah, after the third staging incident this week

---

## Beyond the Basics

Your Compose file works. Services start in order, secrets are safe, profiles separate dev from test. But there's a gap between "works on my machine" and "works in staging without taking down the entire server."

This lesson covers the features that bridge that gap: override files for environment-specific configs, resource limits to prevent runaway containers, logging configuration, and scaling services.

---

## Override Files

### The Problem

Your `docker-compose.yml` works perfectly for development. But staging needs different port mappings, production needs resource limits, and CI needs to skip the database UI entirely.

You could maintain three separate Compose files. You'd also hate yourself in two months.

### The Solution: `docker-compose.override.yml`

Docker Compose automatically loads two files when you run `docker compose up`:

1. `docker-compose.yml` — the base configuration
2. `docker-compose.override.yml` — overrides applied on top

The override file is merged with the base file. Properties in the override replace or extend the base.

```yaml
# docker-compose.yml — the base (committed to repo)
name: learn-ch05

services:
  backend:
    build: ./backend
    environment:
      DATABASE_URL: ${DATABASE_URL}
      PORT: "3000"
    networks:
      - app-net
```

```yaml
# docker-compose.override.yml — dev defaults (committed, but overridable)
services:
  backend:
    ports:
      - "3000:3000"            # expose to host for local testing
    environment:
      LOG_LEVEL: debug          # verbose logging in dev
    volumes:
      - ./backend:/app          # bind mount for hot reload
      - /app/node_modules       # preserve container's node_modules
```

The `override` file adds `ports`, appends to `environment`, and adds `volumes` — without duplicating the base configuration.

### Named Override Files

For non-default overrides, use the `-f` flag:

```bash
# Development (uses default override)
docker compose up -d

# Staging
docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d

# CI/CD
docker compose -f docker-compose.yml -f docker-compose.ci.yml up -d
```

When using `-f`, the automatic loading of `docker-compose.override.yml` is **disabled**. You must list every file explicitly.

### Merge Rules

Understanding how overrides merge is critical:

| Type | Behavior |
|------|----------|
| Scalar values (`image`, `command`) | Override replaces base |
| Maps (`environment`, `labels`) | Override merges with base (override wins on conflict) |
| Lists (`ports`, `volumes`, `networks`) | Override appends to base |
| `build` context | Override replaces base |

```yaml
# Base:
environment:
  NODE_ENV: development
  PORT: "3000"

# Override:
environment:
  NODE_ENV: staging          # replaces the base value
  LOG_LEVEL: warn            # added to the map

# Result:
environment:
  NODE_ENV: staging
  PORT: "3000"
  LOG_LEVEL: warn
```

### Verifying the Merge

Always check what Compose will actually use:

```bash
docker compose config
# or with explicit files:
docker compose -f docker-compose.yml -f docker-compose.staging.yml config
```

This prints the fully resolved, merged configuration — no surprises.

---

## Resource Limits

### Why Limits Matter

Last Tuesday, a test container had a memory leak. It consumed 4 GB over two hours, starving Postgres of memory. Postgres got OOMKilled (exit code 137), and all sessions were lost.

Without resource limits, one misbehaving container can take down everything on the host.

### Setting Limits in Compose

```yaml
services:
  backend:
    build: ./backend
    deploy:
      resources:
        limits:
          cpus: "1.0"          # max 1 CPU core
          memory: 512M         # max 512 MB RAM
        reservations:
          cpus: "0.25"         # guaranteed 0.25 CPU
          memory: 128M         # guaranteed 128 MB RAM
    labels:
      app: learn-docker-k8s
      world: w02
```

### Limits vs. Reservations

| Property | Meaning |
|----------|---------|
| `limits.memory` | Hard cap — container is OOMKilled if it exceeds this |
| `limits.cpus` | Max CPU time — container is throttled above this |
| `reservations.memory` | Guaranteed minimum — Docker ensures this is available |
| `reservations.cpus` | Guaranteed minimum CPU time |

**Rule of thumb:** Set limits on everything. Set reservations on critical services (databases, APIs) that must not be starved.

### Verifying Resource Limits

```bash
# Check limits are applied
docker inspect learn-ch05-backend-1 \
  --format '{{.HostConfig.Memory}} bytes / {{.HostConfig.NanoCpus}} nanoCPUs'

# Watch live usage
docker stats learn-ch05-backend-1
```

### Appropriate Limits by Service Type

| Service | Memory Limit | CPU Limit | Rationale |
|---------|-------------|-----------|-----------|
| Postgres | 512M–1G | 1.0 | Needs memory for query caching |
| Redis | 128M–256M | 0.5 | In-memory store, predictable usage |
| Node.js API | 256M–512M | 1.0 | V8 heap grows; cap it |
| Nginx frontend | 64M–128M | 0.25 | Static files, minimal resources |

---

## Logging Configuration

### The Problem

By default, Docker captures all stdout/stderr from each container and stores it in JSON log files on disk. In development, this is fine. In staging or production, a chatty service can fill the disk.

### Configuring Log Drivers

```yaml
services:
  backend:
    build: ./backend
    logging:
      driver: json-file
      options:
        max-size: "10m"        # rotate logs at 10 MB
        max-file: "3"          # keep 3 rotated files
        tag: "{{.Name}}"       # tag logs with container name
    labels:
      app: learn-docker-k8s
      world: w02
```

### Common Log Drivers

| Driver | Use Case |
|--------|----------|
| `json-file` | Default. Good for development with rotation. |
| `local` | Optimized format with built-in rotation. Good for production on single hosts. |
| `syslog` | Forward to syslog daemon |
| `fluentd` | Forward to Fluentd for centralized logging |
| `none` | Disable logging entirely (use with caution) |

### Setting Defaults for All Services

Instead of repeating logging config on every service, set a default in the `x-` extension:

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  backend:
    build: ./backend
    logging: *default-logging

  frontend:
    build: ./frontend
    logging: *default-logging
```

YAML anchors (`&default-logging`) and aliases (`*default-logging`) let you define once, reference everywhere. This is not a Compose feature — it's a YAML feature. It works in any Compose file.

---

## Scaling Services

### Running Multiple Instances

Need more backend workers? Scale them:

```bash
docker compose up -d --scale backend=3
```

This starts 3 instances of the `backend` service. Each gets a unique container name (`learn-ch05-backend-1`, `learn-ch05-backend-2`, `learn-ch05-backend-3`).

### Port Conflicts When Scaling

If the service maps a fixed host port, scaling fails:

```yaml
# This will fail with --scale backend=3
services:
  backend:
    ports:
      - "3000:3000"   # only one container can bind host port 3000
```

The fix: use a port range or let Docker assign random host ports:

```yaml
# Option 1: Let Docker pick host ports
services:
  backend:
    ports:
      - "3000"         # container port 3000, host port assigned dynamically

# Option 2: Use a reverse proxy (production approach)
services:
  backend:
    expose:
      - "3000"         # internal only — no host mapping
  
  nginx:
    image: nginx:1.25-alpine
    ports:
      - "80:80"        # single entry point
    # nginx config load-balances to backend instances
```

In production, you'd put a reverse proxy (Nginx, Traefik, Caddy) in front and never expose individual service ports to the host.

### Setting Scale in the Compose File

```yaml
services:
  worker:
    build: ./worker
    deploy:
      replicas: 3              # start 3 instances by default
      resources:
        limits:
          memory: 256M
    labels:
      app: learn-docker-k8s
      world: w02
```

The `deploy.replicas` key sets the default replica count. You can still override with `--scale`.

---

## Profiles for Production

In Lesson 3, you learned profiles for dev/test tools. Profiles also work for production-specific services:

```yaml
services:
  # Core services — always start
  backend:
    build: ./backend
    ...

  postgres:
    image: postgres:16-alpine
    ...

  # Dev tools — only in development
  adminer:
    image: adminer
    profiles: [dev]
    ...

  # Monitoring — only in production
  prometheus:
    image: prom/prometheus
    profiles: [monitoring]
    ...

  # Debug tools — only when explicitly needed
  pgcli:
    image: dencold/pgcli
    profiles: [debug]
    ...
```

```bash
# Development
docker compose --profile dev up -d

# Production with monitoring
docker compose --profile monitoring up -d

# Emergency debugging
docker compose --profile debug run pgcli
```

This keeps your Compose file as the single source of truth for all environments, without cluttering the default startup with tools that shouldn't always run.

---

## Putting It All Together

Here's a production-ready snippet combining override files, limits, logging, and scaling:

**`docker-compose.yml`** (base — committed):
```yaml
name: learn-ch05

x-labels: &default-labels
  app: learn-docker-k8s
  world: w02

x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  backend:
    build: ./backend
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      PORT: "3000"
    networks:
      - app-net
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
    logging: *default-logging
    labels:
      <<: *default-labels

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    logging: *default-logging
    labels:
      <<: *default-labels
```

**`docker-compose.override.yml`** (dev defaults — committed):
```yaml
services:
  backend:
    ports:
      - "3000:3000"
    environment:
      LOG_LEVEL: debug
    volumes:
      - ./backend:/app
      - /app/node_modules
```

**`docker-compose.staging.yml`** (staging overrides):
```yaml
services:
  backend:
    ports:
      - "3000:3000"
    environment:
      LOG_LEVEL: warn
    deploy:
      replicas: 2
```

---

## Summary

- **Override files** let you maintain one base config with environment-specific tweaks
- `docker-compose.override.yml` is loaded automatically; named overrides use `-f`
- **Resource limits** prevent runaway containers — set `deploy.resources.limits` on everything
- **Logging config** with `max-size` and `max-file` prevents disk exhaustion
- YAML anchors (`&name` / `*name`) reduce duplication across services
- **Scaling** with `--scale` or `deploy.replicas` runs multiple instances
- Fixed host port mappings conflict with scaling — use reverse proxies in production
- **Profiles** can segment services for dev, staging, production, and debugging
- Always verify your merged config with `docker compose config`

You now have the tools to write Compose files that work in development *and* survive staging. Time to prove it.
