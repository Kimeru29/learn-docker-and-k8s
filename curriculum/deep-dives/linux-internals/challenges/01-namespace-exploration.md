# Challenge 01: Namespace Exploration

> "Alright, here's something fun. I'm going to start a container, and I want you to go spelunking through its namespaces. Tell me what you find."
> — Sarah

---

## The Situation

A container is running at NoCappuccino and something seems off — the process inside reports PID 1, but you know there's got to be more to the story. Sarah wants you to investigate the container's namespace setup from the outside and the inside, and explain what you find.

---

## Setup

Start the investigation target:

```bash
docker run -d --name learn-dd-ns-target \
  --label app=learn-docker-k8s --label track=deep-dive \
  --hostname coffee-worker \
  nginx:alpine
```

---

## Your Mission

Answer these questions by investigating the running container. Document your findings — the verification script will check the observable state.

### Part 1: PID Namespace

1. Find the container's main process PID **on the host**
2. Find the main process PID **inside the container** (what does PID 1 think it is?)
3. Verify they're different — explain why

### Part 2: UTS Namespace

4. Check the hostname inside the container
5. Check the hostname on the host
6. Verify they're different — confirm the UTS namespace is doing its job

### Part 3: NET Namespace

7. List the network interfaces inside the container
8. Find the corresponding veth interface on the host side (if on Linux)
9. Confirm the container has its own network stack

### Part 4: Namespace Comparison

10. Create a file that records your findings:

```bash
mkdir -p /tmp/learn-dd-ns-findings
```

Write a file `/tmp/learn-dd-ns-findings/report.txt` with these lines (fill in the actual values):

```
HOST_PID=<the container's PID on the host>
CONTAINER_PID=1
CONTAINER_HOSTNAME=<the container's hostname>
HOST_HOSTNAME=<the host's hostname>
CONTAINER_INTERFACES=<number of network interfaces inside the container>
```

---

## Requirements

Your investigation **must**:

1. Use `docker inspect` and/or `/proc` to find the host PID
2. Use `docker exec` to investigate from inside the container
3. Produce the findings file at `/tmp/learn-dd-ns-findings/report.txt`
4. The container `learn-dd-ns-target` must still be running when you verify

---

## Success Criteria

```bash
bash curriculum/deep-dives/linux-internals/challenges/verify.sh
```

The script checks that:
- The container is running
- Your report file exists with valid data
- HOST_PID matches the actual container PID
- CONTAINER_HOSTNAME matches the container's hostname
- The container's hostname differs from the host's

---

## Hints

<details>
<summary>Hint 1 — Finding the host PID</summary>

`docker inspect` has a format option that can extract specific fields. Look at `.State.Pid` in the inspect output. Try:

```
docker inspect learn-dd-ns-target --format '{{.State.Pid}}'
```

</details>

<details>
<summary>Hint 2 — Inside the container</summary>

You can run commands inside a running container with `docker exec`. To check the PID:

```
docker exec learn-dd-ns-target ps aux
```

The main process (nginx master) will be PID 1 inside the container.

For the hostname: `docker exec learn-dd-ns-target hostname`

For interfaces: `docker exec learn-dd-ns-target ip link show`

</details>

<details>
<summary>Hint 3 — Building the report</summary>

Here's the general approach for creating the report:

```bash
HOST_PID=$(docker inspect learn-dd-ns-target --format '{{.State.Pid}}')
CONTAINER_HOSTNAME=$(docker exec learn-dd-ns-target hostname)
HOST_HOSTNAME=$(hostname)
IFACE_COUNT=$(docker exec learn-dd-ns-target sh -c 'ip link show | grep "^[0-9]" | wc -l')
```

Write these values into the report file using `echo` or `cat`.

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You used `docker inspect` and `docker exec` to observe namespace isolation from both sides — the host and the container. You verified that PID, hostname, and network interfaces are all isolated.

**Why it works:**
Each namespace type wraps a system resource in an abstraction. The PID namespace makes the container's entrypoint appear as PID 1 (while the host sees a different PID). The UTS namespace gives the container its own hostname. The NET namespace provides a separate network stack with its own interfaces.

**Real-world connection:**
When debugging production containers, you often need to correlate a container process with its host-level PID — for example, to check if the OOM killer targeted it (look at `dmesg` on the host for the host PID). Understanding namespace mapping is essential for this.

**Interview angle:**
"What is PID 1 inside a container, and how does it relate to the host?" is a common question. The answer: the container's entrypoint runs as PID 1 inside the PID namespace, but has a different PID on the host. The kernel maintains the mapping. PID 1 has special signal-handling responsibilities.

**Pro tip:**
You can enter a container's namespaces without `docker exec` by using `nsenter`:
```
nsenter -t <host-pid> -p -n -m -- ps aux
```
This is useful when `docker exec` doesn't work (e.g., container is paused or the shell isn't available in the image).

</details>

---

## Cleanup

```bash
docker rm -f learn-dd-ns-target 2>/dev/null
rm -rf /tmp/learn-dd-ns-findings
```
