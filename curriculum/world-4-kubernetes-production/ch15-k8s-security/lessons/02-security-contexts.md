# Lesson 2: Security Contexts

> **Sarah:** "Every pod in our cluster runs as root. Root inside a container is still root on the host if there's a container escape. And with all capabilities enabled, a compromised container can do almost anything the kernel allows. Let's lock this down."

---

## Why Running as Root Is Dangerous

When a container runs as root (UID 0), the process inside has the same user ID as the root user on the host. Container isolation (namespaces, cgroups) provides boundaries, but these boundaries are not absolute:

- Kernel vulnerabilities can allow container escapes
- Misconfigured volume mounts can expose host paths
- Capabilities like `CAP_SYS_ADMIN` can be used to break out of the container

Running as a non-root user reduces the blast radius. Even if the container is compromised, the attacker has limited permissions.

---

## Pod Security Context

Security context settings can be applied at the **pod level** (affects all containers) or the **container level** (overrides pod-level settings for a specific container).

### Pod-level settings

```yaml
spec:
  securityContext:
    runAsNonRoot: true           # Fail if any container tries to run as root
    runAsUser: 1000              # Run all containers as UID 1000
    runAsGroup: 1000             # Primary group GID 1000
    fsGroup: 2000                # Volumes are owned by GID 2000
    seccompProfile:
      type: RuntimeDefault       # Use the runtime's default seccomp profile
```

### Container-level settings

```yaml
containers:
  - name: api
    image: learn-api:v1.0
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE     # Only if the app needs to bind to ports < 1024
```

---

## Key Settings Explained

### runAsNonRoot

```yaml
securityContext:
  runAsNonRoot: true
```

Kubernetes rejects the pod if the container image is configured to run as root (UID 0). This is a safety check — it doesn't change the user, it just prevents running if the user would be root.

**If the image's default user is root,** you must also set `runAsUser` to a non-root UID, or the pod will fail to start with `Error: container has runAsNonRoot and image will run as root`.

### runAsUser / runAsGroup

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
```

The process runs as UID 1000, GID 1000 — regardless of what the Dockerfile's `USER` instruction says. This overrides the image's default.

### readOnlyRootFilesystem

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

The container's root filesystem becomes read-only. The app cannot write to `/tmp`, `/var/log`, or any path unless an explicit volume is mounted there.

**Why this matters:** If an attacker compromises the container, they can't write malware to the filesystem, modify binaries, or create new scripts.

**Common pattern:** Mount writable volumes where the app actually needs to write:

```yaml
securityContext:
  readOnlyRootFilesystem: true
volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /var/cache/nginx
volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
```

### allowPrivilegeEscalation

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

Prevents the process from gaining more privileges than its parent (via `setuid`, `setgid`, or other mechanisms). Always set to `false` for application containers.

### fsGroup

```yaml
spec:
  securityContext:
    fsGroup: 2000
```

All volumes mounted in the pod are owned by GID 2000. This ensures the non-root user can read and write to mounted volumes. Without `fsGroup`, volume files may have root ownership and be inaccessible to a non-root container.

---

## Linux Capabilities

Linux capabilities are fine-grained privileges that break the traditional "root can do anything" model into specific permissions.

### The problem

By default, containers get a set of capabilities including:
- `CAP_CHOWN` — change file ownership
- `CAP_DAC_OVERRIDE` — bypass file permission checks
- `CAP_FOWNER` — bypass ownership checks
- `CAP_NET_RAW` — use raw sockets (needed for `ping`, but also useful for network attacks)
- `CAP_SETUID` / `CAP_SETGID` — change user/group IDs

Most applications need none of these.

### The fix: drop ALL, add specific

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE   # Only if binding to port < 1024
```

`drop: ALL` removes every capability. Then `add` selectively re-enables only what the app actually needs. Most web applications need zero capabilities.

### Common capabilities

| Capability | What it allows | When you need it |
|-----------|----------------|-----------------|
| `NET_BIND_SERVICE` | Bind to ports below 1024 | Web servers on port 80/443 (use high ports instead when possible) |
| `SYS_PTRACE` | Trace/debug other processes | Debugging containers (never in production) |
| `NET_RAW` | Raw network sockets | `ping`, some network tools (rarely needed) |

---

## Pod Security Standards

Kubernetes defines three levels of pod security via **Pod Security Standards (PSS)**, enforced by the **Pod Security Admission** controller.

### Privileged

No restrictions. The pod can do anything. Used for system-level workloads (CNI plugins, storage drivers, monitoring agents that need host access).

### Baseline

Prevents known privilege escalations. Blocks:
- Privileged containers
- Host namespaces (hostNetwork, hostPID, hostIPC)
- Dangerous capabilities
- HostPath volumes

A reasonable default for general workloads.

### Restricted

Most hardened. Requires:
- Non-root user
- Drop ALL capabilities
- Read-only root filesystem
- No privilege escalation
- Seccomp profile set

This is the target for application pods.

### Enforcing Pod Security Standards

Applied at the namespace level via labels:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: learn-ch15
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

| Mode | Behavior |
|------|----------|
| `enforce` | Reject pods that violate the policy |
| `audit` | Allow pods but log violations |
| `warn` | Allow pods but show a warning |

**Typical rollout:** Start with `warn` to see what would break, move to `audit` to track violations, then `enforce` once all workloads comply.

---

## A Production-Hardened Pod

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-ch15
spec:
  template:
    spec:
      serviceAccountName: api-sa
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: api
          image: learn-api:v1.0
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

This pod:
- Runs as non-root (UID 1000)
- Has a read-only filesystem (with `/tmp` writable via emptyDir)
- Drops all Linux capabilities
- Prevents privilege escalation
- Uses a seccomp profile
- Doesn't mount the ServiceAccount token
- Uses a dedicated ServiceAccount

---

## Quick Reference

```bash
# Check what user a pod is running as
kubectl exec <pod> -n <namespace> -- id

# Check capabilities
kubectl exec <pod> -n <namespace> -- cat /proc/1/status | grep -i cap

# Check if root filesystem is read-only
kubectl exec <pod> -n <namespace> -- touch /test-write
# Should fail with "Read-only file system" if readOnlyRootFilesystem: true

# See security context on a deployment
kubectl get deployment <name> -n <namespace> -o yaml | grep -A 15 securityContext
```

---

> **Sarah:** "Non-root, drop all capabilities, read-only filesystem. Three lines of YAML. They cost nothing to apply and they shrink the attack surface dramatically. There is no good reason to run an application container as root."

**Next:** [Secrets Management](03-secrets-management.md)
