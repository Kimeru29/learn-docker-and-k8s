# Lesson 8.3: Runtime Security

> "The auditor asked: 'What Linux capabilities does your web server container have?' I checked. It had NET_RAW, SYS_CHOWN, SETUID, SETGID... it could do almost everything root can do. For a web server that serves HTML."
> — Sarah

---

## Linux Capabilities

Traditional Unix has two levels of privilege: root (can do everything) and non-root (limited). Linux capabilities split root's powers into smaller, independent permissions.

Docker containers, by default, get a subset of capabilities — but it's still more than most applications need.

### Default Capabilities in Docker

```bash
# See what capabilities a container has
docker inspect learn-ch08-api-1 --format '{{json .HostConfig.CapAdd}} / Drop: {{json .HostConfig.CapDrop}}'
```

Docker grants these capabilities by default:

| Capability | Allows | Does a Web Server Need It? |
|-----------|--------|---------------------------|
| `CHOWN` | Change file ownership | Rarely |
| `DAC_OVERRIDE` | Bypass file permission checks | No |
| `FSETID` | Set file SUID/SGID bits | No |
| `FOWNER` | Bypass ownership checks | No |
| `MKNOD` | Create special files | No |
| `NET_RAW` | Use raw sockets (ping, network scanning) | No |
| `SETGID` | Change group ID | Rarely |
| `SETUID` | Change user ID | Rarely |
| `SETFCAP` | Set file capabilities | No |
| `SETPCAP` | Modify process capabilities | No |
| `NET_BIND_SERVICE` | Bind to ports < 1024 | Only if using port 80/443 |
| `SYS_CHROOT` | Use chroot | No |
| `KILL` | Send signals to other processes | No |
| `AUDIT_WRITE` | Write to audit log | No |

That's 14 capabilities — and a typical web server needs at most 1 or 2 of them.

### Dropping Capabilities

```yaml
# docker-compose.yml
services:
  backend:
    build: ./backend
    cap_drop:
      - ALL                    # drop everything
    cap_add:
      - NET_BIND_SERVICE       # add back only what's needed
    labels:
      app: learn-docker-k8s
      world: w02
```

```bash
# Or with docker run
docker run --cap-drop ALL --cap-add NET_BIND_SERVICE myimage
```

**Best practice:** Drop ALL capabilities, then add back only what the application needs. Most applications need zero capabilities if running on a port above 1024 as a non-root user.

```yaml
# The most restrictive (and most common) setup
services:
  backend:
    cap_drop:
      - ALL
    # No cap_add needed if using port > 1024
```

---

## Read-Only Root Filesystem

By default, containers can write anywhere in their filesystem. A compromised application could:

- Install malware
- Modify application code
- Create backdoor scripts
- Write unauthorized data

Making the root filesystem read-only prevents all filesystem modifications:

```yaml
services:
  backend:
    build: ./backend
    read_only: true
    labels:
      app: learn-docker-k8s
      world: w02
```

```bash
docker run --read-only myimage
```

### When Apps Need to Write

Most applications need to write *somewhere* — temporary files, logs, PID files, session data. Use `tmpfs` mounts for directories that need to be writable:

```yaml
services:
  backend:
    build: ./backend
    read_only: true
    tmpfs:
      - /tmp                   # temporary files
      - /app/logs              # application logs
      - /run                   # PID files, sockets
    labels:
      app: learn-docker-k8s
      world: w02
```

`tmpfs` mounts are stored in memory, not on disk. They're ephemeral (lost when the container stops) and fast.

### Common Directories That Need Write Access

| Directory | Purpose | Solution |
|-----------|---------|---------|
| `/tmp` | Temporary files | `tmpfs: [/tmp]` |
| `/var/log` or `/app/logs` | Application logs | `tmpfs` or volume |
| `/run` | PID files, Unix sockets | `tmpfs: [/run]` |
| `/var/cache` | Application caches | `tmpfs` or volume |
| `/data` | Persistent application data | Named volume |

---

## Seccomp Profiles (Conceptual)

Seccomp (Secure Computing Mode) restricts which **system calls** a container can make. Docker applies a default seccomp profile that blocks ~44 dangerous syscalls.

```bash
# Check if seccomp is enabled
docker inspect learn-ch08-api-1 --format '{{.HostConfig.SecurityOpt}}'
```

The default profile blocks syscalls like:
- `mount` — can't mount filesystems
- `reboot` — can't reboot the host
- `swapon/swapoff` — can't modify swap
- `clock_settime` — can't change system time
- `unshare` — can't create new namespaces (prevents some container escapes)

**For this chapter:** Know that seccomp exists and that Docker applies a reasonable default. Custom seccomp profiles are an advanced topic for specialized security hardening.

