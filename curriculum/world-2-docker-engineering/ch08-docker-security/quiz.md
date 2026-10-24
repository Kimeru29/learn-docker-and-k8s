# Chapter 8 Quiz: The Audit

> "Security isn't a feature you add later. It's a property of the system. Let's make sure you understand the principles."
> — Sarah

---

## Question 1

A Dockerfile has:

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]
```

An auditor says: "This container runs as root." What's the correct fix?

A) Add `RUN chmod 777 /app` to give everyone write access

B) Add a non-root user with `RUN adduser` and switch to it with `USER` before CMD. Fix file ownership with `COPY --chown` or `RUN chown`.

C) Use `docker run --privileged` to bypass the root restriction

D) Change the base image to `node:20-alpine-nonroot` (a special non-root variant)

<details>
<summary>Answer</summary>

**B** is correct.

```dockerfile
FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --chown=appuser:appgroup . .
RUN npm install
USER appuser
CMD ["node", "server.js"]
```

Or use the built-in `node` user (UID 1000) in the official Node.js image:
```dockerfile
COPY --chown=node:node . .
USER node
```

Option A makes everything world-writable — worse security, not better. Option C (`--privileged`) gives the container full host access — the opposite of hardening. Option D doesn't exist (though some images like nginx have unprivileged variants).

</details>

---

## Question 2

A Dockerfile has:

```dockerfile
FROM ubuntu:24.04
ENV DB_PASSWORD=hunter2
COPY . /app
RUN rm /app/.env
```

How many security issues are in this Dockerfile?

A) One — the `RUN rm` doesn't actually remove the file from earlier layers

B) Two — the `ENV DB_PASSWORD` is visible in inspect/history, and the `COPY . /app` copies potentially sensitive files

C) Three — the `ENV` leaks the password, the `COPY` includes sensitive files, and the `RUN rm` only removes from the current layer (the file still exists in the COPY layer)

D) None — the `RUN rm` properly cleans up the sensitive file

<details>
<summary>Answer</summary>

**C** is correct. There are three issues:

1. **`ENV DB_PASSWORD=hunter2`** — The password is permanently in the image metadata. Visible in `docker inspect` and `docker history`.

2. **`COPY . /app`** — Without a `.dockerignore`, this copies everything including `.env`, `.git`, `node_modules`, and any secret files.

3. **`RUN rm /app/.env`** — This removes the file from the writable layer, but the file still exists in the COPY layer. Docker images are additive — deleting a file in a later layer doesn't remove it from earlier layers. Anyone can extract it with `docker save`.

Fixes: Remove the `ENV`, add a `.dockerignore`, use selective `COPY`, and inject secrets at runtime.

</details>

---

## Question 3

You add `cap_drop: [ALL]` to a service in docker-compose.yml. What does this do?

A) Drops all environment variables from the container

B) Removes all Linux capabilities from the container, preventing it from performing privileged kernel operations like changing file ownership, using raw sockets, or binding to ports below 1024

C) Drops all network connections to the container

D) Removes all volumes mounted to the container

<details>
<summary>Answer</summary>

**B** is correct.

Linux capabilities are fine-grained permissions that split root's powers into individual controls. Docker containers get ~14 capabilities by default. `cap_drop: [ALL]` removes all of them.

After dropping all capabilities:
- Can't bind to ports below 1024 (no `NET_BIND_SERVICE`)
- Can't use raw sockets / ping (no `NET_RAW`)
- Can't change file ownership (no `CHOWN`)
- Can't switch user IDs (no `SETUID`, `SETGID`)

Most applications running on port > 1024 as a non-root user need zero capabilities. If a specific capability is needed, add it back with `cap_add`.

</details>

---

## Question 4

You set `read_only: true` on a container, but the application crashes because it needs to write to `/tmp` and `/app/logs`. What's the solution?

A) Remove `read_only: true` — it's not compatible with applications that write files

B) Keep `read_only: true` and add `tmpfs` mounts for the directories that need write access: `tmpfs: [/tmp, /app/logs]`

C) Change the application code to not write any files

D) Use `chmod 777` on the read-only filesystem

<details>
<summary>Answer</summary>

**B** is correct.

`read_only: true` makes the root filesystem immutable — no file can be created, modified, or deleted. This is a strong security control that prevents attackers from modifying application code or installing tools.

For directories that legitimately need write access, use `tmpfs` mounts:

```yaml
services:
  api:
    read_only: true
    tmpfs:
      - /tmp
      - /app/logs
```

`tmpfs` mounts are stored in memory, not on disk. They're writable but ephemeral — contents are lost when the container stops. This gives the application the write access it needs while keeping the rest of the filesystem immutable.

Option D (`chmod 777`) doesn't work on a read-only filesystem — the chmod itself would fail.

</details>

---

## Question 5

A development container has the Docker socket mounted:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

Why does the security auditor flag this as a critical finding?

A) The Docker socket uses too much disk space

B) Mounting the Docker socket gives the container full control over the Docker daemon, which is equivalent to root access on the host. The container can start privileged containers, mount the host filesystem, and access any resource.

C) The Docker socket conflicts with other containers using networking

D) The Docker socket is deprecated and should be replaced with Docker Compose

<details>
<summary>Answer</summary>

**B** is correct.

The Docker socket (`/var/run/docker.sock`) is the API endpoint for the Docker daemon. A container with access to the socket can:

1. Start a new container with `--privileged -v /:/host` — full host access
2. Read secrets from any running container
3. Stop or delete any container on the host
4. Pull and run arbitrary images
5. Essentially become root on the host machine

This is flagged as critical because it completely bypasses container isolation. Even if the container itself runs as non-root with dropped capabilities, it can use the Docker API to launch a privileged container that has full access.

Safer alternatives: Docker-in-Docker (DinD), kaniko for builds, read-only socket proxy for monitoring tools, or TCP with TLS mutual authentication.

</details>
