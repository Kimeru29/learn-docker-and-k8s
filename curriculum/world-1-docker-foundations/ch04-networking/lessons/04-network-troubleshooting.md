# Lesson 4: Network Troubleshooting

> "Every networking problem has a systematic diagnosis path. Most people skip straight to 'restart everything' -- which is just Dave-ing it. Let's be better than that."
> -- Sarah

---

## Why This Lesson Exists

You've learned how Docker networking works: drivers, DNS, port mapping. But in the real world, things break. Containers can't reach each other. Ports appear mapped but nothing responds. DNS names resolve to the wrong IP. Connections time out for no apparent reason.

This lesson gives you a systematic approach to diagnosing network issues in Docker -- the same approach I use at 3 AM when something's broken.

---

## The Troubleshooting Framework

When a container can't talk to something, follow this path:

```
1. Is the container running?
       |
       v
2. Is the service listening inside the container?
       |
       v
3. Are the containers on the same network?
       |
       v
4. Can they resolve each other by name (DNS)?
       |
       v
5. Can they ping each other by IP?
       |
       v
6. Is the port mapping correct (for host access)?
       |
       v
7. Is the app binding to the right interface?
```

Let's go through each step with the actual commands you'd use.

---

## Step 1: Is the Container Running?

This sounds obvious, but it's the first thing to check.

```bash
docker ps --filter name=learn-ch04-backend
```

If the container isn't running, check why it stopped:

```bash
docker ps -a --filter name=learn-ch04-backend
docker logs learn-ch04-backend
```

An `Exited (1)` status means the application crashed. Check the logs for the error.

---

## Step 2: Is the Service Listening?

The container is running, but is the process actually listening on the expected port?

```bash
# Check what ports are being listened on inside the container:
docker exec learn-ch04-backend netstat -tlnp
```

If `netstat` isn't available (common in minimal images), try:

```bash
docker exec learn-ch04-backend ss -tlnp
```

If neither is available, install one temporarily or use a sidecar:

```bash
# Run a diagnostic container that shares the target's network namespace:
docker run --rm --network container:learn-ch04-backend \
  nicolaka/netshoot ss -tlnp
```

**What to look for:**

```
State    Recv-Q   Send-Q   Local Address:Port   Peer Address:Port
LISTEN   0        128      0.0.0.0:3000         0.0.0.0:*
```

