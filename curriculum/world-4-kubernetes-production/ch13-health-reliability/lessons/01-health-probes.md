# Lesson 1: Health Probes

> **Sarah:** "Yesterday, the API pod was 'Running' for forty minutes while the process inside was stuck in a deadlock. No errors in the logs — just silence. Customers got 500s the entire time. Kubernetes didn't restart it because nobody told Kubernetes what 'healthy' means."

---

## The Gap Between Running and Healthy

When Kubernetes starts a container, it watches the **process**. If the process is running (PID 1 is alive), the pod status says `Running`. That's it. Kubernetes has no idea if:

- The application inside has finished loading its configuration
- The HTTP server is accepting connections
- The database connection is established
- The app is stuck in an infinite loop, returning errors to every request

A pod can be `Running` and completely broken. Health probes close this gap.

---

## The Three Probe Types

Kubernetes supports three probe types, each with a different purpose and a different consequence when it fails.

### Startup Probe

**Question it answers:** "Has this container finished starting up?"

**When it runs:** Only during initial startup. Once it succeeds, it never runs again.

**What happens on failure:** The container is killed and restarted (subject to restart policy).

**Why it exists:** Some applications take a long time to start. A Java app loading a large classpath, a machine learning model loading weights, a service waiting for a database migration to complete. Without a startup probe, a liveness probe might kill the container before it even finishes initializing.

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 10
```

This configuration gives the app up to **300 seconds** (30 failures × 10 seconds) to start. During that window, liveness and readiness probes are disabled. Once the startup probe succeeds, the liveness and readiness probes take over.

**When to use:** Applications with variable or long startup times. If your app starts in under 5 seconds consistently, you probably don't need a startup probe.

---

### Readiness Probe

**Question it answers:** "Is this container ready to receive traffic?"

**When it runs:** Continuously, for the lifetime of the pod, after the startup probe passes (or immediately if no startup probe is configured).

**What happens on failure:** The pod is **removed from Service endpoints**. Traffic stops flowing to it. The pod is NOT restarted. It remains running and will be added back to endpoints when the probe passes again.

**Why it exists:** A container might be running but temporarily unable to handle requests. It could be:
- Warming up a cache
- Waiting for a dependency to become available
- Processing a backlog and unable to take new work
- Briefly overloaded

In all these cases, you don't want to kill the pod (it will recover). You just want to stop sending it traffic.

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
  successThreshold: 1
```

**Critical for rolling updates:** During a rolling update, the new pod is not counted as "Ready" until its readiness probe passes. Without a readiness probe, Kubernetes considers the pod Ready the instant the container starts — and may remove old pods before new ones can actually handle traffic.

---

### Liveness Probe

**Question it answers:** "Is this container still alive and functioning?"

**When it runs:** Continuously, for the lifetime of the pod, after the startup probe passes.

**What happens on failure:** The container is **killed and restarted**. This is the nuclear option — Kubernetes decides the container is irrecoverable and replaces it.

**Why it exists:** Sometimes applications enter a broken state they cannot recover from:
- Deadlocked threads
- Memory corruption that doesn't crash the process
- An HTTP server that accepts connections but never sends responses
- An infinite loop consuming CPU but doing no useful work

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 10
  failureThreshold: 3
```

**The most common mistake with liveness probes:** Making them too aggressive. If your liveness probe has `failureThreshold: 1` and `periodSeconds: 5`, a single slow response (perhaps during a garbage collection pause or a brief CPU spike) will kill the pod. The pod restarts, which causes load to shift to the remaining pods, which makes them slower, which triggers more restarts. This is a **restart cascade** and it can take down your entire service.

---

## Probe Mechanisms

All three probe types support the same three mechanisms:

### HTTP GET

The most common. Kubernetes sends an HTTP GET request and considers the probe successful if the response status is 200–399.

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
      - name: Accept
        value: application/json
```

### TCP Socket

Kubernetes attempts a TCP connection. If the connection succeeds (the port is open), the probe passes. Useful for services that don't expose HTTP endpoints (databases, message brokers).

```yaml
readinessProbe:
  tcpSocket:
    port: 5432
```

### Exec Command

Kubernetes runs a command inside the container. If the command exits with code 0, the probe passes. Useful for custom health checks.

```yaml
livenessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - pg_isready -U postgres
```

### gRPC (Kubernetes 1.24+)

For gRPC services, Kubernetes can call the standard health checking protocol directly.

```yaml
livenessProbe:
  grpc:
    port: 50051
    service: "myapp"
```

---

## Probe Parameters

Every probe supports these timing parameters:

| Parameter | Default | What it controls |
|-----------|---------|-----------------|
| `initialDelaySeconds` | 0 | Seconds to wait after container starts before running the first probe |
| `periodSeconds` | 10 | How often to run the probe |
| `timeoutSeconds` | 1 | How long to wait for a probe response before considering it failed |
| `failureThreshold` | 3 | Number of consecutive failures before taking action |
| `successThreshold` | 1 | Number of consecutive successes before considering the probe passed (only applies to readiness; liveness and startup require 1) |

