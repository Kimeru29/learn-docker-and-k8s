# Lesson 02: cgroups Hands-On

> "Namespaces are the walls. cgroups are the bouncer. Namespaces decide what you can see; cgroups decide how much you can consume."
> — Sarah

---

## What cgroups Do

**Control groups (cgroups)** are the Linux kernel's mechanism for limiting, accounting, and isolating resource usage of process groups. When you run `docker run --memory 256m --cpus 0.5`, Docker translates those flags directly into cgroup settings.

Without cgroups, a single runaway container could eat all the host's memory and kill everything else. cgroups prevent that.

---

## cgroups v1 vs v2

There are two versions of cgroups, and which one you're running affects where things live in the filesystem.

| | cgroups v1 | cgroups v2 |
|---|-----------|-----------|
| **Hierarchy** | Multiple hierarchies — one per resource controller | Single unified hierarchy |
| **Mount point** | `/sys/fs/cgroup/memory/`, `/sys/fs/cgroup/cpu/`, etc. | `/sys/fs/cgroup/` (unified) |
| **Control files** | `memory.limit_in_bytes`, `cpu.cfs_quota_us` | `memory.max`, `cpu.max` |
| **Default on** | Older kernels, RHEL 7/8, older Docker Desktop | Newer kernels (5.8+), Ubuntu 22.04+, Fedora 31+, newer Docker Desktop |

Check which version you're running:

```bash
# Inside a container (or on the host):
mount | grep cgroup
```

- If you see `cgroup2 on /sys/fs/cgroup type cgroup2` → **v2**
- If you see multiple mounts like `cgroup on /sys/fs/cgroup/memory type cgroup` → **v1**

Or more directly:

```bash
stat -fc %T /sys/fs/cgroup/
# "cgroup2fs" = v2
# "tmpfs"     = v1
```

> This lesson shows both v1 and v2 paths. Most modern systems use v2.

---

## Finding a Container's cgroup Path

Start a container with resource limits:

```bash
docker run -d --name learn-dd-cg-demo \
  --label app=learn-docker-k8s --label track=deep-dive \
  --memory 128m --cpus 0.5 \
  alpine sleep 3600
```

### Method 1: docker inspect

```bash
docker inspect learn-dd-cg-demo --format '{{json .HostConfig.Memory}}'
# 134217728 (that's 128 * 1024 * 1024 bytes)

docker inspect learn-dd-cg-demo --format '{{json .HostConfig.NanoCpus}}'
# 500000000 (that's 0.5 CPUs in nanoseconds)

docker inspect learn-dd-cg-demo --format '{{json .HostConfig.CgroupParent}}'
```

### Method 2: Read /proc inside the container

The container can see its own cgroup membership:

```bash
docker exec learn-dd-cg-demo cat /proc/1/cgroup
```

On cgroups v2, you'll see something like:

```
0::/system.slice/docker-<container-id>.scope
```

On cgroups v1, you'll see multiple lines — one per controller:

```
12:memory:/docker/<container-id>
11:cpu,cpuacct:/docker/<container-id>
...
```

### Method 3: Read the cgroup filesystem directly

On a Linux host (or inside the Docker Desktop VM), you can read the actual cgroup control files.

**cgroups v2:**

```bash
CONTAINER_ID=$(docker inspect learn-dd-cg-demo --format '{{.Id}}')

# Memory limit:
cat /sys/fs/cgroup/system.slice/docker-${CONTAINER_ID}.scope/memory.max
# 134217728

# CPU limit:
cat /sys/fs/cgroup/system.slice/docker-${CONTAINER_ID}.scope/cpu.max
# 50000 100000
# That means: 50000 microseconds per 100000 microsecond period = 50% of one CPU
```

**cgroups v1:**

```bash
cat /sys/fs/cgroup/memory/docker/${CONTAINER_ID}/memory.limit_in_bytes
cat /sys/fs/cgroup/cpu/docker/${CONTAINER_ID}/cpu.cfs_quota_us
cat /sys/fs/cgroup/cpu/docker/${CONTAINER_ID}/cpu.cfs_period_us
```

> ⚠️ **Docker Desktop users:** These paths exist inside the Docker Desktop VM, not on your macOS filesystem. You can access them via:
> ```bash
> docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -u -i -n \
>   cat /sys/fs/cgroup/system.slice/docker-${CONTAINER_ID}.scope/memory.max
> ```

---

## Reading Current Resource Usage

cgroups don't just enforce limits — they also track current usage.

```bash
# Current memory usage (cgroups v2):
docker exec learn-dd-cg-demo cat /sys/fs/cgroup/memory.current

# Or via docker stats (real-time):
docker stats learn-dd-cg-demo --no-stream --format \
  "CPU: {{.CPUPerc}}, MEM: {{.MemUsage}}, MEM%: {{.MemPerc}}"
```

You can also read individual counters:

```bash
# Memory stats breakdown (cgroups v2):
docker exec learn-dd-cg-demo cat /sys/fs/cgroup/memory.stat
```

This shows `anon` (heap/stack), `file` (page cache), `slab`, and other memory categories. When debugging memory issues, this breakdown is invaluable.

---

## What Happens at the Memory Limit

This is the critical behavior to understand. When a container's memory usage hits `memory.max`, the kernel's OOM killer activates.

