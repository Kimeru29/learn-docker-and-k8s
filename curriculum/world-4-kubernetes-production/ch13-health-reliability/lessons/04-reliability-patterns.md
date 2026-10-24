# Lesson 4: Reliability Patterns

> **Sarah:** "Sometimes one container isn't enough. Your API needs a database migration to run before it starts. Your app needs a log shipper running alongside it. The worker needs to wait for a config file to be generated. Kubernetes has patterns for all of these — and they all live inside the same pod."

---

## Init Containers

An init container runs **to completion** before the main containers start. If the init container fails, Kubernetes retries it (subject to restart policy). The main containers never start until all init containers succeed.

### Why they exist

Init containers handle setup tasks that must complete before the app can run:
- Wait for a dependency to be available
- Run a database migration
- Download configuration from a remote source
- Set filesystem permissions
- Generate certificates

### How they work

```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command:
        - /bin/sh
        - -c
        - |
          echo "Waiting for database..."
          until nc -z postgres-service 5432; do
            echo "Database not ready, retrying in 2s..."
            sleep 2
          done
          echo "Database is ready!"
  containers:
    - name: api
      image: learn-api:v1.0
```

The `wait-for-db` init container loops until it can reach PostgreSQL on port 5432. Only then does the `api` container start.

### Multiple init containers

Init containers run **sequentially**, in the order they're defined:

```yaml
initContainers:
  - name: wait-for-db        # Runs first
    image: busybox:1.36
    command: [...]

  - name: run-migrations      # Runs second (only after wait-for-db succeeds)
    image: learn-api:v1.0
    command: ["./migrate", "up"]

  - name: seed-cache          # Runs third
    image: learn-api:v1.0
    command: ["./seed-cache"]
```

### Init containers vs startup probes

Both deal with slow initialization, but differently:

| | Init container | Startup probe |
|---|---|---|
| Runs separate process | Yes (different image possible) | No (checks the main container) |
| Can access shared volumes | Yes | N/A |
| Blocks main container start | Yes | No (main container is running, probe gates liveness/readiness) |
| Use case | Setup that must happen before the app | App that takes a long time to become ready |

**Use init containers** when you need to run a different process or command before the main app.  
**Use startup probes** when the main app itself is slow to start.

---

## Sidecar Containers

A sidecar runs **alongside** the main container in the same pod, for the lifetime of the pod. Both containers share the same network namespace (localhost), filesystem (via shared volumes), and lifecycle.

### Common sidecar patterns

**Log shipping:**
```yaml
spec:
  containers:
    - name: api
      image: learn-api:v1.0
      volumeMounts:
        - name: logs
          mountPath: /var/log/app

    - name: log-shipper
      image: fluent-bit:2.1
      volumeMounts:
        - name: logs
          mountPath: /var/log/app
          readOnly: true
  volumes:
    - name: logs
      emptyDir: {}
```

The `api` writes logs to `/var/log/app`. The `log-shipper` reads them and forwards to a centralized logging system. Both containers share the `logs` volume.

**Reverse proxy / TLS termination:**
```yaml
containers:
  - name: api
    image: learn-api:v1.0
    ports:
      - containerPort: 8080   # Plain HTTP

  - name: envoy
    image: envoyproxy/envoy:v1.28
    ports:
      - containerPort: 8443   # HTTPS
    # Envoy terminates TLS and proxies to localhost:8080
```

**Config reloader:**
```yaml
containers:
  - name: api
    image: learn-api:v1.0
    volumeMounts:
      - name: config
        mountPath: /etc/config

  - name: config-reloader
    image: configmap-reload:v0.9
    args: ["--watched-dir=/etc/config", "--webhook-url=http://localhost:8080/reload"]
    volumeMounts:
      - name: config
        mountPath: /etc/config
        readOnly: true
```

The `config-reloader` watches for ConfigMap changes and sends a webhook to the main app to reload.

### Kubernetes 1.28+ Native Sidecar Containers

Starting in Kubernetes 1.28, you can define sidecars as init containers with `restartPolicy: Always`:

```yaml
initContainers:
  - name: log-shipper
    image: fluent-bit:2.1
    restartPolicy: Always   # Makes this a native sidecar
    volumeMounts:
      - name: logs
        mountPath: /var/log/app
```

Native sidecars:
- Start before the main containers (like init containers)
- Run for the lifetime of the pod (like regular containers)
- Are terminated **after** the main containers during shutdown
- Are properly accounted for in pod status

This solves the long-standing problem where sidecar containers (defined as regular containers) might exit before the main container was done flushing logs during shutdown.

---

## Lifecycle Hooks

Every container supports two lifecycle hooks: `postStart` and `preStop`.

### postStart

Runs immediately after the container is created. Note: it runs **asynchronously** with the container's entrypoint — there's no guarantee it completes before the main process starts.

```yaml
lifecycle:
  postStart:
    exec:
      command:
        - /bin/sh
        - -c
        - "echo 'Container started at $(date)' >> /var/log/lifecycle.log"
```

