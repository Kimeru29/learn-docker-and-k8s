# Challenge 2: Harden Pods

> **Sarah:** "The security audit flagged every pod in the cluster: running as root, all capabilities enabled, writable root filesystem. If an attacker gets shell access, they can install tools, modify binaries, and escalate privileges. We need to harden these pods without breaking the application."

---

## The Situation

The `learn-web` Deployment in namespace `learn-ch15` is running with no security context. The container:
- Runs as root (UID 0)
- Has all default Linux capabilities
- Has a writable root filesystem
- Allows privilege escalation

Your job: apply a security context that hardens the pod while keeping the application functional.

---

## Setup

```bash
kubectl create namespace learn-ch15 2>/dev/null || true
```

Save the following as `insecure-web.yaml` and apply it:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-web
  namespace: learn-ch15
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch15
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-web
  template:
    metadata:
      labels:
        app: learn-web
        world: w04
        chapter: ch15
    spec:
      containers:
        - name: nginx
          image: nginxinc/nginx-unprivileged:1.25
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
          # No security context — running with defaults
---
apiVersion: v1
kind: Service
metadata:
  name: learn-web
  namespace: learn-ch15
spec:
  selector:
    app: learn-web
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

```bash
kubectl apply -f insecure-web.yaml
```

Verify the pod is running and check the current security state:

```bash
# Check the user the container is running as
kubectl exec -it deploy/learn-web -n learn-ch15 -- id

# Check if the filesystem is writable
kubectl exec -it deploy/learn-web -n learn-ch15 -- touch /tmp/test-write

# Check if the pod is functional
kubectl port-forward service/learn-web 8092:80 -n learn-ch15 &
curl -s http://localhost:8092
kill %1 2>/dev/null
```

---

## Your Mission

Modify the `learn-web` Deployment to apply these security hardening measures:

1. **`runAsNonRoot: true`** — Ensure the container does not run as root
2. **`runAsUser: 101`** — Run as the nginx user (UID 101 in the `nginxinc/nginx-unprivileged` image)
3. **`readOnlyRootFilesystem: true`** — Make the root filesystem read-only
4. **`allowPrivilegeEscalation: false`** — Prevent privilege escalation
5. **`capabilities: drop: [ALL]`** — Drop all Linux capabilities

**The app must still function** after applying these changes. nginx needs to write to certain directories (`/tmp`, `/var/cache/nginx`), so you'll need to mount writable `emptyDir` volumes for those paths.

---

## Success Criteria

- The pod is `Running` and `Ready 1/1`
- `kubectl exec -- id` shows a non-root user (UID != 0)
- `kubectl exec -- touch /test-file` fails with "Read-only file system"
- The Service still returns an HTTP response (the app works)
- The Deployment spec includes all five security settings

---

## Hints

<details>
<summary>Hint 1: The security context</summary>

Add the security context at the container level:

```yaml
containers:
  - name: nginx
    securityContext:
      runAsNonRoot: true
      runAsUser: 101
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
```

</details>

<details>
<summary>Hint 2: nginx needs writable directories</summary>

With a read-only root filesystem, nginx can't write to `/tmp` or `/var/cache/nginx`. Mount `emptyDir` volumes for these paths:

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /var/cache/nginx
  - name: run
    mountPath: /var/run
```

And in the pod spec:

```yaml
volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

The `nginxinc/nginx-unprivileged` image is designed to run as non-root and listens on port 8080 instead of 80.

</details>

<details>
<summary>Hint 3: Verifying the hardened pod</summary>

After applying the changes:

```bash
# Verify non-root
kubectl exec deploy/learn-web -n learn-ch15 -- id
# Should show uid=101(nginx)

# Verify read-only filesystem
kubectl exec deploy/learn-web -n learn-ch15 -- touch /test-file
# Should fail: "Read-only file system"

# Verify /tmp is writable (emptyDir mount)
kubectl exec deploy/learn-web -n learn-ch15 -- touch /tmp/test-file
# Should succeed

# Verify the app still works
kubectl port-forward service/learn-web 8092:80 -n learn-ch15 &
curl -s http://localhost:8092
kill %1 2>/dev/null
```

</details>

---

## Verification

```bash
bash curriculum/world-4-kubernetes-production/ch15-k8s-security/challenges/verify.sh
```

---

> **Sarah:** "Non-root, read-only filesystem, no capabilities. The app still works perfectly — it never needed root in the first place. That's the thing about security hardening: most of the time, you're removing permissions the app never used."

**Next:** [Challenge 03 — Secret Hygiene](03-secret-hygiene.md)