Let's watch it happen:

```bash
# Run a container with a 64MB limit:
docker run --rm --name learn-dd-cg-oom \
  --label app=learn-docker-k8s --label track=deep-dive \
  --memory 64m \
  alpine sh -c '
    echo "Allocating memory until OOM..."
    # Use dd to allocate blocks of memory via tmpfs
    mkdir -p /tmp/fillmem
    mount -t tmpfs -o size=256m tmpfs /tmp/fillmem
    dd if=/dev/zero of=/tmp/fillmem/block bs=1M count=256 2>&1
    echo "This line should not appear"
  '
```

The container will be killed by the OOM killer before it can allocate 256MB. Check the exit code:

```bash
echo $?
# 137 = killed by signal 9 (SIGKILL from OOM killer)
```

You can see OOM events in Docker:

```bash
docker inspect learn-dd-cg-oom --format '{{.State.OOMKilled}}' 2>/dev/null
# true (if the container still exists — it won't with --rm)
```

### Exit code 137 decoded

- Exit code `137` = `128 + 9`
- Signal `9` = `SIGKILL`
- The kernel OOM killer sends `SIGKILL` — it cannot be caught, blocked, or handled
- Your application gets no warning and no chance for graceful shutdown

This is why setting memory limits correctly matters. Too low and you get random OOM kills. No limit and a memory leak takes down the host.

---

## CPU Limits: How They Actually Work

CPU limits in cgroups work differently from memory limits. They use a **CFS (Completely Fair Scheduler) bandwidth control** mechanism.

```bash
# Container with 0.5 CPU limit:
docker exec learn-dd-cg-demo cat /sys/fs/cgroup/cpu.max
# 50000 100000
```

This means: out of every 100,000 microseconds (100ms), this cgroup can use at most 50,000 microseconds (50ms) of CPU time. That's 50% of one CPU core.

**Key difference from memory:** hitting a CPU limit does NOT kill the process. It just gets **throttled** — the scheduler stops giving it CPU time until the next period. The process slows down but stays alive.

```bash
# See CPU throttling stats (cgroups v2):
docker exec learn-dd-cg-demo cat /sys/fs/cgroup/cpu.stat
```

Look for `nr_throttled` and `throttled_usec` — if these are non-zero, the container is being throttled.

### CPU limit vs CPU request (Kubernetes preview)

In Kubernetes:
- **CPU request** = the minimum guaranteed CPU (used for scheduling)
- **CPU limit** = the maximum CPU (enforced via cgroups)

Both translate to cgroup settings. You'll see this in Chapter 14.

---

## Manually Setting cgroup Limits (Linux Only)

On a Linux host, you can manually write to cgroup files to change limits on a running container. This is exactly what `docker update` does under the hood.

```bash
# Using docker update (works everywhere):
docker update --memory 256m learn-dd-cg-demo

# Verify:
docker inspect learn-dd-cg-demo --format '{{.HostConfig.Memory}}'
# 268435456 (256MB)
```

On a Linux host, the equivalent raw cgroup operation would be:

```bash
# Direct cgroup write (v2):
echo 268435456 > /sys/fs/cgroup/system.slice/docker-${CONTAINER_ID}.scope/memory.max
```

`docker update` is the safe way to do this. Direct cgroup writes bypass Docker's tracking and can cause inconsistencies.

---

## Practical: Resource Monitoring

Use `docker stats` for a live dashboard of all container resource usage:

```bash
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
```

For a specific container:

```bash
docker stats learn-dd-cg-demo --no-stream
```

The values here come directly from reading the cgroup accounting files. `docker stats` is essentially a formatted view of `/sys/fs/cgroup/*/` data.

---

## The cgroup Hierarchy

cgroups are organized in a tree. Each node can have limits that constrain all child nodes:

```
/sys/fs/cgroup/
├── system.slice/
│   ├── docker-<container-A>.scope/
│   │   ├── memory.max         ← container A's memory limit
│   │   ├── memory.current     ← container A's current memory
│   │   └── cpu.max            ← container A's CPU limit
│   ├── docker-<container-B>.scope/
│   │   └── ...
│   └── ...
└── user.slice/
    └── ...                    ← non-container processes
```

Docker places each container in its own cgroup scope under `system.slice` (on systemd-based systems). This isolation means:
- Each container's resource usage is tracked independently
- Limits on one container don't affect others
- You can set limits at the slice level to cap ALL containers collectively

---

## Cleanup

```bash
docker rm -f learn-dd-cg-demo 2>/dev/null
```

---

## Summary

- cgroups limit and track resource usage per process group
- `memory.max` enforces a hard memory ceiling — exceeding it triggers the OOM killer (exit code 137)
- `cpu.max` enforces CPU bandwidth — exceeding it throttles the process (doesn't kill it)
- cgroups v2 uses a unified hierarchy under `/sys/fs/cgroup/`; v1 uses separate hierarchies per controller
- `docker stats` reads cgroup accounting files to show real-time usage
- `docker update` modifies cgroup limits on running containers
- Understanding cgroup behavior is essential for setting resource requests and limits in Kubernetes

---

**Next:** [OverlayFS and Layers](03-overlayfs-and-layers.md) — How image layering actually works at the filesystem level
