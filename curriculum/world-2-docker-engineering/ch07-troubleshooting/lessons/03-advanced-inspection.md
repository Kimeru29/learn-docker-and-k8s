# Lesson 7.3: Advanced Inspection

> "Logs are empty. Exit code is 0. The container looks healthy but the app isn't working. Time to go deeper."
> — Sarah

---

## Beyond Logs and Exit Codes

Sometimes the basics aren't enough. The logs are clean, the exit code is 0, and `docker inspect` shows nothing unusual. That's when you need the advanced toolbox.

---

## `docker stats` — Live Resource Monitoring

```bash
# Live dashboard — all containers
docker stats

# One container
docker stats learn-ch07-backend-1

# Snapshot (no streaming)
docker stats --no-stream

# Custom format
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
```

### Reading Stats Output

```
NAME                  CPU %   MEM USAGE / LIMIT     MEM %   NET I/O          BLOCK I/O
learn-ch07-backend-1  45.2%   234.5MiB / 512MiB     45.8%   1.2MB / 890kB    12.3MB / 0B
learn-ch07-postgres-1 12.1%   89.3MiB / 512MiB      17.4%   45kB / 120kB     50MB / 25MB
learn-ch07-redis-1     0.3%   12.1MiB / 128MiB       9.5%   22kB / 18kB      0B / 0B
```

**Red flags:**
- MEM % above 80% — approaching OOMKill territory
- CPU % at 100%+ sustained — possible infinite loop or heavy computation
- NET I/O at 0B / 0B — container has no network activity (possible connectivity issue)
- BLOCK I/O very high writes — possible excessive logging or temp file creation

### Diagnosing a Memory Leak

Watch memory over time:

```bash
# Log memory usage every 5 seconds
while true; do
  docker stats --no-stream --format "{{.Name}}: {{.MemUsage}}" | grep backend
  sleep 5
done
```

If memory goes up but never comes down, you have a leak:

```
learn-ch07-backend-1: 45MiB / 512MiB
learn-ch07-backend-1: 67MiB / 512MiB
learn-ch07-backend-1: 89MiB / 512MiB     ← trending up
learn-ch07-backend-1: 112MiB / 512MiB    ← still going
learn-ch07-backend-1: 145MiB / 512MiB    ← will eventually hit 512MiB → OOMKill
```

---

## `docker top` — Process List

```bash
# Default format
docker top learn-ch07-backend-1

# Custom format (like ps)
docker top learn-ch07-backend-1 -eo pid,ppid,stat,rss,comm
```

**Useful for:**
- Verifying PID 1 is the right process (not `/bin/sh -c`)
- Spotting zombie processes (`Z` status)
- Checking if unexpected processes are running
- Seeing RSS (resident memory) per process

```
PID   PPID  STAT  RSS     COMM
1     0     Ss    52000   node
15    1     Sl    8400    node       ← child worker
23    1     Z     0       node       ← zombie!
```

---

## `docker diff` — Filesystem Changes

```bash
docker diff learn-ch07-backend-1
```

Shows files added (`A`), changed (`C`), or deleted (`D`) in the container's writable layer since startup.

```
C /app
A /app/logs
A /app/logs/error.log
A /app/tmp/cache-292831.dat
C /tmp
A /tmp/core.1234              ← a core dump!
```

**Useful for:**
- Finding unexpected file writes (temp files, logs, uploads)
- Detecting configuration files that were modified at runtime
- Spotting core dumps from segfaults
- Understanding why a container's writable layer is growing

---

## `docker history` — Image Layer History

```bash
# Show how the image was built
docker history learn-ch07-backend

# Full commands (not truncated)
docker history learn-ch07-backend --no-trunc

# With size information
docker history learn-ch07-backend --format "table {{.Size}}\t{{.CreatedBy}}"
```

Output:
```
SIZE      CREATED BY
0B        CMD ["node" "server.js"]
0B        EXPOSE map[3000/tcp:{}]
5.2MB     COPY server.js . # buildkit
32MB      RUN npm install --omit=dev
124B      COPY package*.json ./
8.1kB     WORKDIR /app
0B        LABEL chapter=ch07
185MB     /bin/sh -c #(nop)  FROM node:20-alpine
```

**Useful for:**
- Understanding image size — which layer is biggest?
- Detecting secrets accidentally baked into layers (passwords in ENV or COPY)
- Verifying the correct base image was used
- Checking if the build cache is stale

### Detecting Leaked Secrets

```bash
docker history learn-ch07-backend --no-trunc | grep -iE "password|secret|key|token"
```