---

## Resource Limits as Security

Resource limits aren't just for performance — they're a security control. Without limits, a compromised container can:

1. **CPU exhaustion:** Mine cryptocurrency or run a DDoS attack using your CPU
2. **Memory exhaustion:** Allocate memory until the host runs out, crashing other containers
3. **Fork bomb:** Create processes until the process table is full
4. **Disk exhaustion:** Write data until the disk is full

```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 256M
        reservations:
          memory: 64M
    # Also limit the number of processes
    pids_limit: 100
    labels:
      app: learn-docker-k8s
      world: w02
```

### `pids_limit` — Fork Bomb Protection

```yaml
services:
  backend:
    pids_limit: 100            # max 100 processes
```

A fork bomb (`:(){ :|:& };:`) in an unlimited container can create thousands of processes and crash the host. `pids_limit` caps the number of processes in the container's cgroup.

---

## Docker Socket Exposure

The Docker socket (`/var/run/docker.sock`) is the API endpoint for the Docker daemon. Mounting it inside a container gives that container **full control over Docker** — which is effectively root access on the host.

### Why It's Dangerous

```yaml
# NEVER DO THIS in production
services:
  my-tool:
    image: some-tool
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

A container with Docker socket access can:
- Start new containers with `--privileged` (full host access)
- Mount the host's root filesystem (`-v /:/host`)
- Read any secret, modify any file, access any network
- Essentially become root on the host machine

### When It's Used (and Alternatives)

| Use Case | Why Socket is Mounted | Safer Alternative |
|----------|----------------------|-------------------|
| CI/CD runners | Build Docker images | Use Docker-in-Docker (DinD) or kaniko |
| Container monitoring | Watch container metrics | Use the Docker API over TCP with TLS |
| Development tools | Auto-reload on code changes | Use bind mounts instead |
| Portainer/Traefik | Manage/route to containers | Restrict with read-only socket proxy |

### If You Must Mount the Socket

```yaml
services:
  monitoring:
    image: monitoring-tool
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro   # read-only
    cap_drop:
      - ALL
    # Or use a socket proxy like tecnativa/docker-socket-proxy
```

The `:ro` flag makes the socket read-only — the tool can query Docker but not modify it. Even better: use a Docker socket proxy that exposes only specific API endpoints.

---

## Putting It All Together

A hardened container in Compose:

```yaml
services:
  backend:
    build: ./backend
    user: "1001:1001"                    # non-root
    read_only: true                       # immutable filesystem
    cap_drop:
      - ALL                               # no capabilities
    tmpfs:
      - /tmp                              # writable temp
      - /app/logs                         # writable logs
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 256M
    pids_limit: 50                        # fork bomb protection
    security_opt:
      - no-new-privileges:true            # prevent privilege escalation
    labels:
      app: learn-docker-k8s
      world: w02
```

### `no-new-privileges`

```yaml
security_opt:
  - no-new-privileges:true
```

This prevents the process from gaining new privileges via `setuid` binaries or capabilities. Even if an attacker finds a setuid binary in the container, they can't use it to escalate.

---

## Security Checklist

| Control | Implementation | Impact |
|---------|---------------|--------|
| Non-root user | `USER` in Dockerfile or `user:` in Compose | Prevents root-level access |
| Drop capabilities | `cap_drop: [ALL]` | Removes unneeded kernel permissions |
| Read-only filesystem | `read_only: true` + `tmpfs` | Prevents filesystem modifications |
| Resource limits | `deploy.resources.limits` | Prevents resource exhaustion |
| PID limits | `pids_limit: N` | Prevents fork bombs |
| No new privileges | `security_opt: [no-new-privileges:true]` | Prevents privilege escalation |
| No Docker socket | Don't mount `/var/run/docker.sock` | Prevents host takeover |
| Minimal base image | `alpine` or `distroless` | Reduces attack surface |
| No secrets in layers | `.dockerignore`, multi-stage, runtime injection | Prevents credential exposure |

---

## Summary

- **Capabilities:** Drop ALL, add back only what's needed. Most apps need zero capabilities.
- **Read-only filesystem:** Set `read_only: true` and use `tmpfs` for directories that need writes
- **Seccomp:** Docker applies a default profile that blocks dangerous syscalls — usually sufficient
- **Resource limits:** Mandatory security control — prevents CPU, memory, and process exhaustion
- **PID limits:** Protect against fork bombs with `pids_limit`
- **Docker socket:** Never mount in production. Use alternatives (DinD, kaniko, socket proxy)
- **`no-new-privileges`:** Prevents setuid escalation
- The combination of non-root + dropped caps + read-only + limits covers most container security requirements

Time to put all of this into practice.
