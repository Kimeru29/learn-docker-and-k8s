# Challenge 5.4: Production Compose

> "Someone's test container just ate 4 GB of memory and killed Postgres on staging. No resource limits, no log rotation, and every service is on the same flat network. This is not production-ready. Fix it."
> — Sarah, incident postmortem, 10:15 AM

---

## The Situation

Your Compose stack from the previous challenges works — for development. But when Dave deployed it to the staging server, things fell apart:

1. A backend container had a log-heavy debug mode enabled. In 48 hours, the logs consumed 12 GB of disk space.
2. The test-runner container (meant only for CI) consumed unlimited memory during a stress test, starving Postgres until it was OOMKilled.
3. The frontend, backend, database, and debug tools are all on the same network — any compromised service can reach the database directly.
4. There's no way to run a different configuration for staging vs. development without editing the main Compose file.

Sarah wants you to make this production-ready.

---

## Your Task

Starting from your working Compose setup (Challenges 1–3), make the following improvements:

### Part 1: Resource Limits

Add resource limits to **all services**:

| Service | Memory Limit | CPU Limit |
|---------|-------------|-----------|
| `postgres` | 512M | 1.0 |
| `redis` | 128M | 0.5 |
| `backend` | 256M | 1.0 |
| `frontend` | 64M | 0.25 |

Use the `deploy.resources.limits` section.

### Part 2: Logging Configuration

Add log rotation to **all services**:

- Driver: `json-file`
- Max size: `10m` (10 megabytes per log file)
- Max files: `3` (keep 3 rotated files)

Use YAML anchors (`&` / `*`) to avoid repeating the logging config on every service.

### Part 3: Network Isolation

Create two networks instead of one:

| Network | Services | Purpose |
|---------|----------|---------|
| `frontend-net` | frontend, backend | Public-facing tier |
| `backend-net` | backend, postgres, redis | Data tier — no direct external access |

The backend must be on **both** networks (it bridges frontend to data). The frontend must NOT be on `backend-net`. Postgres and Redis must NOT be on `frontend-net`.

### Part 4: Override File

Create a `docker-compose.override.yml` that adds development-specific configuration:

- Backend: expose port 3000 to the host, set `LOG_LEVEL=debug`
- Frontend: expose port 8080 to the host
- Postgres: expose port 5432 to the host (for local database tools)

The base `docker-compose.yml` should NOT map any ports to the host. Ports should only appear in the override.

---

## Success Criteria

Run the verification script:

```bash
bash challenges/verify.sh
```

The script checks:

1. All four core services are running
2. Resource limits are applied to all services
3. Log rotation is configured on all services
4. Two networks exist (`frontend-net` and `backend-net`)
5. The frontend is NOT on `backend-net`
6. Postgres is NOT on `frontend-net`
7. A `docker-compose.override.yml` file exists
8. The override file contains port mappings

---

## Hints

<details>
<summary>Hint 1 — YAML anchors for logging</summary>

YAML anchors let you define a block once and reference it everywhere. Define the logging config with an anchor at the top level using the `x-` extension prefix:

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  backend:
    logging: *default-logging
  
  frontend:
    logging: *default-logging
```

The `x-` prefix tells Compose to ignore the key at the top level — it's just there for YAML anchoring purposes.

</details>

<details>
<summary>Hint 2 — Resource limits syntax</summary>

Resource limits live under `deploy.resources.limits`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
```

You can verify limits are applied with:

```bash
docker inspect learn-ch05-backend-1 --format '{{.HostConfig.Memory}}'
```

A value of `0` means no limit is set. `268435456` means 256 MB (256 × 1024 × 1024).

</details>

<details>
<summary>Hint 3 — Multi-network setup and override file</summary>

A service can be on multiple networks:

```yaml
services:
  backend:
    networks:
      - frontend-net
      - backend-net
  
  frontend:
    networks:
      - frontend-net       # only the frontend network
  
  postgres:
    networks:
      - backend-net        # only the backend network

networks:
  frontend-net:
    labels:
      app: learn-docker-k8s
      world: w02
  backend-net:
    labels:
      app: learn-docker-k8s
      world: w02
```

For the override file, remember that `docker-compose.override.yml` is loaded automatically. It should only contain the development-specific additions:

```yaml
# docker-compose.override.yml
services:
  backend:
    ports:
      - "3000:3000"
    environment:
      LOG_LEVEL: debug
  
  frontend:
    ports:
      - "8080:80"
  
  postgres:
    ports:
      - "5432:5432"
```

The base file should have NO ports mapped — the override adds them for development.

</details>