- `0.0.0.0:3000` -- listening on all interfaces (good for containers)
- `127.0.0.1:3000` -- listening on loopback only (bad -- port mapping won't work)

---

## Step 3: Are They on the Same Network?

Containers on different Docker networks cannot communicate by default.

```bash
# Check which networks a container is connected to:
docker inspect learn-ch04-backend \
  --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$net}} -> {{$cfg.IPAddress}}{{"\n"}}{{end}}'
```

```bash
# Compare with the other container:
docker inspect learn-ch04-frontend \
  --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$net}} -> {{$cfg.IPAddress}}{{"\n"}}{{end}}'
```

If they're on different networks, either connect them to the same network:

```bash
docker network connect learn-ch04-app-net learn-ch04-backend
```

Or create a new shared network and connect both.

---

## Step 4: DNS Resolution

On a user-defined network, containers should resolve each other by name.

```bash
# From inside the frontend container, try to resolve the backend:
docker exec learn-ch04-frontend nslookup learn-ch04-backend
```

Expected output:
```
Server:    127.0.0.11
Address 1: 127.0.0.11

Name:      learn-ch04-backend
Address 1: 172.18.0.3 learn-ch04-backend.learn-ch04-app-net
```

**Common failures:**

| Symptom | Cause |
|---------|-------|
| `can't resolve 'learn-ch04-backend'` | Containers are on the default bridge (no DNS) |
| `server can't find learn-ch04-backend: NXDOMAIN` | Container name is wrong or container isn't on the same network |
| Resolves but wrong IP | Container was recreated and got a new IP (shouldn't matter with DNS, but check) |

If `nslookup` isn't available:

```bash
docker exec learn-ch04-frontend ping -c 1 learn-ch04-backend
```

The error message tells you if it's a DNS failure (`bad address`) vs. a connectivity failure (`Network unreachable`).

---

## Step 5: Connectivity Test

DNS resolves, but can they actually talk?

```bash
# Ping by name:
docker exec learn-ch04-frontend ping -c 3 learn-ch04-backend

# Ping by IP (to bypass DNS):
docker exec learn-ch04-frontend ping -c 3 172.18.0.3

# Test a specific port with curl:
docker exec learn-ch04-frontend curl -v http://learn-ch04-backend:3000

# Or wget (available on Alpine):
docker exec learn-ch04-frontend wget -qO- http://learn-ch04-backend:3000
```

**Common failures:**

| Symptom | Likely cause |
|---------|-------------|
| Ping works but curl fails | Service not listening on that port, or wrong port number |
| `Connection refused` | Service is listening on a different port or interface |
| `Connection timed out` | Firewall, wrong network, or container is unresponsive |
| `No route to host` | Containers are on completely separate networks with no bridge |

---

## Step 6: Port Mapping (Host Access)

If you need to access the container from the host (not from another container), check the port mapping:

```bash
# See all port mappings for a container:
docker port learn-ch04-backend

# Detailed view:
docker inspect learn-ch04-backend \
  --format '{{json .NetworkSettings.Ports}}' | python3 -m json.tool
```

**Common failures:**

| Symptom | Cause |
|---------|-------|
| No output from `docker port` | No `-p` flag was used when starting the container |
| Port shows mapped but host can't connect | The app inside is binding to `127.0.0.1` (see Step 7) |
| `address already in use` when starting container | Another process (or container) is already using that host port |

### Finding Port Conflicts

```bash
# What's using port 3000 on the host?
lsof -i :3000

# Or on Linux:
ss -tlnp | grep :3000

# Check if another container has the same port:
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep 3000
```

---

## Step 7: The 0.0.0.0 vs 127.0.0.1 Trap

This is the most subtle and most common networking bug in Docker. We covered it in Lesson 3, but let's see it from the troubleshooting angle.

### The symptom

- Container is running
- Port mapping shows correctly (`0.0.0.0:3000->3000/tcp`)
- `docker logs` shows "Server listening on 127.0.0.1:3000"
- `curl http://localhost:3000` from the host fails

### The diagnosis

```bash
# Check what the app is actually listening on:
docker exec learn-ch04-backend ss -tlnp | grep 3000
```

If you see:
```
LISTEN   0   128   127.0.0.1:3000   0.0.0.0:*
```

The app is listening on the container's **loopback** interface. Docker's port mapping routes traffic to the container's **eth0** interface. The traffic arrives but nobody is listening on eth0.

### The fix

Change the application to bind to `0.0.0.0` instead of `127.0.0.1`:

```javascript
// Bad:
server.listen(3000, '127.0.0.1');

// Good:
server.listen(3000, '0.0.0.0');

// Also good (most frameworks default to 0.0.0.0):
server.listen(3000);
```

This applies to every language and framework:
- **Python Flask**: `app.run(host='0.0.0.0')`
- **Rails**: `rails server -b 0.0.0.0`
- **Django**: `python manage.py runserver 0.0.0.0:8000`
- **Go**: `http.ListenAndServe(":8080", nil)` (already binds to all interfaces)

---

## Conceptual: How Docker's iptables Rules Work

When you use `-p 8080:80`, Docker creates rules in the host's `iptables` (or nftables on newer kernels). You don't need to memorize iptables syntax, but understanding the concept helps you debug.

```
# Incoming traffic path:
Host port 8080
    |
    v
iptables PREROUTING chain (DNAT rule)
    |  Rewrites destination: host:8080 -> container_ip:80
    v
FORWARD chain (allows the packet through)
    |
    v
Container eth0:80
    |
    v
Application inside the container
```

### When iptables rules go stale

If Docker crashes or is killed without cleaning up, leftover iptables rules can cause:
- Port conflicts ("address already in use" even though no container is running)
- Ghost port mappings that route traffic to nowhere

The fix is usually to restart the Docker daemon:
```bash
sudo systemctl restart docker
```

This cleans up all Docker-managed iptables rules and recreates them for running containers.

---

## Common Failure Patterns: Quick Reference

| Problem | Check | Fix |
|---------|-------|-----|
| "host not found" / DNS failure | Are containers on a user-defined network? | Create one and connect both containers |
| "Connection refused" from host | Is the app binding to `0.0.0.0`? | Change bind address in the application |
| "Connection refused" between containers | Is the target service actually running and listening? | Check with `docker exec` + `ss -tlnp` |
| Port conflict on host | Is another process using that port? | `lsof -i :PORT` then stop the conflict |
| Container starts then exits | Check logs for crash | `docker logs CONTAINER` |
| Timeout / no response | Are they on the same network? | `docker inspect` both containers |
| Works by IP but not by name | Default bridge network (no DNS) | Use a user-defined network |

---

## The netshoot Swiss Army Knife

When a container image is too minimal for debugging (no `curl`, no `ping`, no `nslookup`), use the `nicolaka/netshoot` image:

```bash
# Run netshoot on a specific container's network namespace:
docker run --rm -it \
  --network container:learn-ch04-backend \
  nicolaka/netshoot

# Now you have every networking tool available:
# curl, wget, ping, nslookup, dig, traceroute, nmap,
# tcpdump, iftop, mtr, ss, ip, iptables, etc.
```

This is the Docker equivalent of a network engineer's toolkit. Bookmark it.

---

## Key Takeaways

1. Follow the systematic path: running? -> listening? -> same network? -> DNS? -> connectivity? -> port mapping? -> bind address?
2. `docker exec` + `ss -tlnp` is your best friend for checking what's listening inside a container
3. The `0.0.0.0` vs `127.0.0.1` bind address is the most common silent failure in Docker networking
4. Port conflicts on the host are diagnosed with `lsof -i :PORT` or `ss -tlnp`
5. The `nicolaka/netshoot` image gives you every diagnostic tool in a container with no install needed
6. When in doubt, check `docker inspect` for network configuration and `docker logs` for application errors

---

**Ready for the challenges? Let's fix NoCappuccino's networking.**

**First challenge:** [Fix the DNS](../challenges/01-fix-dns.md)
