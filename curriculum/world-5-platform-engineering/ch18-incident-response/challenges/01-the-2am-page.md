# Challenge 1: The 2 AM Page

> **Sarah:** "The pager just went off. Multiple alerts. Take a breath, follow the process, and work through it systematically."

---

## The Situation

It's 2:14 AM. Three alerts fire simultaneously:

1. 🔴 **Error rate above 5%** on the `learn-api` service
2. 🔴 **p99 latency above 10 seconds** on the `learn-api` service
3. 🟡 **Pod restarts above 5 in 10 minutes** on `learn-worker`

Multiple symptoms. One underlying cause. Your job: triage, mitigate, investigate, and resolve.

---

## Setup

### Create the Namespace and Deploy the Broken State

```bash
kubectl create namespace learn-ch18
kubectl label namespace learn-ch18 app=learn-docker-k8s world=w05 chapter=ch18
```

Save the following as `incident-state.yaml` and apply it:

```yaml
# ============================================================
# The API — deployed with a bad image tag (simulates bad deploy)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-ch18
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch18
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-api
  template:
    metadata:
      labels:
        app: learn-api
        world: w05
        chapter: ch18
    spec:
      containers:
        - name: api
          image: nginx:1.25-nonexistent
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-api
  namespace: learn-ch18
spec:
  selector:
    app: learn-api
  ports:
    - port: 80
      targetPort: 80
---
# ============================================================
# The Worker — runs but with insufficient memory (OOMKilled)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-worker
  namespace: learn-ch18
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch18
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-worker
  template:
    metadata:
      labels:
        app: learn-worker
        world: w05
        chapter: ch18
    spec:
      containers:
        - name: worker
          image: nginx:1.25
          resources:
            requests:
              memory: "4Mi"
              cpu: "50m"
            limits:
              memory: "6Mi"
              cpu: "100m"
---
# ============================================================
# A ConfigMap with deployment metadata (for investigation)
# ============================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: learn-deploy-history
  namespace: learn-ch18
data:
  last_deploy: "v1.5.0 at 02:00 UTC"
  previous_version: "v1.4.2 (nginx:1.25-alpine)"
  deployer: "ci-pipeline"
  change_description: "Updated API image to v1.5.0, increased worker concurrency"
```

```bash
kubectl apply -f incident-state.yaml
```

Wait a moment for the problems to manifest:

```bash
kubectl get pods -n learn-ch18 -w
```

---

## Your Mission

Follow the incident response process from Lesson 01.

### Phase 1: Triage (5 minutes)

1. **Acknowledge** — you're on it.
2. **Assess impact:**
   ```bash
   kubectl get pods -n learn-ch18
   kubectl get events -n learn-ch18 --sort-by='.lastTimestamp' | tail -20
   ```
3. **Classify severity:** Based on what you see, is this SEV1, SEV2, or SEV3?
4. **Identify blast radius:** Which services are affected?

### Phase 2: Mitigate (10 minutes)

Fix the immediate problems. Don't investigate root cause yet — just stop the bleeding.

**Problem 1: learn-api pods** — They're not running. Diagnose:
```bash
kubectl describe pod -l app=learn-api -n learn-ch18 | tail -20
```

The image is bad. The deploy metadata says the previous version was `nginx:1.25-alpine`. Roll back:
```bash
kubectl set image deployment/learn-api api=nginx:1.25-alpine -n learn-ch18
```

**Problem 2: learn-worker pods** — They're restarting. Diagnose:
```bash
kubectl describe pod -l app=learn-worker -n learn-ch18 | grep -A 5 "Last State"
```

OOMKilled. The memory limit is too low. Fix:
```bash
kubectl patch deployment learn-worker -n learn-ch18 \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"128Mi"},{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"64Mi"}]'
```

### Phase 3: Verify Recovery (5 minutes)

```bash
kubectl get pods -n learn-ch18
# All pods should be Running with 0 restarts (or low restart count)
```

### Phase 4: Document the Incident

Create a ConfigMap with your incident report:

```bash
kubectl create configmap learn-incident-report \
  --from-literal=severity="SEV2" \
  --from-literal=impact="API unavailable (ImagePullBackOff), worker unstable (OOMKilled)" \
  --from-literal=blast_radius="learn-api and learn-worker affected, both services down" \
  --from-literal=root_cause="Bad image tag in v1.5.0 deployment (nginx:1.25-nonexistent), and insufficient memory limits for worker after concurrency increase" \
  --from-literal=mitigation="Rolled back API image to nginx:1.25-alpine, increased worker memory limits to 128Mi" \
  --from-literal=duration_minutes="15" \
  -n learn-ch18
```

---

## Success Criteria

- [ ] All pods in `learn-ch18` are Running with READY status
- [ ] No pods in ImagePullBackOff or CrashLoopBackOff
- [ ] `learn-api` is running with a valid image (not `nginx:1.25-nonexistent`)
- [ ] `learn-worker` has memory limits ≥ 32Mi
- [ ] ConfigMap `learn-incident-report` exists with severity, impact, root_cause, and mitigation

---

## Hints

<details>
<summary>Hint 1: How to identify the API problem</summary>

```bash
kubectl describe pod -l app=learn-api -n learn-ch18
```

Look at the Events section. You'll see `Failed to pull image "nginx:1.25-nonexistent"`. The image tag doesn't exist.

Check the deployment metadata:

```bash
kubectl get configmap learn-deploy-history -n learn-ch18 -o yaml
```

It tells you the previous version was `nginx:1.25-alpine`. Roll back to that.

</details>

<details>
<summary>Hint 2: How to identify the Worker problem</summary>

```bash
kubectl describe pod -l app=learn-worker -n learn-ch18
```

Look for `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`. The memory limit (6Mi) is far too low for nginx.

Increase it:

```bash
kubectl set resources deployment/learn-worker \
  --limits=memory=128Mi,cpu=100m \
  --requests=memory=64Mi,cpu=50m \
  -n learn-ch18
```

</details>

<details>
<summary>Hint 3: The incident report</summary>

The key insight: two problems, one root cause. Both were introduced by the "v1.5.0" deployment:
- API got a bad image tag
- Worker got insufficient memory limits (the "increased concurrency" required more memory)

The severity is SEV2 because both the API and worker were down, but it's not SEV1 because we have a clear rollback path.

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch18-incident-response/challenges/verify.sh
```

---

> **Sarah:** "Notice what you did: triage first, mitigate second, investigate third, document fourth. That's the process. You didn't panic. You didn't spend 30 minutes reading logs before fixing anything. You stopped the bleeding, then figured out why it bled."

**Next:** [Challenge 02 — Cascading Failure](02-cascading-failure.md)