### Timing example

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5    # Wait 5s after start
  periodSeconds: 5          # Check every 5s
  timeoutSeconds: 3         # Each check has 3s to respond
  failureThreshold: 3       # 3 consecutive failures = not ready
  successThreshold: 2       # 2 consecutive successes = ready again
```

Timeline: container starts → wait 5s → first check → check every 5s → after 3 consecutive failures (15s worst case), pod is removed from endpoints → after 2 consecutive successes (10s), pod is added back.

---

## Common Mistakes

### Mistake 1: Using liveness where readiness belongs

**Symptom:** Pods keep restarting during temporary slowdowns.

A readiness probe removes the pod from traffic. A liveness probe kills it. If your app is temporarily slow (heavy load, dependency timeout), readiness is the right tool — it removes traffic pressure and lets the pod recover. Liveness is for when the pod is broken beyond recovery.

**Rule of thumb:** If the pod will recover on its own, use readiness. If the pod will never recover without a restart, use liveness.

### Mistake 2: Liveness probe checks dependencies

**Symptom:** All pods restart when a downstream service goes down.

```yaml
# BAD: liveness probe checks the database
livenessProbe:
  httpGet:
    path: /healthz  # This endpoint queries the DB
    port: 8080
```

If `/healthz` checks the database, and the database goes down, every pod fails the liveness probe and restarts. The pods weren't broken — the database was. Now you have a thundering herd of pods all restarting simultaneously, all trying to reconnect to an already-overloaded database.

**Fix:** Liveness probes should check the application process, not its dependencies. Readiness probes can (and should) check dependencies — removing the pod from traffic while the dependency is down.

```yaml
# GOOD: liveness checks the process, readiness checks dependencies
livenessProbe:
  httpGet:
    path: /livez    # Only checks: is the HTTP server running?
    port: 8080

readinessProbe:
  httpGet:
    path: /readyz   # Checks: is the app ready to serve? (DB, cache, etc.)
    port: 8080
```

### Mistake 3: No startup probe on slow-starting apps

**Symptom:** Pod killed and restarted during initial load.

If your app takes 60 seconds to initialize but your liveness probe has `initialDelaySeconds: 10`, the liveness probe will fire before the app is ready, fail, and restart the pod. The pod restarts, starts loading again, and gets killed again. Infinite loop.

**Fix:** Add a startup probe with generous timing. Liveness doesn't start until startup passes.

### Mistake 4: Missing readiness probe during rolling updates

**Symptom:** 503 errors during deployments.

Without a readiness probe, Kubernetes marks a pod as Ready the instant the container starts. During a rolling update, K8s sees the new pod as "Ready," removes an old pod, and routes traffic to the new pod — which hasn't finished loading yet. Users see errors.

---

## Designing Your Probe Strategy

For a typical web application:

```yaml
startupProbe:          # "Are you done booting?"
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30
  periodSeconds: 10    # Up to 5 minutes to start

readinessProbe:        # "Can you handle traffic right now?"
  httpGet:
    path: /readyz
    port: 8080
  periodSeconds: 5
  failureThreshold: 3

livenessProbe:         # "Are you still alive?"
  httpGet:
    path: /livez
    port: 8080
  periodSeconds: 10
  failureThreshold: 5  # Be generous — don't kill pods for brief slowdowns
```

For a database:

```yaml
readinessProbe:
  exec:
    command: ["pg_isready", "-U", "postgres"]
  periodSeconds: 5

livenessProbe:
  tcpSocket:
    port: 5432
  periodSeconds: 10
  failureThreshold: 5
```

For a background worker (no HTTP, no ports):

```yaml
livenessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - "test -f /tmp/worker-alive"
  periodSeconds: 30
  failureThreshold: 3
```

The worker touches `/tmp/worker-alive` on each successful work cycle. If the file gets stale, the probe fails.

---

## Quick Reference

```bash
# See probe configuration on a deployment
kubectl get deployment <name> -n <namespace> -o yaml | grep -A 10 "Probe"

# Watch pod readiness changes
kubectl get pods -n <namespace> -w

# Check endpoints (pods that pass readiness)
kubectl get endpoints <service-name> -n <namespace>

# See probe failures in events
kubectl describe pod <pod-name> -n <namespace>
# Look for: Readiness probe failed, Liveness probe failed, Startup probe failed
```

---

> **Sarah:** "Every production outage I've debugged that involved 'but the pods were Running' turned out to be a missing readiness probe. Every single one. Add the probe. Check the endpoints. Trust the probe, not the status."

**Next:** [Deployment Strategies](02-deployment-strategies.md)