**Common uses:**
- Registering with a service discovery system
- Sending a notification that the pod started
- Warming up a cache

**Caution:** If postStart fails, the container is killed. Keep it simple and fast.

### preStop

Runs before SIGTERM is sent during termination. We covered this in detail in the previous lesson.

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 5 && /app/drain-connections"]
```

### Hook types

Both hooks support two mechanisms:

**exec:** Run a command inside the container
```yaml
lifecycle:
  postStart:
    exec:
      command: ["/bin/sh", "-c", "echo ready"]
```

**httpGet:** Send an HTTP request
```yaml
lifecycle:
  postStart:
    httpGet:
      path: /hooks/started
      port: 8080
```

---

## Multi-Container Pod Patterns

The Kubernetes documentation describes three canonical multi-container patterns. In practice, these are guidelines, not strict categories.

### Sidecar Pattern

A helper container that extends the main container's functionality without changing the main container's code.

```
  Pod
  ┌──────────────────────────┐
  │  ┌─────────┐ ┌─────────┐ │
  │  │  Main   │ │ Sidecar │ │
  │  │  App    │ │ Log     │ │
  │  │         │ │ Shipper │ │
  │  └─────────┘ └─────────┘ │
  │       shared volume       │
  └──────────────────────────┘
```

Examples: log shippers, monitoring agents, config reloaders, TLS proxies.

### Ambassador Pattern

A proxy container that simplifies outbound connections from the main container.

```
  Pod
  ┌──────────────────────────────┐
  │  ┌─────────┐ ┌────────────┐ │
  │  │  Main   │→│ Ambassador │→→→ External DB
  │  │  App    │ │ (proxy)    │→→→ External Cache
  │  │localhost │ │ localhost  │ │
  │  └─────────┘ └────────────┘ │
  └──────────────────────────────┘
```

The main app connects to `localhost:5432` and `localhost:6379`. The ambassador container routes those connections to the actual external services, handling authentication, connection pooling, and failover.

### Adapter Pattern

A container that transforms the main container's output into a standard format.

```
  Pod
  ┌──────────────────────────────┐
  │  ┌─────────┐ ┌────────────┐ │
  │  │  Main   │ │  Adapter   │──→ Prometheus
  │  │  App    │ │ (exporter) │ │  /metrics
  │  │ custom  │ │ standard   │ │
  │  │ metrics │ │ format     │ │
  │  └─────────┘ └────────────┘ │
  └──────────────────────────────┘
```

The main app emits metrics in a proprietary format. The adapter container reads them and exposes them as Prometheus-compatible metrics on `/metrics`.

---

## Shared Resources in Multi-Container Pods

Containers in the same pod share:

| Resource | How |
|----------|-----|
| **Network** | Same IP, same port space. Containers reach each other via `localhost` |
| **Volumes** | Shared via `emptyDir` or other volume types mounted in both containers |
| **Process namespace** | Optional: `shareProcessNamespace: true` lets containers see each other's processes |
| **IPC namespace** | Shared by default (System V IPC, POSIX message queues) |

They do NOT share:
- Filesystem (each container has its own root filesystem, unless mounted volumes overlap)
- Environment variables (each container has its own `env`)
- Resource limits (each container has its own `resources`)

---

## Practical Example: API with Migration and Log Shipping

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-ch13
spec:
  replicas: 3
  template:
    spec:
      initContainers:
        - name: run-migrations
          image: learn-api:v1.0
          command: ["./migrate", "up"]
          env:
            - name: DB_HOST
              value: "postgres-service"

      containers:
        - name: api
          image: learn-api:v1.0
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
          volumeMounts:
            - name: logs
              mountPath: /var/log/app
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 5"]

        - name: log-shipper
          image: fluent-bit:2.1
          volumeMounts:
            - name: logs
              mountPath: /var/log/app
              readOnly: true

      volumes:
        - name: logs
          emptyDir: {}
```

Flow:
1. `run-migrations` runs and applies database schema changes
2. Once it exits with code 0, the main containers start
3. `api` serves HTTP traffic and writes logs to `/var/log/app`
4. `log-shipper` reads those logs and forwards them to the logging backend
5. On shutdown, `api` gets a 5-second preStop sleep, then SIGTERM
6. `log-shipper` continues running briefly to flush remaining logs

---

## Quick Reference

```bash
# Check init container status
kubectl describe pod <name> -n <namespace>
# Look for: Init Containers section, State, Reason

# See logs from an init container
kubectl logs <pod-name> -c <init-container-name> -n <namespace>

# See logs from a sidecar
kubectl logs <pod-name> -c <sidecar-name> -n <namespace>

# Exec into a specific container in a multi-container pod
kubectl exec -it <pod-name> -c <container-name> -n <namespace> -- /bin/sh
```

---

> **Sarah:** "Init containers, sidecars, and lifecycle hooks are how you make pods production-ready without making your application code more complex. The app does its job. The infrastructure around it handles everything else."

**Now let's apply everything: [Challenge 01 — Probe Diagnosis](../challenges/01-probe-diagnosis.md)**
