# Challenge 01: Trace the Packet

> "I've got a web app running with port mapping. Your job: trace the entire network path from the host to the container. Every hop. Every interface. Every rule."
> — Sarah

---

## The Situation

A container is serving traffic on `localhost:7777`, mapped to port 80 inside the container. Sarah wants you to trace the full packet path and document every hop. This is the kind of investigation you'd do when "port mapping doesn't work" and you need to figure out where packets are getting lost.

---

## Setup

```bash
docker run -d --name learn-dd-net-trace \
  --label app=learn-docker-k8s --label track=deep-dive \
  -p 7777:80 \
  nginx:alpine
```

Verify it works:

```bash
curl -s http://localhost:7777 | head -3
```

---

## Your Mission

Trace the network path from `localhost:7777` to the nginx process inside the container. Document each hop by creating a report file.

### What to find

1. **The iptables DNAT rule** — find the specific rule that rewrites destination port 7777 to the container
2. **The container's IP address** — what IP does the DNAT rule point to?
3. **The container's veth pair** — find the interface name on the host side
4. **The bridge** — which bridge is the veth attached to?
5. **The container's interface** — what does `eth0` look like inside the container?

### Create the report

Write your findings to `/tmp/learn-dd-net-trace/report.txt`:

```
CONTAINER_IP=<container's IP address, e.g., 172.17.0.2>
HOST_VETH=<host-side veth interface name, e.g., veth3a8f2c1>
BRIDGE=<bridge name, e.g., docker0>
HOST_PORT=7777
CONTAINER_PORT=80
DNAT_RULE_EXISTS=yes
```

---

## Requirements

1. Container `learn-dd-net-trace` must be running and accessible on port 7777
2. Report file at `/tmp/learn-dd-net-trace/report.txt` with accurate data
3. `CONTAINER_IP` must match the container's actual IP address
4. `DNAT_RULE_EXISTS` must be `yes`
5. `curl http://localhost:7777` must return a response

---

## Success Criteria

```bash
bash curriculum/deep-dives/advanced-networking/challenges/verify.sh
```

---

## Hints

<details>
<summary>Hint 1 — Finding the container's IP</summary>

Use `docker inspect` to get the container's IP address:

```
docker inspect learn-dd-net-trace --format '{{.NetworkSettings.IPAddress}}'
```

Or look at the iptables DNAT rule — it shows the destination IP and port.

</details>

<details>
<summary>Hint 2 — Finding the iptables rule</summary>

The iptables rule is in the nat table's DOCKER chain. You need to access it from the Docker host's network context.

On Linux:
```
sudo iptables -t nat -L DOCKER -n | grep 7777
```

On Docker Desktop, you'll need a privileged container:
```
docker run --rm --privileged --network=host alpine sh -c \
  'apk add --no-cache iptables > /dev/null 2>&1 && iptables -t nat -L DOCKER -n'
```

</details>

<details>
<summary>Hint 3 — Finding the veth pair</summary>

From inside the container, find the peer interface index:

```
docker exec learn-dd-net-trace cat /sys/class/net/eth0/iflink
```

That number is the interface index on the host. On Linux, find it with:

```
ip link show | grep "^<index>:"
```

If you can't access host interfaces directly (Docker Desktop), you can report the peer index or use a privileged container.

For the report: if finding the exact veth name isn't possible on your platform, set `HOST_VETH=unknown` — the verify script accepts this on Docker Desktop.

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You traced the complete network path from host port 7777 to the nginx process inside the container, identifying the iptables DNAT rule, the container's IP, the veth pair, and the bridge.

**Why it works:**
The path is: incoming packet → iptables PREROUTING → DOCKER chain DNAT (rewrites destination to container IP:80) → routing decision → FORWARD chain → docker0 bridge → veth pair → container's eth0 → nginx. The response follows the reverse path with SNAT masquerading the source IP.

**Real-world connection:**
When "the container can't be reached from outside" or "port mapping stopped working," this is exactly how you debug it. Check each hop: is the iptables rule there? Is the bridge up? Is the veth pair connected? Is the process actually listening? Most networking problems are a break in one of these links.

**Interview angle:**
"How does Docker port mapping work under the hood?" is an advanced interview question. The answer: Docker creates an iptables DNAT rule in the nat table that rewrites the destination IP and port of incoming packets from the host port to the container's IP and port. The reverse direction uses connection tracking (conntrack) to route responses back.

**Pro tip:**
`iptables -t nat -L -n -v` (with `-v` for verbose) shows packet and byte counters for each rule. If the counter is zero, no packets have matched that rule — useful for confirming whether traffic is actually hitting the expected path.

</details>

---

## Cleanup

```bash
docker rm -f learn-dd-net-trace 2>/dev/null
rm -rf /tmp/learn-dd-net-trace
```
