# Challenge 02: cgroup Limits

> "We've got a container that someone launched with no resource limits. It's been eating memory like Dave eats donuts during deployments. Find it, measure it, and put it on a diet."
> — Sarah

---

## The Situation

A developer at NoCappuccino launched a background processing container without any resource limits. It's been running for a while and is consuming more resources than it should. Your job:

1. Find the container's current resource usage
2. Discover that it has no memory limit
3. Apply a memory limit to the running container
4. Verify the limit is enforced

---

## Setup

Start the offending container:

```bash
docker run -d --name learn-dd-cg-hungry \
  --label app=learn-docker-k8s --label track=deep-dive \
  alpine sh -c '
    # Simulate a process that gradually consumes memory
    mkdir -p /tmp/memhog
    mount -t tmpfs -o size=512m tmpfs /tmp/memhog 2>/dev/null || true
    i=0
    while true; do
      dd if=/dev/urandom of=/tmp/memhog/block_$i bs=1K count=64 2>/dev/null
      i=$((i + 1))
      sleep 2
    done
  '
```

Wait about 10 seconds for it to consume some memory, then begin your investigation.

---

## Your Mission

### Part 1: Investigate

1. Check the container's current resource usage using `docker stats`
2. Determine whether the container has a memory limit set (hint: inspect it)
3. Record your findings

### Part 2: Apply Limits

4. Apply a **128MB memory limit** to the running container (without stopping it)
5. Apply a **0.5 CPU limit** to the running container

### Part 3: Verify

6. Confirm the limits are in effect by inspecting the container
7. Verify the container is still running after applying limits

---

## Requirements

1. Container `learn-dd-cg-hungry` must be running with a **128MB memory limit**
2. Container `learn-dd-cg-hungry` must have a **0.5 CPU limit** (500000000 NanoCpus)
3. The container must still be running (not restarted or recreated)
4. You must NOT stop, remove, and re-run the container — apply limits to the running container

---

## Success Criteria

```bash
bash curriculum/deep-dives/linux-internals/challenges/verify.sh
```

The script checks that:
- The container is running
- Memory limit is set to 134217728 bytes (128MB)
- CPU limit is set to 500000000 NanoCpus (0.5 CPU)

---

## Hints

<details>
<summary>Hint 1 — Checking current limits</summary>

Use `docker inspect` to see the current resource configuration:

```
docker inspect learn-dd-cg-hungry --format '{{.HostConfig.Memory}}'
```

A value of `0` means "no limit." You can also check `NanoCpus` for CPU limits.

For live usage, try `docker stats learn-dd-cg-hungry --no-stream`.

</details>

<details>
<summary>Hint 2 — Applying limits to a running container</summary>

There's a Docker command specifically for updating resource limits on a running container. Check `docker update --help` — it's the command you need.

</details>

<details>
<summary>Hint 3 — The exact command</summary>

```
docker update --memory 128m --cpus 0.5 learn-dd-cg-hungry
```

After running this, verify with:
```
docker inspect learn-dd-cg-hungry --format 'Memory: {{.HostConfig.Memory}}, CPU: {{.HostConfig.NanoCpus}}'
```

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You identified a container running without resource limits, measured its current usage, and applied memory and CPU limits to the running container using `docker update`.

**Why it works:**
`docker update` modifies the cgroup settings for the container's process group in real time. For memory, it writes to `memory.max` (cgroups v2) or `memory.limit_in_bytes` (v1). For CPU, it adjusts `cpu.max`. The kernel applies these limits immediately — no restart needed.

**Real-world connection:**
In production, you'll encounter containers that were deployed without proper resource limits (it happens more than anyone admits). Being able to apply limits to running containers without restarting them is a critical operational skill — especially during an incident when a runaway process is degrading the host.

**Interview angle:**
"How would you handle a container that's consuming too much memory in production?" The answer involves: 1) `docker stats` to confirm the issue, 2) `docker inspect` to check current limits, 3) `docker update` to apply limits without restart. In Kubernetes, you'd edit the resource limits in the pod spec, but that triggers a pod restart.

**Pro tip:**
In Kubernetes, there's no equivalent of `docker update` — you can't change resource limits on a running pod. You have to update the Deployment spec and let it roll out a new pod. This is why getting resource requests and limits right in your manifests is so important. Also look into Vertical Pod Autoscaler (VPA) for automated recommendations.

</details>

---

## Cleanup

```bash
docker rm -f learn-dd-cg-hungry 2>/dev/null
```
