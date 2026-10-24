# Challenge 2: Zero-Downtime Update

> **Sarah:** "A security patch just dropped for nginx. We need to update from 1.25 to 1.26 — right now, during business hours. The last time someone did this without a strategy, we had 30 seconds of downtime. This time, zero failed requests. That's the bar."

---

## The Situation

The `learn-frontend` Deployment is running `nginx:1.25` with 3 replicas in namespace `learn-ch13`. A continuous request loop will be running throughout the update. Every failed request is visible. The target: **zero failures**.

---

## Setup

Apply the starting Deployment (if you still have the namespace from Challenge 1, skip the create):

```bash
kubectl create namespace learn-ch13 2>/dev/null || true
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch13
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch13
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-frontend
  template:
    metadata:
      labels:
        app: learn-frontend
        world: w04
        chapter: ch13
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-frontend
  namespace: learn-ch13
spec:
  selector:
    app: learn-frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
EOF
```

Wait for the Deployment to be ready:

```bash
kubectl rollout status deployment/learn-frontend -n learn-ch13
```

---

## The Continuous Request Loop

Open a second terminal and start this loop. **Leave it running** throughout the entire challenge:

```bash
kubectl port-forward service/learn-frontend 8091:80 -n learn-ch13 &
PORT_FWD_PID=$!

echo "Port-forward PID: $PORT_FWD_PID"
echo "Starting request loop. Press Ctrl+C to stop."
echo ""

FAIL_COUNT=0
PASS_COUNT=0

while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8091 2>/dev/null)
  TIMESTAMP=$(date +%T)
  if [ "$STATUS" = "200" ]; then
    echo "[$TIMESTAMP] HTTP $STATUS OK"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[$TIMESTAMP] HTTP $STATUS FAIL <---"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  sleep 0.5
done
```

You should see a steady stream of `HTTP 200 OK`. That's your baseline.

When done, stop with `Ctrl+C`, then:

```bash
kill $PORT_FWD_PID 2>/dev/null
echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
```

---

## Your Mission

With the request loop running, update `learn-frontend` from `nginx:1.25` to `nginx:1.26`.

**Requirements:**

1. The Deployment must use a **rolling update strategy** with `maxSurge: 1` and `maxUnavailable: 0`
2. The Deployment must have a **readiness probe** (HTTP GET on port 80)
3. The image must be updated to `nginx:1.26`
4. The request loop must show **zero failures** during the update

**You choose the approach:** edit YAML and apply, or use `kubectl set image`. Both are valid.

---

## What to Watch

While the update runs, in your primary terminal:

```bash
# Watch pod transitions in real time
kubectl get pods -n learn-ch13 -l app=learn-frontend -w

# Check rollout progress
kubectl rollout status deployment/learn-frontend -n learn-ch13
```

You'll see new pods spin up, reach `1/1 Ready`, and old pods terminate. The request loop should show `200` the entire time.

---

## Bonus: Simulate a Bad Deploy and Roll Back

Once the zero-downtime update succeeds:

1. Trigger an update to a non-existent image: `nginx:9.99.99`
2. Watch the new pods fail (`ImagePullBackOff`)
3. Notice old pods stay running (because `maxUnavailable: 0`)
4. The request loop keeps returning `200`
5. Roll back with `kubectl rollout undo`
6. Confirm the old image is restored

This demonstrates why `maxUnavailable: 0` with readiness probes is so powerful — a bad deploy cannot take down the running service.

---

## Hints

<details>
<summary>Hint 1: Configuring the strategy and probe together</summary>

Both the rolling update strategy and the readiness probe go in the Deployment spec. You can update both at once:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
        - name: nginx
          readinessProbe:
            httpGet:
              path: /
              port: 80
            periodSeconds: 3
            failureThreshold: 3
```

Apply with `kubectl apply -f`, then update the image separately or all at once.

</details>

<details>
<summary>Hint 2: Triggering the image update</summary>

**Option A — Edit and apply:**
Change the image from `nginx:1.25` to `nginx:1.26` in your YAML and apply.

**Option B — kubectl set image:**
```bash
kubectl set image deployment/learn-frontend nginx=nginx:1.26 -n learn-ch13
```

Both trigger an identical rolling update.

</details>

<details>
<summary>Hint 3: The request loop is showing failures</summary>

Check these in order:

1. **Is the readiness probe configured?** Without it, `maxUnavailable: 0` doesn't actually prevent downtime — K8s thinks the new pod is ready instantly.

2. **Is the port-forward still running?** If the port-forward process died, all requests fail with connection errors, not HTTP errors. Check with `jobs` or restart it.

3. **Is the strategy actually applied?** Run:
   ```bash
   kubectl get deployment learn-frontend -n learn-ch13 -o jsonpath='{.spec.strategy}'
   ```

</details>

---

## Verification

After the update completes:

```bash
# All pods should be running nginx:1.26
kubectl get pods -n learn-ch13 -l app=learn-frontend \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Rollout history should show revisions
kubectl rollout history deployment/learn-frontend -n learn-ch13

# Strategy should be configured
kubectl get deployment learn-frontend -n learn-ch13 \
  -o jsonpath='{.spec.strategy}' | python3 -m json.tool
```

Run the verify script:

```bash
bash curriculum/world-4-kubernetes-production/ch13-health-reliability/challenges/verify.sh
```

---

> **Sarah:** "That's what zero-downtime looks like. No maintenance windows. No 2 AM deploys. Users kept ordering lattes the entire time and never noticed. That's the standard."

**Next:** [Challenge 03 — Graceful Shutdown](03-graceful-shutdown.md)
