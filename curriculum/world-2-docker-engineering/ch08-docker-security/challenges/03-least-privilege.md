# Challenge 8.3: Least Privilege

> "The audit's final recommendation: 'Apply least-privilege principles across the entire stack.' Every service runs as root, shares a flat network, and has no resource limits. Time to fix the whole thing."
> — Sarah

---

## The Situation

The NoCappuccino Compose stack has four services. The auditor found that:

1. All services run as root
2. All services share one flat network — the frontend can directly access the database
3. No resource limits — a single service could consume all host resources
4. No security controls — full capabilities, writable filesystem

Your job: apply least-privilege across the entire stack.

---

## Setup

**`docker-compose.yml`** (the insecure version):

```yaml
name: learn-ch08

services:
  frontend:
    image: nginx:1.25-alpine
    ports:
      - "8080:80"
    networks:
      - app-net
    labels:
      app: learn-docker-k8s
      world: w02

  backend:
    image: node:20-alpine
    working_dir: /app
    command: ["node", "-e", "
      const http = require('http');
      const server = http.createServer((req, res) => {
        if (req.url === '/health') { res.writeHead(200); res.end(JSON.stringify({status:'ok', user: process.getuid()})); return; }
        res.writeHead(200); res.end('API ok');
      });
      process.on('SIGTERM', () => server.close(() => process.exit(0)));
      server.listen(3000, () => console.log('Backend on 3000'));
    "]
    ports:
      - "3000:3000"
    networks:
      - app-net
    labels:
      app: learn-docker-k8s
      world: w02

  redis:
    image: redis:7-alpine
    networks:
      - app-net
    labels:
      app: learn-docker-k8s
      world: w02

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: cloudbrew
      POSTGRES_USER: brew
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-brewpass}
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    labels:
      app: learn-docker-k8s
      world: w02

networks:
  app-net:
    labels:
      app: learn-docker-k8s
      world: w02

volumes:
  db-data:
    labels:
      app: learn-docker-k8s
      world: w02
```

Create a `.env` file:
```
POSTGRES_PASSWORD=brewpass
```

---

## Your Task

Modify the `docker-compose.yml` to apply least-privilege:

### 1. Non-Root Users

| Service | User |
|---------|------|
| frontend (nginx) | `nginx` (built into the image, may need port change) |
| backend | `node` (built into node image) or UID `1000` |
| redis | `redis` (built into the image) |
| postgres | `postgres` (built into the image — handled automatically) |

For nginx: the official nginx image runs as root by default to bind port 80. You'll need to either use the `user:` directive in Compose or accept that nginx manages its own worker processes as non-root.

### 2. Network Isolation

Create two networks:

| Network | Services | Purpose |
|---------|----------|---------|
| `frontend-net` | frontend, backend | Public-facing tier |
| `backend-net` | backend, redis, postgres | Data tier |

The backend bridges both. The frontend must NOT access the database directly.

### 3. Resource Limits

| Service | Memory Limit | CPU Limit |
|---------|-------------|-----------|
| frontend | 64M | 0.25 |
| backend | 256M | 1.0 |
| redis | 128M | 0.5 |
| postgres | 512M | 1.0 |

### 4. Security Controls

Apply to all services:
- `cap_drop: [ALL]`
- `security_opt: [no-new-privileges:true]`

Apply to frontend and backend:
- `read_only: true` (with appropriate `tmpfs` mounts)

---

## Success Criteria

```bash
bash challenges/verify.sh
```

The script checks:
1. All four services are running
2. Backend and frontend respond on their ports
3. Backend runs as non-root (UID != 0)
4. Network isolation: frontend is NOT on backend-net
5. Network isolation: postgres is NOT on frontend-net
6. Memory limits are set on all services
7. Capabilities are dropped on all services

---

## Hints

<details>
<summary>Hint 1 — User configuration</summary>

For services using official images, you can set the user in Compose:

```yaml
services:
  backend:
    user: "1000:1000"           # node user's UID:GID
  redis:
    user: "999:999"             # redis user's UID:GID
```

For nginx, the default image runs master as root and workers as nginx. The simplest approach for this challenge: use `user: "101:101"` (nginx's UID/GID) with the understanding that nginx might need `cap_add: [NET_BIND_SERVICE]` to bind port 80, OR change the nginx config to listen on 8080 instead.

Alternatively, leave nginx running as root since it's the standard pattern for the official image (master as root, workers as non-root) — and note this exception in your security documentation.

For postgres: the official image handles user switching internally (runs initdb as root, then switches to `postgres` user). Setting `user:` in Compose can break Postgres initialization. Leave postgres as-is — the image handles it correctly.

</details>

<details>
<summary>Hint 2 — Network isolation and resource limits</summary>

```yaml
services:
  frontend:
    networks:
      - frontend-net       # only frontend network

  backend:
    networks:
      - frontend-net       # can receive requests from frontend
      - backend-net        # can reach database and cache

  redis:
    networks:
      - backend-net        # only backend network

  postgres:
    networks:
      - backend-net        # only backend network

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

For resource limits:
```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: "1.0"
```

</details>

<details>
<summary>Hint 3 — Security controls</summary>

Apply security controls to each service:

```yaml
services:
  backend:
    user: "1000:1000"
    cap_drop:
      - ALL
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: "1.0"

  frontend:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE    # needed for port 80
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache/nginx
      - /run
    security_opt:
      - no-new-privileges:true

  redis:
    user: "999:999"
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true

  postgres:
    # Don't set user: — postgres image handles it
    cap_drop:
      - ALL
    cap_add:
      - CHOWN               # postgres needs to change file ownership during init
      - SETUID               # postgres needs to switch users
      - SETGID
      - FOWNER
      - DAC_OVERRIDE
    security_opt:
      - no-new-privileges:true
```

Note: Postgres needs some capabilities for initialization (it switches from root to the postgres user). You can't drop ALL for postgres without breaking it. The key insight: least privilege doesn't mean zero privileges — it means the minimum needed.

</details>

---

## Post-Challenge Debrief

**What you did:** Applied least-privilege across a four-service Compose stack: non-root users, network segmentation, resource limits, dropped capabilities, read-only filesystems, and privilege escalation prevention.

**Why it works:** Defense in depth. Each control reduces the blast radius independently. An attacker who exploits the frontend can't reach the database (network isolation). Even if they get code execution, they're non-root with no capabilities and a read-only filesystem. And even if they find an escalation vector, `no-new-privileges` blocks it.

**Real-world connection:** This is exactly what a production security review looks for. The CIS Docker Benchmark has specific controls for each of these areas. SOC 2 audits verify network segmentation. PCI-DSS requires non-root execution for containers handling payment data.

**Interview angle:** "You have a four-service stack. Walk me through how you'd secure it." This is an architecture question, not a coding question. Hit: network segmentation (two tiers), non-root users, minimal capabilities, resource limits, secret management, and read-only filesystems. The candidate who mentions all six stands out.

**Pro tip:** Not every service can run with zero capabilities. Postgres needs CHOWN, SETUID, SETGID for initialization. Nginx needs NET_BIND_SERVICE for port 80. The skill is knowing the *minimum* set for each service, not blindly dropping everything and wondering why it breaks.
