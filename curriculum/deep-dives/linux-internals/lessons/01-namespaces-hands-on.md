# Lesson 01: Namespaces Hands-On

> "You already know namespaces provide isolation. Now let's actually see them — from the outside, from the inside, and if you're on Linux, create one by hand."
> — Sarah

---

## What You Already Know

From Chapter 01 you learned that namespaces are one of two Linux kernel features Docker relies on. Each namespace type isolates a different system resource. A container is really just a process wrapped in a set of namespaces.

Now let's stop talking about it and start looking at it.

---

## The Six Namespace Types (Revisited)

| Namespace | Flag | What the process sees in isolation |
|-----------|------|-------------------------------------|
| **PID** | `CLONE_NEWPID` | Its own process tree — PID 1 is the container's entrypoint |
| **NET** | `CLONE_NEWNET` | Its own network stack — interfaces, routing table, iptables |
| **MNT** | `CLONE_NEWNS` | Its own mount points — different filesystem view |
| **UTS** | `CLONE_NEWUTS` | Its own hostname — `hostname` inside ≠ `hostname` outside |
| **IPC** | `CLONE_NEWIPC` | Its own shared memory segments and message queues |
| **USER** | `CLONE_NEWUSER` | Its own UID/GID mapping — root inside can be nobody outside |

There's also a 7th: **cgroup namespace** (`CLONE_NEWCGROUP`), which isolates the cgroup root view. Docker uses this too, but we'll cover cgroups in the next lesson.

---

## Seeing Namespaces on a Running Container

Start a simple container:

```bash
docker run -d --name learn-dd-ns-demo \
  --label app=learn-docker-k8s --label track=deep-dive \
  alpine sleep 3600
```

### Step 1: Find the container's PID on the host

Every container process has a real PID on the host. Docker just hides it behind a PID namespace so the process *thinks* it's PID 1.

```bash
# Get the host PID of the container's main process
docker inspect learn-dd-ns-demo --format '{{.State.Pid}}'
```

Save that PID — you'll use it throughout this lesson:

```bash
CONTAINER_PID=$(docker inspect learn-dd-ns-demo --format '{{.State.Pid}}')
echo "Container's host PID: $CONTAINER_PID"
```

### Step 2: List the container's namespaces via /proc

Every process on Linux exposes its namespace memberships under `/proc/[pid]/ns/`:

```bash
# On Linux hosts (or inside the Docker Desktop VM):
ls -la /proc/$CONTAINER_PID/ns/
```

You'll see something like:

```
lrwxrwxrwx 1 root root 0 Jan 15 10:00 cgroup -> 'cgroup:[4026532519]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 ipc    -> 'ipc:[4026532456]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 mnt    -> 'mnt:[4026532454]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 net    -> 'net:[4026532459]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 pid    -> 'pid:[4026532457]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 user   -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 Jan 15 10:00 uts    -> 'uts:[4026532455]'
```

Each symlink points to a namespace identified by an inode number (e.g., `pid:[4026532457]`). Two processes sharing the same inode number are in the same namespace.

### Step 3: Compare container vs. host namespaces

```bash
# Host's init process (PID 1) namespaces:
ls -la /proc/1/ns/

# Container's namespaces:
ls -la /proc/$CONTAINER_PID/ns/
```

