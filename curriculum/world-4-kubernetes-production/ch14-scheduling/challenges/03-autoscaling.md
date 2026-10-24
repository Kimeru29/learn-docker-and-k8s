# Challenge 3: Autoscaling

> **Sarah:** "The NoCappuccino kiosk at Heathrow went viral. Marcus just forwarded a notification — traffic is about to spike. We need autoscaling so Kubernetes handles it automatically, without anyone SSH-ing into anything or manually bumping replica counts."

---

## The Situation

The `learn-frontend` Deployment is running at 2 replicas in namespace `learn-ch14`. Traffic is currently quiet. But a spike is incoming, and you need the Horizontal Pod Autoscaler to handle it.

---

## Prerequisites

This challenge requires the Metrics Server. Check if it's running:

```bash
kubectl get deployment metrics-server -n kube-system
```

If not found, install it:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# kind clusters need this flag
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl rollout status deployment/metrics-server -n kube-system
```

Verify it works:

```bash
kubectl top nodes
kubectl top pods -n learn-ch14
```

If `kubectl top` returns `error: Metrics API not available`, wait 60 seconds and retry.

---

## Setup

```bash
kubectl create namespace learn-ch14 2>/dev/null || true
```

Apply the Deployment:

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch14
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch14
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-frontend
  template:
    metadata:
      labels:
        app: learn-frontend
        world: w04
        chapter: ch14
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
  namespace: learn-ch14
spec:
  selector:
    app: learn-frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
EOF
```

---

## Your Mission

### Part 1: Create the HPA

Create a Horizontal Pod Autoscaler for `learn-frontend` with:

- **Minimum replicas:** `2`
- **Maximum replicas:** `10`
- **Target CPU utilization:** `50%`

After creating it, verify:

```bash
kubectl get hpa -n learn-ch14
```

The `TARGETS` column should show a percentage (e.g., `3%/50%`). If it shows `<unknown>/50%`, wait 30–60 seconds for the Metrics Server to collect data.

### Part 2: Generate Load and Watch Scaling

Run a load generator from inside the cluster:

```bash
# Start a load generator pod
kubectl run -n learn-ch14 load-generator --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://learn-frontend.learn-ch14.svc.cluster.local; done"
```

While the load runs, watch what happens:

```bash
# Watch HPA in real time
kubectl get hpa -n learn-ch14 -w

# Watch pods scale up
kubectl get pods -n learn-ch14 -w
```

You should see:
1. CPU utilization climb above 50%
2. HPA increase the replica count
3. New pods appear and reach Running
4. CPU per pod drop as load is distributed

### Part 3: Stop Load and Watch Scale-Down

```bash
# Stop the load generator
kubectl delete pod load-generator -n learn-ch14
```

After the scale-down stabilization window (~5 minutes), the HPA should reduce replicas back toward the minimum.

### Part 4: Read the Scaling Events

```bash
kubectl describe hpa -n learn-ch14
```

Look at the `Events` section. You should see `SuccessfulRescale` entries showing when and why the HPA scaled.

---

## Success Criteria

- An HPA exists in `learn-ch14` targeting `learn-frontend`
- `minReplicas: 2`, `maxReplicas: 10`, CPU target: `50%`
- `kubectl describe hpa` shows at least one scaling event
- At load peak, replica count exceeded the minimum of 2

---

## Hints

<details>
<summary>Hint 1: Creating the HPA</summary>

The fastest way:

```bash
kubectl autoscale deployment learn-frontend \
  --min=2 --max=10 --cpu-percent=50 \
  -n learn-ch14
```

Or apply a YAML file with `apiVersion: autoscaling/v2`.

</details>

<details>
<summary>Hint 2: HPA shows unknown targets</summary>

Two common causes:

1. **Metrics Server not ready:** `kubectl top pods -n learn-ch14` should return data. If it errors, wait longer.

2. **CPU requests not set:** The HPA calculates utilization as `current / requests`. No requests = no percentage. Confirm: `kubectl get deployment learn-frontend -n learn-ch14 -o yaml | grep -A 3 requests`

</details>

<details>
<summary>Hint 3: Load generator isn't causing scaling</summary>

A single `wget` loop might not generate enough CPU load on nginx to cross the 50% threshold (nginx is very efficient).

Try a more aggressive load:

```bash
kubectl delete pod load-generator -n learn-ch14 2>/dev/null
for i in $(seq 1 5); do
  kubectl run -n learn-ch14 "load-gen-$i" --image=busybox:1.36 --restart=Never -- \
    /bin/sh -c "while true; do wget -q -O- http://learn-frontend.learn-ch14.svc.cluster.local; done"
done
```

Or lower the HPA target temporarily:

```bash
kubectl patch hpa learn-frontend -n learn-ch14 \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/metrics/0/resource/target/averageUtilization","value":20}]'
```

Don't forget to clean up load generator pods when done:

```bash
kubectl delete pods -n learn-ch14 -l run --field-selector=status.phase=Running
```

</details>

---

## Verification

```bash
bash curriculum/world-4-kubernetes-production/ch14-scheduling/challenges/verify.sh
```

Or manually:

```bash
# HPA exists and shows targets
kubectl get hpa -n learn-ch14

# HPA has scaling events
kubectl describe hpa -n learn-ch14

# Clean up load generators
kubectl delete pod -n learn-ch14 -l run 2>/dev/null
```

---

> **Sarah:** "You just watched Kubernetes scale a deployment automatically based on real traffic. No humans involved, no SSH, no manual `kubectl scale`. When Dave lands, all he'll see is a green dashboard. That's the standard."

**Finished with Chapter 14 challenges!** Run the full verify script, then take the [Quiz](../quiz.md).
