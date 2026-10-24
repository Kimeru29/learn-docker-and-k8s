# Lesson 01: veth Pairs and Bridges

> "Every time you run a container, Docker builds a tiny virtual network cable and plugs one end into your container and the other end into a switch. Let me show you the wiring."
> — Sarah

---

## How Container Networking Actually Works

When you run `docker run -p 8080:80 nginx`, Docker does far more than "start a process." At the networking level, it:

1. Creates a **network namespace** for the container (you learned this in the Linux Internals deep dive — or Chapter 01)
2. Creates a **veth pair** — a virtual ethernet cable with two ends
3. Places one end (`eth0`) inside the container's network namespace
4. Attaches the other end (`vethXXXXXX`) to the **docker0 bridge** on the host
5. Assigns an IP address to the container's `eth0` from the bridge's subnet
6. Sets up routes so the container can reach the outside world through the bridge

Let's see all of this happening on a real container.

---

## Starting Our Investigation

```bash
docker run -d --name learn-dd-net-web \
  --label app=learn-docker-k8s --label track=deep-dive \
  -p 8888:80 \
  nginx:alpine
```

---

## Step 1: The docker0 Bridge

The `docker0` bridge is Docker's default virtual switch. It's created when Docker starts.

```bash
# On Linux:
ip link show docker0

# Or via Docker:
docker network inspect bridge --format '{{json .IPAM.Config}}' | python3 -m json.tool
```

You'll see something like:

```json
[
    {
        "Subnet": "172.17.0.0/16",
        "Gateway": "172.17.0.1"
    }
]
```

The bridge (`docker0`) acts as the gateway for all containers on the default bridge network. It has IP `172.17.0.1`, and containers get IPs from the `172.17.0.0/16` subnet.

```
  Host
  ┌────────────────────────────────────────┐
  │                                        │
  │    docker0 bridge (172.17.0.1)         │
  │    ┌──────────────────────────┐        │
  │    │  vethA ──── vethB ────── │        │
  │    │    │           │         │        │
  │    └────┼───────────┼─────────┘        │
  │         │           │                  │
  │    ┌────▼────┐ ┌────▼────┐             │
  │    │Container│ │Container│             │
  │    │  .2     │ │  .3     │             │
  │    │  eth0   │ │  eth0   │             │
  │    └─────────┘ └─────────┘             │
  └────────────────────────────────────────┘
```

---

## Step 2: Finding the veth Pair

A **veth pair** is a virtual ethernet cable. Packets sent into one end come out the other. One end lives in the container's network namespace (as `eth0`), the other lives in the host's namespace (as `vethXXXXXX`).

### Find the container's interface

```bash
# Inside the container — see eth0:
docker exec learn-dd-net-web ip link show

# You'll see:
# 1: lo: <LOOPBACK,UP,LOWER_UP> ...
# 42: eth0@if43: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
```

Note the numbers: `42: eth0@if43`. This means:
- Interface index 42 is `eth0` inside the container
- `@if43` means the peer (other end of the veth pair) has index 43 on the host

### Find the host-side veth

```bash
# On Linux:
ip link show | grep "^43:"

# You'll see something like:
# 43: veth3a8f2c1@if42: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
#                                   master docker0
```

The `master docker0` part confirms this veth end is plugged into the docker0 bridge.

> ⚠️ **Docker Desktop users:** The host-side veth lives inside the Docker Desktop VM. Access it with:
> ```bash
> docker run --rm --privileged --pid=host --network=host \
>   alpine ip link show | grep veth
> ```

### Match the pair

```bash
# Container side:
docker exec learn-dd-net-web cat /sys/class/net/eth0/iflink
# Output: 43 (the host-side interface index)

# Host side (Linux):
cat /sys/class/net/veth3a8f2c1/iflink
# Output: 42 (the container-side interface index)
```

They point to each other — that's the pair.

---

## Step 3: IP Addresses and Routes

### Container's network configuration

```bash
# IP address:
docker exec learn-dd-net-web ip addr show eth0
# inet 172.17.0.2/16 ...

# Routing table:
docker exec learn-dd-net-web ip route
# default via 172.17.0.1 dev eth0
# 172.17.0.0/16 dev eth0 scope link
```

The container has:
- IP `172.17.0.2` on the `172.17.0.0/16` subnet
- A default route through `172.17.0.1` (the docker0 bridge) for internet access

### How outbound traffic flows

When the container pings `8.8.8.8`:

```
Container eth0 (172.17.0.2)
    │
    ▼  veth pair
Host vethXXXXXX
    │
    ▼  bridge forwarding
docker0 (172.17.0.1)
    │
    ▼  IP forwarding + NAT (iptables MASQUERADE)
Host eth0 / en0 (real NIC)
    │
    ▼
Internet
```

1. Packet enters the veth pair's container end
2. Comes out the host end, into the docker0 bridge
3. The host's IP forwarding sends it to the real NIC
4. iptables SNAT (masquerade) rewrites the source IP from `172.17.0.2` to the host's IP
5. The response follows the reverse path

---

## Step 4: Bridge Details

You can see all interfaces plugged into the docker0 bridge:

```bash
# On Linux:
bridge link show

# Or:
brctl show docker0    # if bridge-utils is installed

# Or via ip:
ip link show master docker0
```

Each `vethXXXXXX` shown as `master docker0` is the host-side end of a container's veth pair.

---

## User-Defined Bridges

When you create a user-defined network, Docker creates a **separate bridge**:

```bash
docker network create \
  --label app=learn-docker-k8s --label track=deep-dive \
  learn-dd-net-custom

# A new bridge interface appears on the host:
# On Linux:
ip link show type bridge
```

Each user-defined bridge is isolated — containers on `learn-dd-net-custom` cannot reach containers on `docker0` unless you explicitly connect them to both networks.

The key difference: user-defined bridges run Docker's embedded DNS server (at `127.0.0.11`) for container name resolution. The default bridge does not.

---

## Multiple Networks on One Container

A container can be connected to multiple bridges simultaneously:

```bash
docker run -d --name learn-dd-net-multi \
  --label app=learn-docker-k8s --label track=deep-dive \
  --network learn-dd-net-custom \
  alpine sleep 3600

# Also connect to the default bridge:
docker network connect bridge learn-dd-net-multi

# The container now has TWO eth interfaces:
docker exec learn-dd-net-multi ip addr
# eth0 — connected to learn-dd-net-custom
# eth1 — connected to default bridge
```

Each interface is one end of a separate veth pair, plugged into a different bridge. The container can reach hosts on both networks.

---

## Cleanup

```bash
docker rm -f learn-dd-net-web learn-dd-net-multi 2>/dev/null
docker network rm learn-dd-net-custom 2>/dev/null
```

---

## Summary

- Docker creates a **veth pair** for each container — a virtual cable connecting the container to a bridge
- The **docker0 bridge** is the default virtual switch; user-defined bridges are separate
- Container `eth0` is one end of the veth pair; the host-side `vethXXX` is the other end
- Outbound traffic flows: container → veth → bridge → host NIC → internet (with SNAT)
- You can match veth pairs using `/sys/class/net/*/iflink` or the `@ifN` notation in `ip link`
- User-defined bridges add DNS; the default bridge does not

---

**Next:** [iptables and NAT](02-iptables-and-nat.md) — How Docker rewrites packet destinations for port mapping