Notice: the `user` namespace inode is often the same (Docker doesn't use user namespaces by default). The `pid`, `net`, `mnt`, `uts`, and `ipc` inodes are different — that's the isolation.

---

## PID Namespace: "I Am PID 1"

Inside the container, the sleep process thinks it's PID 1:

```bash
# Inside the container:
docker exec learn-dd-ns-demo ps aux
```

```
PID   USER     TIME  COMMAND
    1 root      0:00 sleep 3600
   13 root      0:00 ps aux
```

But on the host, it's a completely different PID:

```bash
# On the host:
ps aux | grep "sleep 3600" | grep -v grep
```

This is the PID namespace in action. The kernel maintains a mapping between the "real" PID (host namespace) and the "virtual" PID (container namespace).

### Why PID 1 matters

PID 1 in a namespace has special responsibilities:
- It receives signals that orphaned child processes would otherwise miss
- If PID 1 exits, the entire namespace is destroyed (all processes killed)
- It must handle `SIGTERM` properly — this is why graceful shutdown matters (you learned this in Chapter 06)

---

## NET Namespace: Its Own Network Stack

Each container gets an entirely separate network stack:

```bash
# Container's interfaces:
docker exec learn-dd-ns-demo ip addr

# Host's interfaces:
ip addr
```

The container sees `eth0` and `lo`. The host sees `docker0`, `veth*` interfaces, and the real NICs. They're in different NET namespaces — completely separate routing tables, iptables rules, and interface lists.

---

## UTS Namespace: Its Own Hostname

```bash
# Container hostname:
docker exec learn-dd-ns-demo hostname

# Host hostname:
hostname
```

Different. That's the UTS namespace. It seems trivial, but it matters when applications use the hostname for service registration or logging.

You can set a container's hostname explicitly:

```bash
docker run --rm --hostname espresso-machine alpine hostname
# espresso-machine
```

---

## MNT Namespace: Its Own Filesystem

The container sees a completely different filesystem tree:

```bash
# Container's root filesystem:
docker exec learn-dd-ns-demo ls /

# Host's root filesystem:
ls /
```

The MNT namespace gives the container its own set of mount points. Docker mounts the image's layers as the container's root filesystem, volumes as additional mounts, and `/proc`, `/sys`, `/dev` as special filesystems — all invisible to the host's mount table.

```bash
# Container's mounts:
docker exec learn-dd-ns-demo mount | head -10

# See how Docker sets up the container's mount namespace:
docker inspect learn-dd-ns-demo --format '{{json .Mounts}}' | python3 -m json.tool
```

---

## Creating a Namespace by Hand (Linux Only)

> ⚠️ **macOS users:** The `unshare` command doesn't exist on macOS. Use the Docker-based alternative below.

On a Linux host, you can create namespaces without Docker using `unshare`:

```bash
# Create a new PID and mount namespace, start a shell:
sudo unshare --pid --mount --fork bash

# Inside this new namespace:
mount -t proc proc /proc   # Mount a new /proc for our PID namespace
ps aux                      # You'll see only processes in THIS namespace
echo $$                     # This shell is PID 1 in its namespace

# Exit to return to the host namespace:
exit
```

What just happened:
1. `unshare --pid` created a new PID namespace
2. `--mount` created a new MNT namespace (so our `/proc` mount doesn't affect the host)
3. `--fork` forked a new process into the namespace (required for PID namespaces)
4. Inside, we mounted `/proc` so `ps` would read our namespace's process list

This is essentially what Docker does — but Docker also sets up cgroups, networking, the filesystem layers, and a hundred other things.

### Docker-based alternative (works everywhere)

If you can't use `unshare`, you can observe the same thing through Docker:

```bash
# Run a container and inspect its namespace setup from inside:
docker run --rm -it alpine sh -c '
  echo "My PID: $$"
  echo "My hostname: $(hostname)"
  echo "My interfaces:"
  ip link show
  echo "Processes I can see:"
  ps aux
  echo "My mounts:"
  mount | head -5
'
```

---

## How Docker Uses Namespaces: docker inspect

Docker records namespace configuration in the container's metadata:

```bash
docker inspect learn-dd-ns-demo --format '{{json .HostConfig.PidMode}}'
docker inspect learn-dd-ns-demo --format '{{json .HostConfig.NetworkMode}}'
docker inspect learn-dd-ns-demo --format '{{json .HostConfig.UTSMode}}'
docker inspect learn-dd-ns-demo --format '{{json .HostConfig.IpcMode}}'
```

When you use flags like `--pid=host`, `--network=host`, or `--ipc=host`, you're telling Docker to *not* create a separate namespace — instead, share the host's namespace for that resource.

---

## Namespace Sharing Between Containers

Containers can share namespaces. This is how Kubernetes pods work — all containers in a pod share the same NET and IPC namespaces:

```bash
# Start a container:
docker run -d --name learn-dd-ns-net-source \
  --label app=learn-docker-k8s --label track=deep-dive \
  nginx:alpine

# Start another container that shares its network namespace:
docker run --rm --network container:learn-dd-ns-net-source \
  alpine wget -qO- http://localhost:80 | head -5
```

The second container can reach `localhost:80` because it shares the first container's network namespace — they see the same network stack, same interfaces, same ports.

This is exactly how a Kubernetes pod's sidecar container can reach the main container on `localhost`.

---

## Cleanup

```bash
docker rm -f learn-dd-ns-demo learn-dd-ns-net-source 2>/dev/null
```

---

## Summary

- Namespaces are per-process views of system resources — isolation without virtualization
- Every container process has real namespaces visible under `/proc/[pid]/ns/`
- PID namespace makes the container's entrypoint PID 1 (with all the responsibilities that implies)
- NET namespace gives each container its own network stack
- MNT namespace gives each container its own filesystem
- `unshare` lets you create namespaces by hand — Docker automates this and adds much more
- Containers can share namespaces — that's how K8s pods work

---

**Next:** [cgroups Hands-On](02-cgroups-hands-on.md) — How the kernel enforces resource limits
