# Challenge 2: Cascading Failure

> **Sarah:** "The database hiccupped. Then the API started timing out. Then the frontend started showing errors. Then the load balancer started health-checking failures. One domino knocked over three more. Welcome to cascading failures."

---

## The Situation

A failure in one service has spread to others:

```
  ┌──────────┐     ┌──────────┐     ┌──────────┐
  │ Frontend │────→│   API    │────→│ Database │
  │  learn-  │     │  learn-  │     │  learn-  │
  │ frontend │     │ backend  │     │   db     │
  └──────────┘     └──────────┘     └──────────┘
       │                │                │
       │ ⚠ Shows       │ ⚠ Times out   │ 💥 Source of
       │   errors      │   waiting     │    the problem
       │   to users    │   for DB      │
```

The database is the source. The API hangs waiting for it. The frontend hangs waiting for the API. All three appear broken, but only one has the actual problem.

---

## Setup

Save the following as `cascade-state.yaml` and apply it:

```yaml
# ============================================================
# The Database — broken (wrong image, simulates DB crash)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-db
  namespace: learn-ch18
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch18
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: learn-db
  template:
    metadata:
      labels:
        app: learn-db
        tier: database
        chapter: ch18
    spec:
      containers:
        - name: db
          image: postgres:16-alpine-nonexistent
          ports:
            - containerPort: 5432
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-db
  namespace: learn-ch18
spec:
  selector:
    app: learn-db
  ports:
    - port: 5432
      targetPort: 5432
---
# ============================================================
# The API Backend — "healthy" but depends on learn-db
# It's running but its endpoints would timeout waiting for DB
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-backend
  namespace: learn-ch18
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch18
    tier: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-backend
  template:
    metadata:
      labels:
        app: learn-backend
        tier: api
        chapter: ch18
    spec:
      containers:
        - name: backend
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
          env:
            - name: DB_HOST
              value: "learn-db"
            - name: DB_PORT
              value: "5432"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-backend
  namespace: learn-ch18
spec:
  selector:
    app: learn-backend
  ports:
    - port: 80
      targetPort: 80
---
# ============================================================
# The Frontend — "healthy" but depends on learn-backend
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch18
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch18
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-frontend
  template:
    metadata:
      labels:
        app: learn-frontend
        tier: frontend
        chapter: ch18
    spec:
      containers:
        - name: frontend
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
          env:
            - name: API_URL
              value: "http://learn-backend"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-frontend
  namespace: learn-ch18
spec:
  selector:
    app: learn-frontend
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f cascade-state.yaml
```

---

## Your Mission

### Part 1: Identify the Cascade

Check all three tiers:

```bash
# Overview of all pods
kubectl get pods -n learn-ch18 -l chapter=ch18 --show-labels

# Check each tier
kubectl get pods -n learn-ch18 -l tier=database
kubectl get pods -n learn-ch18 -l tier=api
kubectl get pods -n learn-ch18 -l tier=frontend
```

Questions to answer:
- Which tier has the actual problem?
- Which tiers appear healthy but would be affected?
- What's the dependency chain?

### Part 2: Stop the Bleeding at the Source

Fix the root cause — the database. The broken image needs to be replaced with a working one:

```bash
kubectl set image deployment/learn-db db=postgres:16-alpine -n learn-ch18
```

Wait for the database pod to be Running:

```bash
kubectl get pods -n learn-ch18 -l tier=database -w
```

### Part 3: Verify the Cascade Resolved

Once the source is fixed, check if downstream services recovered:

```bash
kubectl get pods -n learn-ch18 -l chapter=ch18
```

All pods across all three tiers should be Running.

### Part 4: Implement Backpressure

Create a ConfigMap documenting what backpressure measures should be in place to prevent this cascade in the future:

```bash
kubectl create configmap learn-cascade-analysis \
  --from-literal=source_of_failure="learn-db (database tier)" \
  --from-literal=cascade_path="learn-db -> learn-backend -> learn-frontend" \
  --from-literal=fix_applied="Replaced broken database image with postgres:16-alpine" \
  --from-literal=backpressure_recommendation="API should implement connection timeouts and circuit breaker for database calls. Frontend should implement timeout and fallback response when API is unavailable. Health probes should check dependency health, not just process liveness." \
  -n learn-ch18
```

---

## Success Criteria

- [ ] `learn-db` pod is Running with a valid image (not `nonexistent`)
- [ ] `learn-backend` pods are all Running (3/3)
- [ ] `learn-frontend` pods are all Running (2/2)
- [ ] ConfigMap `learn-cascade-analysis` exists with cascade path and backpressure recommendations
- [ ] No pods in ImagePullBackOff, CrashLoopBackOff, or Error state

---

## Hints

<details>
<summary>Hint 1: Finding the source</summary>

```bash
# Check which pods are NOT healthy
kubectl get pods -n learn-ch18 -l chapter=ch18 | grep -v Running
```

The database tier will show the broken pod. The API and frontend tiers may look healthy (Running) but would functionally fail because their dependency (the database) is down.

This is the challenge of cascading failures: upstream services look "healthy" by infrastructure metrics (pod is running, memory is fine) but are functionally broken because their dependency is dead.

</details>

<details>
<summary>Hint 2: Why fix the source, not the symptoms?</summary>

You could restart the backend pods. They'd come back up and... immediately fail again because the database is still down.

In a cascade, always fix the root source first. Then verify downstream services recover. If they don't recover automatically, work your way up the chain.

</details>

<details>
<summary>Hint 3: What is backpressure?</summary>

Backpressure is when a service stops accepting or propagating requests when it's overwhelmed. Examples:

- **Connection timeout:** API stops waiting for database after 5 seconds instead of hanging forever
- **Circuit breaker:** After 3 database failures, stop trying for 30 seconds
- **Fallback response:** Frontend shows cached content instead of erroring when API is down
- **Health probe dependency check:** API readiness probe fails if database is unreachable, removing it from the Service's endpoint list

Without backpressure, one failure cascades through every service that depends on it.

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch18-incident-response/challenges/verify.sh
```

---

## Reflection

Cascading failures are the most common pattern in distributed system outages:

1. A leaf service fails (database, cache, external API)
2. Services that depend on it start timing out (hanging, not crashing)
3. Services that depend on THOSE services also start timing out
4. The entire system appears broken, even though only one component actually failed

The fix is always the same: **find the source, fix it there, and verify downstream recovery.** The prevention is backpressure: timeouts, circuit breakers, and graceful degradation.

---

> **Sarah:** "Every cascading failure I've ever seen followed the same pattern: something at the bottom died, everything above it hung waiting, and the on-call engineer started debugging the frontend because that's where the user complaints were. Always start at the bottom of the dependency chain."

**Next:** [Challenge 03 — Write the Postmortem](03-write-the-postmortem.md)