If you see something like `ENV DB_PASSWORD=hunter2`, the secret is permanently baked into that layer.

---

## `docker system df` — Disk Usage

```bash
# Summary
docker system df

# Detailed
docker system df -v
```

Output:
```
TYPE            TOTAL    ACTIVE   SIZE      RECLAIMABLE
Images          12       5        4.2GB     2.8GB (66%)
Containers      8        5        120MB     45MB (37%)
Local Volumes   6        4        890MB     200MB (22%)
Build Cache     24       0        1.2GB     1.2GB (100%)
```

**Red flags:**
- Build Cache consuming gigabytes — run `docker builder prune` (but only for learn-* resources!)
- Images piling up — old versions not removed
- Volumes growing — possible unbounded logging or data

---

## Debugging Slim and Distroless Images

Minimal images (`alpine`, `scratch`, `distroless`) don't have shells or debugging tools. This makes `docker exec` useless — you can't run `bash`, `curl`, `ps`, or `netstat`.

### Approach 1: `docker debug` (Docker Desktop)

Docker Desktop includes a `docker debug` command that attaches a toolbox container:

```bash
docker debug learn-ch07-api-1
```

This opens a shell with tools (`curl`, `vim`, `htop`, `strace`) available, without modifying the target container.

### Approach 2: Copy files out

```bash
# Copy a file from the container to your host
docker cp learn-ch07-api-1:/app/config.json ./config-debug.json

# Copy a file into the container
docker cp ./fixed-config.json learn-ch07-api-1:/app/config.json
```

### Approach 3: Temporary sidecar

Run a debug container on the same network:

```bash
# Join the same network as the target
docker run --rm -it \
  --network learn-ch07-app-net \
  --label app=learn-docker-k8s \
  --label world=w02 \
  alpine sh

# Now you can:
# ping learn-ch07-api-1
# wget -qO- http://learn-ch07-api-1:3000/health
# nslookup learn-ch07-postgres-1
```

### Approach 4: Override the entrypoint

```bash
# Start the image with a shell instead of the normal process
docker run --rm -it \
  --entrypoint /bin/sh \
  learn-ch07-api
```

This only works if the image has a shell (`alpine`, `debian`-based). It won't work for `scratch` or `distroless` images.

---

## `nsenter` — Entering a Container's Namespace (Advanced)

For truly headless containers, you can enter the container's Linux namespace from the host:

```bash
# Get the container's PID on the host
PID=$(docker inspect learn-ch07-api-1 --format '{{.State.Pid}}')

# Enter the network namespace
sudo nsenter -t $PID -n ss -tlnp

# Enter the mount namespace
sudo nsenter -t $PID -m ls /app/

# Enter all namespaces
sudo nsenter -t $PID -m -n -p -u sh
```

This is an advanced Linux technique — it requires root access on the host. Useful in production when you absolutely need to inspect a distroless container without modifying it.

> **Note:** `nsenter` requires host access and may not be available on Docker Desktop (which runs Docker in a VM). It works on native Linux hosts.

---

## The Debugging Decision Tree

```
Container not working?
│
├── Is it running?
│   ├── No → Check exit code + logs
│   │   ├── Exit 1 → App error, check logs
│   │   ├── Exit 127 → Command not found
│   │   ├── Exit 137 → OOMKilled (check stats/limits)
│   │   └── Exit 143 → Normal SIGTERM stop
│   │
│   └── Yes → Is it healthy?
│       ├── No → Check health check command
│       │   └── Health check failing → Check what it tests
│       │
│       └── Yes → App-level issue
│           ├── Check connectivity (DNS, ports)
│           ├── Check resources (CPU, memory, disk)
│           ├── Check config (env vars, mounts)
│           └── Check image (docker history, docker diff)
```

---

## Summary

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `docker stats` | Live CPU/memory/network/disk usage | Suspect resource exhaustion or leaks |
| `docker top` | Process list inside container | Check PID 1, spot zombies, verify processes |
| `docker diff` | Filesystem changes since startup | Unexpected files, config drift, core dumps |
| `docker history` | Image build layer history | Check image size, detect leaked secrets |
| `docker system df` | Docker disk usage summary | Disk space issues |
| `docker debug` | Shell into distroless containers | No shell available in the image |
| `docker cp` | Copy files in/out of containers | Extract logs, inject config |
| `nsenter` | Enter container namespaces from host | Advanced debugging on Linux hosts |

The key to debugging is not knowing every command by heart — it's knowing which tool to reach for based on the symptom. The 6-step ladder from Lesson 1 gives you the order. These tools give you the depth.

Time to put it all together with some broken containers.
