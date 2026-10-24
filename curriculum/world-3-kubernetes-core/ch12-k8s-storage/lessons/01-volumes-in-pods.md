# Lesson 1: Volumes in Pods

## The Storage Problem

By default, a container's filesystem is **ephemeral** — it exists only as long as the container runs. When a container restarts (even within the same Pod), its filesystem is reset to the image's original state.

In Docker, you learned about volumes and bind mounts. Kubernetes has its own volume system, with more types and more control. Let's start with the simplest ones.

---

## emptyDir: Temporary Shared Storage

An `emptyDir` volume is created when a Pod is assigned to a node, and it exists as long as the Pod runs on that node. When the Pod is deleted, the emptyDir data is **permanently deleted**.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: learn-emptydir-demo
  namespace: learn-ch12
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo 'Hello from writer' > /shared/message.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /shared
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "sleep 5 && cat /shared/message.txt && sleep 3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /shared
  volumes:
    - name: shared-data
      emptyDir: {}
```

Both containers mount the same volume at `/shared`. The writer creates a file; the reader sees it. This is how sidecar patterns share data — a web server writes logs to a volume, and a log shipper reads from it.

**Key behaviors:**
- Created when Pod starts, deleted when Pod dies
- Shared between all containers in the same Pod
- Data does NOT survive Pod deletion or restart
- Stored on the node's filesystem (or tmpfs with `emptyDir: {medium: Memory}`)

### When to Use emptyDir

| Use Case | Why |
|----------|-----|
| Sidecar patterns (log shipping, config generation) | Containers need shared filesystem |
| Scratch space for computations | Temporary data that doesn't need to persist |
| Cache that can be rebuilt | Fast storage that's OK to lose |

---

## hostPath: The Escape Hatch

A `hostPath` volume mounts a file or directory from the **node's filesystem** into the Pod.

```yaml
volumes:
  - name: host-logs
    hostPath:
      path: /var/log
      type: Directory
```

**Warning:** `hostPath` is generally dangerous in production:
- **Not portable:** The data lives on a specific node. If the Pod moves to another node, the data isn't there.
- **Security risk:** Mounting host paths gives the container access to the node's filesystem.
- **No lifecycle management:** Kubernetes doesn't manage the data — it's just a mount.

**Legitimate uses:**
- DaemonSets that need access to node-level data (log collectors reading `/var/log`)
- DaemonSets that need to access the container runtime socket
- Development and debugging only

For persistent data, always use PersistentVolumeClaims (Lesson 2).

---

## ConfigMap Volumes

A **ConfigMap** stores configuration data as key-value pairs. You can mount a ConfigMap as a volume — each key becomes a file, and its value becomes the file content.

### Creating a ConfigMap

```bash
# From literal values
kubectl create configmap learn-app-config \
  --from-literal=DATABASE_HOST=learn-db.learn-ch12.svc.cluster.local \
  --from-literal=DATABASE_PORT=5432 \
  --from-literal=LOG_LEVEL=info \
  -n learn-ch12

# From a file
kubectl create configmap learn-nginx-config \
  --from-file=nginx.conf \
  -n learn-ch12
```

Or as YAML:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: learn-app-config
  namespace: learn-ch12
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch12
data:
  DATABASE_HOST: "learn-db.learn-ch12.svc.cluster.local"
  DATABASE_PORT: "5432"
  LOG_LEVEL: "info"
  app.properties: |
    spring.datasource.url=jdbc:postgresql://learn-db:5432/nocappuccino
    spring.cache.enabled=true
```

### Mounting as a Volume

```yaml
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /config/DATABASE_HOST && sleep 3600"]
      volumeMounts:
        - name: config-volume
          mountPath: /config
          readOnly: true
  volumes:
    - name: config-volume
      configMap:
        name: learn-app-config
```

Inside the container, `/config/` contains:
```
/config/DATABASE_HOST          → "learn-db.learn-ch12.svc.cluster.local"
/config/DATABASE_PORT          → "5432"
/config/LOG_LEVEL              → "info"
/config/app.properties         → (the multi-line content)
```

### Using as Environment Variables

You can also inject ConfigMap data as environment variables (not a volume):

```yaml
spec:
  containers:
    - name: app
      env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: learn-app-config
              key: DATABASE_HOST
```

Or inject all keys at once:

```yaml
spec:
  containers:
    - name: app
      envFrom:
        - configMapRef:
            name: learn-app-config
```

### ConfigMap Updates and Propagation

When you update a ConfigMap, the change propagates to Pods that mount it as a volume:
- **Volume mounts:** Updated automatically (within ~60 seconds). The kubelet periodically syncs mounted ConfigMaps.
- **Environment variables:** NOT updated. The env vars are set at container start and don't change until the Pod is restarted.

This is an important distinction. If your app reads config from files (volume mount), it can pick up changes without restart. If it reads from environment variables, you need to restart the Pod.

---

## Secret Volumes

**Secrets** are like ConfigMaps but designed for sensitive data (passwords, API keys, TLS certificates). They work almost identically to ConfigMaps but with these differences:

1. Secret data is **base64 encoded** (not encrypted by default)
2. Secrets are stored in etcd (encrypted at rest if configured)
3. Access can be restricted via RBAC
4. Kubernetes limits Secret exposure to nodes that need them

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: learn-db-credentials
  namespace: learn-ch12
type: Opaque
data:
  username: bm9jYXBwdWNjaW5v          # base64 of "nocappuccino"
  password: c3VwZXJzZWNyZXQxMjM=      # base64 of "supersecret123"
```

```bash
# Create from literals (kubectl handles base64 encoding)
kubectl create secret generic learn-db-credentials \
  --from-literal=username=nocappuccino \
  --from-literal=password=supersecret123 \
  -n learn-ch12
```

### Mounting as a Volume

```yaml
volumeMounts:
  - name: db-creds
    mountPath: /secrets
    readOnly: true
volumes:
  - name: db-creds
    secret:
      secretName: learn-db-credentials
```

Inside the container:
```
/secrets/username → "nocappuccino"     (decoded automatically)
/secrets/password → "supersecret123"   (decoded automatically)
```

When mounted as volumes, Secrets are **automatically decoded** from base64. The container sees plain text.

---

## Volume Types Summary

| Type | Lifecycle | Use Case |
|------|-----------|----------|
| `emptyDir` | Dies with the Pod | Temp scratch space, sidecar sharing |
| `hostPath` | Lives on the node | DaemonSets accessing node data (⚠️ dangerous) |
| `configMap` | Managed separately | Application configuration |
| `secret` | Managed separately | Credentials, keys, certificates |
| `persistentVolumeClaim` | Managed separately | Persistent data (databases, file storage) |

---

## Summary

| Concept | What it is |
|---------|-----------|
| emptyDir | Temporary volume; shared between containers in a Pod; deleted when Pod dies |
| hostPath | Mounts node filesystem into Pod; not portable; security risk |
| ConfigMap | Key-value config data; mountable as files or injectable as env vars |
| Secret | Like ConfigMap but for sensitive data; base64 encoded |
| Volume mount propagation | ConfigMap volumes update automatically; env vars require Pod restart |
| readOnly | Best practice: mount config and secrets as read-only |

---

Up next: [Lesson 2 — Persistent Volumes](02-persistent-volumes.md)

emptyDir, ConfigMaps, and Secrets are useful, but none of them solve the real problem: data that survives Pod deletion. For that, you need PersistentVolumes.
