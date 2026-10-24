# Lesson 8.1: Running as Non-Root

> "The auditor asked me: 'Why is your web server running as root?' I said 'Because that's the default.' She said 'That's not a reason.' She was right."
> — Sarah

---

## Why Root in Containers Is Dangerous

By default, the process inside a Docker container runs as `root` (UID 0). This is the same root that exists on the host — the container just has a restricted *view* of the system through namespaces.

### The Risk

If an attacker exploits a vulnerability in your application (SQL injection, remote code execution, dependency supply chain attack), they gain code execution as root inside the container. From there:

1. **Container escape:** Some kernel vulnerabilities allow a root process inside a container to break out and become root on the host
2. **Data access:** Root can read any file inside the container, including mounted secrets and volumes
3. **Network access:** Root can listen on privileged ports, install network tools, and pivot to other services
4. **Persistence:** Root can modify the filesystem, install backdoors, and change container behavior

### The Principle

**Principle of Least Privilege:** Every process should run with the minimum permissions it needs to do its job. A web server that serves HTML files does not need root. A Node.js API does not need root. A database might need specific permissions, but not full root.

---

## The `USER` Instruction

```dockerfile
FROM node:20-alpine

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --chown=appuser:appgroup package.json .
RUN npm install --omit=dev
COPY --chown=appuser:appgroup . .

# Switch to non-root user
USER appuser

CMD ["node", "server.js"]
```

After `USER appuser`, every subsequent instruction (`RUN`, `CMD`, `ENTRYPOINT`) runs as `appuser`, not root.

### Creating Users on Different Base Images

**Alpine:**
```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
```

**Debian/Ubuntu:**
```dockerfile
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser
```

**Using numeric UID (most portable):**
```dockerfile
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser
USER 1001
```

Using numeric UIDs is more portable and explicit — it works regardless of whether the user exists in `/etc/passwd` at runtime.

---

## Common Permission Issues

Switching to non-root almost always triggers permission errors on the first attempt. Here's how to fix them.

### Problem 1: Can't write to the working directory

```
Error: EACCES: permission denied, open '/app/data/cache.json'
```

The `/app` directory was created by root during `COPY`. The non-root user can't write to it.

**Fix:** Set ownership during the build:

```dockerfile
WORKDIR /app
COPY --chown=appuser:appgroup . .
```

Or fix ownership explicitly:

```dockerfile
RUN chown -R appuser:appgroup /app
```

### Problem 2: Can't bind to port 80

```
Error: listen EACCES: permission denied 0.0.0.0:80
```

On Linux, ports below 1024 are "privileged" — only root can bind to them.

**Fix:** Use a port above 1024:

```dockerfile
EXPOSE 8080
CMD ["node", "server.js"]  # configured to listen on 8080
```

In your Compose file, map the external port:
```yaml
ports:
  - "80:8080"    # host port 80 → container port 8080
```

### Problem 3: Can't write to `/tmp` or `/var`

```
Error: EACCES: permission denied, mkdir '/var/log/app'
```

**Fix:** Create the directories and set ownership before switching to the non-root user:

```dockerfile
RUN mkdir -p /var/log/app && chown appuser:appgroup /var/log/app
USER appuser
```

### Problem 4: Volume mount permissions

When you mount a host directory as a volume, the files have the host's UID/GID. If the host user is UID 1000 and the container user is UID 1001, there's a mismatch.

**Fix:** Make the container user's UID match the host user's UID:

```dockerfile
# Use a specific UID that matches the host user
ARG UID=1000
RUN adduser -u $UID -D appuser
USER appuser
```

Or use `--user` at runtime:
```bash
docker run --user "$(id -u):$(id -g)" myimage
```

---

## The `--chown` Flag in COPY

```dockerfile
# Without --chown (files owned by root):
COPY . /app/
# drwxr-xr-x root root /app/

# With --chown (files owned by appuser):
COPY --chown=appuser:appgroup . /app/
# drwxr-xr-x appuser appgroup /app/
```

Using `--chown` in `COPY` is more efficient than a separate `RUN chown` because it sets ownership during the copy — no extra layer needed.

---

## Verifying Non-Root

### During build (in Dockerfile)

```dockerfile
# This should print "appuser" or "1001"
RUN whoami
```

### At runtime

```bash
# Check who's running inside the container
docker exec learn-ch08-api-1 whoami
# appuser

docker exec learn-ch08-api-1 id
# uid=1001(appuser) gid=1001(appgroup) groups=1001(appgroup)

# Check PID 1
docker top learn-ch08-api-1
# UID      PID   CMD
# 1001     1     node server.js
```

### In docker inspect

```bash
docker inspect learn-ch08-api-1 --format '{{.Config.User}}'
# appuser (or 1001)
```

---

## The Node.js `node` User

The official Node.js Docker images already include a non-root user called `node` (UID 1000). You can use it directly:

```dockerfile
FROM node:20-alpine

WORKDIR /app
COPY --chown=node:node package.json .
RUN npm install --omit=dev
COPY --chown=node:node . .

USER node
CMD ["node", "server.js"]
```

Many official images include pre-built non-root users:

| Image | Built-in User | UID |
|-------|--------------|-----|
| `node` | `node` | 1000 |
| `python` | (none — create your own) | — |
| `nginx` | `nginx` | 101 |
| `postgres` | `postgres` | 70 |
| `redis` | `redis` | 999 |

---

## Runtime Override

Even if the Dockerfile doesn't set `USER`, you can force non-root at runtime:

```bash
docker run --user 1001:1001 myimage
```

In Compose:
```yaml
services:
  backend:
    build: ./backend
    user: "1001:1001"
```

This is useful for third-party images that you don't control.

---

## Summary

- **Root inside containers is dangerous** — it's the same root as the host, just with a restricted view
- **Use the `USER` instruction** to switch to a non-root user before `CMD`
- **Common issues:** permission denied on files, can't bind port < 1024, volume mount UID mismatch
- **Fix ownership** with `COPY --chown=user:group` or `RUN chown`
- **Use ports above 1024** inside the container; map to 80/443 with `ports:`
- **Official images** often include built-in non-root users (e.g., `node` in Node.js images)
- **Verify** with `docker exec whoami` or `docker top`
- Runtime `--user` flag can force non-root even on images without a `USER` instruction

Next: your container runs as non-root. But what about the secrets baked into the image layers?
