# Challenge 1: Probe Diagnosis

> **Sarah:** "Three pods. All show Running. But customer complaints keep coming in — orders fail, pages timeout, and the error rate is climbing. The monitoring dashboard is green. The customers disagree. Time to find out which pods are actually healthy and stop traffic from reaching the broken ones."

---

## The Situation

The `learn-api` Deployment in namespace `learn-ch13` has 3 replicas. All three pods show `Running` and `Ready 1/1`. The Service routes traffic to all three.

But two of the pods are returning HTTP 500 errors on every request. The application inside crashed and restarted in a degraded state — it accepts TCP connections (so the container is technically running) but every HTTP response is a 500.

Because there are no health probes, Kubernetes has no idea anything is wrong. Traffic continues flowing to all three pods, meaning roughly two-thirds of all user requests fail.

---

## Setup

Create the namespace and apply the broken state:

```bash
kubectl create namespace learn-ch13
```

Save the following as `broken-api.yaml` and apply it:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-ch13
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch13
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-api
  template:
    metadata:
      labels:
        app: learn-api
        world: w04
        chapter: ch13
    spec:
      containers:
        - name: api
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
  name: learn-api
  namespace: learn-ch13
spec:
  selector:
    app: learn-api
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

```bash
kubectl apply -f broken-api.yaml
```

Now simulate the broken state. Two of the three pods will return 500 errors. Run this after the pods are ready:

```bash
# Get pod names
PODS=$(kubectl get pods -n learn-ch13 -l app=learn-api -o jsonpath='{.items[*].metadata.name}')
POD_ARRAY=($PODS)

# Break two of the three pods by replacing the default nginx page with a 500 error
for pod in "${POD_ARRAY[@]:0:2}"; do
  kubectl exec "$pod" -n learn-ch13 -- /bin/sh -c \
    'rm /usr/share/nginx/html/index.html && echo "error" > /usr/share/nginx/html/50x.html'
  kubectl exec "$pod" -n learn-ch13 -- /bin/sh -c \
    'echo "server { listen 80; location / { return 500; } location /healthz { return 500; } }" > /etc/nginx/conf.d/default.conf && nginx -s reload'
  echo "Broke pod: $pod"
done

echo "Healthy pod: ${POD_ARRAY[2]}"
```

Verify the breakage — port-forward to the Service and make requests:

```bash
kubectl port-forward service/learn-api 8090:80 -n learn-ch13 &
# Make a few requests — roughly 2/3 should return 500
for i in $(seq 1 9); do
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8090
done
kill %1 2>/dev/null
```

You should see a mix of `HTTP 200` and `HTTP 500` responses.

---

## Your Mission

Fix the deployment so that traffic only reaches healthy pods. Specifically:

1. **Add a readiness probe** to the `learn-api` Deployment that checks HTTP health on port 80
2. After applying the probe, Kubernetes should detect that two pods are not ready and **remove them from Service endpoints**
3. Only the healthy pod should receive traffic
4. All curl requests through the Service should return `HTTP 200`

**Bonus:** Add a liveness probe that will eventually restart the broken pods, returning them to healthy state (since a fresh nginx container serves 200 by default).

---

## Investigation Steps

Start by confirming the problem:

```bash
# All pods show Running — but are they healthy?
kubectl get pods -n learn-ch13

# Check endpoints — all three pod IPs are listed
kubectl get endpoints learn-api -n learn-ch13

# Make requests through the Service — you'll see failures
```

Then make your fix and verify:

```bash
# After adding probes, watch pods become NotReady
kubectl get pods -n learn-ch13 -w

# Check endpoints again — only healthy pods should be listed
kubectl get endpoints learn-api -n learn-ch13

# All requests should now return 200
```

---

## Hints

<details>
<summary>Hint 1: What kind of probe do you need?</summary>

You need a **readiness probe** to remove broken pods from Service endpoints. The key property of a readiness probe: when it fails, the pod stays running but is removed from the Service — no traffic reaches it.

Think about what endpoint to check and what a healthy response looks like.

</details>

<details>
<summary>Hint 2: Configuring the readiness probe</summary>

Add a readiness probe to the container spec in your Deployment:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  periodSeconds: 5
  failureThreshold: 3
```

This sends an HTTP GET to `/` every 5 seconds. If it gets 3 consecutive non-2xx responses, the pod is marked NotReady and removed from endpoints.

Apply the updated Deployment with `kubectl apply -f`. Kubernetes will perform a rolling update with the new probe configuration.

</details>

<details>
<summary>Hint 3: The bonus — adding a liveness probe to restart broken pods</summary>

A liveness probe with the same HTTP check will cause Kubernetes to restart pods that fail the check:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
```

When the broken pods fail 3 consecutive liveness checks, Kubernetes kills and restarts them. Fresh containers will serve 200 again, pass the readiness probe, and be added back to endpoints.

</details>

---

## Verification

When you think you're done, run:

```bash
bash curriculum/world-4-kubernetes-production/ch13-health-reliability/challenges/verify.sh
```

Or check manually:

```bash
# Deployment should have a readiness probe configured
kubectl get deployment learn-api -n learn-ch13 -o yaml | grep -A 5 readinessProbe

# Endpoints should only list healthy pod IPs
kubectl get endpoints learn-api -n learn-ch13

# All requests through the Service should return 200
kubectl port-forward service/learn-api 8090:80 -n learn-ch13 &
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8090
done
kill %1 2>/dev/null
```

---

> **Sarah:** "You just stopped Kubernetes from sending traffic to broken pods. That one readiness probe is the difference between 'two-thirds of requests fail' and 'zero requests fail.' This is the single most impactful thing you can add to any Deployment."

**Next:** [Challenge 02 — Zero-Downtime Update](02-zero-downtime-update.md)
