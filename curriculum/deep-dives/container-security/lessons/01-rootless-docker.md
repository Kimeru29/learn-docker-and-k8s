# Lesson 01: Rootless Docker

> "The Docker daemon runs as root by default. That means anyone with access to the Docker socket effectively has root on the host. Rootless Docker changes that equation."
> — Sarah

---

## The Root Problem

By default, the Docker daemon (`dockerd`) runs as root. This is necessary because Docker needs to:
- Create namespaces and cgroups (kernel operations)
- Bind to privileged ports (< 1024)
- Mount filesystems
- Configure networking (iptables, bridges, veth pairs)

The consequence: anyone who can run `docker` commands has **effective root access** to the host. Try this:

```bash
# This mounts the host's root filesystem into a container:
docker run --rm -v /:/hostfs alpine cat /hostfs/etc/shadow
```

If that command shows password hashes, Docker just gave you root-level file access. That's the problem rootless Docker solves.

---

## What Rootless Docker Is

**Rootless Docker** runs the entire Docker daemon — and all containers — as a regular, unprivileged user. No root. No sudo.

It achieves this using **user namespaces** — the same namespace technology Docker uses for other isolation, but applied to user and group IDs:

```
Host                        Container
user: juan (UID 1000)  →   user: root (UID 0)
      ↑                          ↑
      └── User namespace mapping ┘
```

Inside the container, the process thinks it's root (UID 0). On the host, it's actually running as your unprivileged user (UID 1000). Even if an attacker escapes the container, they have no root privileges on the host.

---

## How It Works

### User namespace UID/GID mapping

Rootless Docker maps a range of UIDs inside the container to a range of UIDs on the host:

```
Container UID 0     → Host UID 100000
Container UID 1     → Host UID 100001
Container UID 65534 → Host UID 165534
```

The mapping is defined in `/etc/subuid` and `/etc/subgid`:

```bash
cat /etc/subuid
# juan:100000:65536
# This means: user "juan" can use host UIDs 100000 through 165535
```

### No privileged kernel operations

Without root, rootless Docker:
- Uses `slirp4netns` or `pasta` for networking instead of creating bridges and iptables rules
- Uses `fuse-overlayfs` instead of kernel OverlayFS (on older kernels)
- Cannot bind to ports below 1024 without `CAP_NET_BIND_SERVICE`

---

## Setting Up Rootless Docker (Linux Only)

> ⚠️ **macOS/Docker Desktop users:** Rootless Docker is Linux-only. Docker Desktop already runs Docker inside a VM, providing a different kind of isolation. Read this section to understand the concepts.

### Prerequisites

```bash
# Check if your user has subuid/subgid entries:
grep $(whoami) /etc/subuid /etc/subgid

# Install required packages (Ubuntu/Debian):
sudo apt-get install -y uidmap dbus-user-session fuse-overlayfs slirp4netns

# Install rootless Docker:
dockerd-rootless-setuptool.sh install
```

### Running rootless

```bash
# The rootless daemon runs as your user:
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

# Verify:
docker info | grep -i "root"
# Security Options: rootless
# Docker Root Dir: /home/juan/.local/share/docker
```

### Key differences from regular Docker

| Feature | Root Docker | Rootless Docker |
|---------|------------|-----------------|
| Daemon runs as | root | your user |
| Container root maps to | host root (UID 0) | host unprivileged user |
| Networking | bridges, iptables | slirp4netns / pasta |
| Port < 1024 | Works | Requires sysctl or CAP |
| OverlayFS | Kernel driver | fuse-overlayfs (or kernel if supported) |
| Performance | Full speed | Slight overhead (networking) |
| `/var/lib/docker` | System-wide | `~/.local/share/docker` |

---

## Limitations

Rootless Docker has real limitations you should know:

1. **No `--privileged`** — Can't run privileged containers (that would defeat the purpose)
2. **No host networking** — `--network=host` doesn't work (no access to host's network namespace)
3. **Port restrictions** — Ports < 1024 require `sysctl net.ipv4.ip_unprivileged_port_start=0`
4. **Performance** — Network throughput is lower due to slirp4netns (userspace networking)
5. **Cgroup limits** — May require cgroups v2 with delegation enabled
6. **Some volume mounts** — Can't mount host paths the user doesn't have access to

---

## When to Use Rootless Docker

**Use rootless when:**
- CI/CD runners that build/run containers (Jenkins agents, GitHub Actions self-hosted)
- Shared development servers where multiple users run Docker
- Environments where the Docker socket is exposed and you want to limit blast radius
- Compliance requirements mandate no-root daemon

**Stick with regular Docker when:**
- Production servers with proper access controls
- You need host networking or privileged operations
- Performance is critical (high-throughput networking)
- The environment is already well-isolated (VMs, dedicated nodes)

---

## Docker Desktop vs Rootless Docker

Docker Desktop on macOS and Windows already runs containers inside a Linux VM. The host machine's root is not directly exposed. This is a different security model:

```
macOS:
  Your user → Docker Desktop app → Linux VM → Docker daemon (root inside VM)
  
Rootless Linux:
  Your user → Docker daemon (runs as your user) → Containers (mapped UIDs)
```

Both improve security over "Docker daemon as root on a shared Linux server," but in different ways.

---

## Practical: Checking Container UID Mapping

Even without rootless Docker, you can verify user namespace behavior:

```bash
# Regular Docker — container root IS host root:
docker run --rm alpine id
# uid=0(root) gid=0(root)

docker run --rm alpine cat /proc/1/uid_map
# 0     0     4294967295
# (container UID 0 maps to host UID 0 — full range)

# With user namespace remapping enabled:
# 0     100000  65536
# (container UID 0 maps to host UID 100000)
```

---

## Summary

- Default Docker daemon runs as root — Docker socket access ≈ root access on the host
- Rootless Docker runs the entire daemon as an unprivileged user using user namespaces
- User namespaces remap container UID 0 to an unprivileged host UID
- Trade-offs: slightly lower networking performance, no privileged containers, port restrictions
- Docker Desktop provides VM-based isolation (different model, similar security benefit)
- Use rootless on shared servers, CI runners, and when compliance requires no-root

---

**Next:** [Seccomp and AppArmor](02-seccomp-and-apparmor.md) — Controlling what containers can do at the syscall and profile level
