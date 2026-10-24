# Lesson 3: Autoscaling

> **Sarah:** "A coffee influencer with 2 million followers just tweeted about NoCappuccino. Traffic tripled in two minutes. Our static replica count of 3 handled the normal load fine. It did not handle the viral moment. Let me show you how to make Kubernetes react to real demand."

---

## Horizontal Pod Autoscaler (HPA)

The HPA automatically adjusts the replica count of a Deployment based on observed metrics. More traffic → more pods. Less traffic → fewer pods.

### How it works

The HPA controller runs in the control plane and queries the Metrics Server every 15 seconds. It compares current metric values to your target and calculates the desired replica count.

**The formula:**

```
desiredReplicas = ceil(currentReplicas × (currentMetric / targetMetric))
```

**Example:** 2 pods averaging 80% CPU, target is 50%:

```
desiredReplicas = ceil(2 × (80 / 50)) = ceil(3.2) = 4
```

The HPA scales to 4 pods. Once CPU drops below 50%, it eventually scales back down.

### Creating an HPA

**From the command line:**
```bash
kubectl autoscale deployment learn-frontend \
  --min=2 \
  --max=10 \
  --cpu-percent=50 \
  -n learn-ch14
```

**From YAML (recommended for version control):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: learn-frontend-hpa
  namespace: learn-ch14
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: learn-frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

### Requirements

1. **Metrics Server must be installed.** The HPA reads metrics from the Metrics API. In kind clusters:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   kubectl patch deployment metrics-server -n kube-system \
     --type='json' \
     -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   ```

2. **CPU/memory requests must be set on the Deployment.** The HPA calculates utilization as a percentage of the requested amount. No requests = no percentage = HPA shows `<unknown>`.

### Checking HPA status

```bash
kubectl get hpa -n learn-ch14
# NAME                   REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS
# learn-frontend-hpa     Deployment/learn-front   23%/50%   2         10        2

kubectl describe hpa learn-frontend-hpa -n learn-ch14
# Shows scaling events, conditions, and current metrics
```

If `TARGETS` shows `<unknown>/50%`, either the Metrics Server isn't ready or `requests.cpu` isn't set.

---

## Scaling Metrics

### CPU utilization (most common)

```yaml
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

Scales when the average CPU utilization across all pods exceeds 50% of their requested CPU.

### Memory utilization

```yaml
metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

Scales when average memory usage exceeds 70% of requested memory. **Caution:** Memory-based scaling is less predictable than CPU. Memory often grows gradually (caches, connection pools) and doesn't drop quickly when load decreases. This can cause the HPA to scale up but never scale down.

### Multiple metrics

```yaml
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

With multiple metrics, the HPA calculates the desired replica count for each metric and uses the **highest** value. If CPU says 4 pods and memory says 6, the HPA scales to 6.

### Custom metrics (advanced)

With Prometheus Adapter or KEDA, you can scale on:
- Requests per second
- Queue depth (messages waiting to be processed)
- Active connections
- Custom application metrics

This is beyond the scope of this chapter but understand that CPU isn't the only option.

---

## Scaling Behavior

### Scale-up

The HPA reacts to high utilization quickly — within 15–30 seconds of detecting the need. By default, it can double the replica count in a single scale-up decision.

### Scale-down

The HPA is deliberately conservative about scaling down:
- Default stabilization window: **5 minutes**
- The HPA looks at the maximum recommendation over the last 5 minutes
- This prevents flapping: traffic drops briefly, you scale down, traffic spikes again, you scale back up

### Configuring behavior (autoscaling/v2)

```yaml
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0        # React immediately
      policies:
        - type: Percent
          value: 100                        # Can double replica count
          periodSeconds: 60
        - type: Pods
          value: 4                          # Or add up to 4 pods
          periodSeconds: 60
      selectPolicy: Max                     # Use whichever allows more scaling

    scaleDown:
      stabilizationWindowSeconds: 300       # Wait 5 minutes before scaling down
      policies:
        - type: Percent
          value: 10                         # Remove at most 10% per minute
          periodSeconds: 60
      selectPolicy: Min                     # Use whichever removes fewer pods
```

This configuration scales up aggressively (double or +4 pods per minute) but scales down slowly (10% per minute, with a 5-minute cooldown). This is a good default for production: handle spikes fast, avoid premature scale-down.

---

## When HPA Helps and When It Doesn't

### HPA helps when:

- Traffic patterns are variable and somewhat predictable
- The workload is CPU or memory-bound
- You have enough cluster capacity to add more pods
- Your app can handle multiple replicas (stateless or properly distributed)

### HPA doesn't help when:

- **The pods are OOMKilled** — Scaling up just creates more pods that also get OOMKilled. Fix the resource limits first.
- **The bottleneck is external** — If the database is the limit, more API pods just creates more connections to a saturated database.
- **The app isn't horizontally scalable** — A single-threaded worker that processes one job at a time won't go faster with more replicas (unless jobs are parallelizable).
- **Startup time is slow** — If pods take 60 seconds to start, the HPA's reaction time is 60+ seconds. The traffic spike may be over before the new pods are ready.
- **There's no cluster capacity** — The HPA creates pods, but if no node has room, the pods stay Pending. This is where the Cluster Autoscaler comes in (adds new nodes to the cluster).

---

## Vertical Pod Autoscaler (VPA) — Concepts

The VPA adjusts **resource requests** instead of replica count. If your pod needs 256Mi but you requested 64Mi, the VPA bumps the request to match actual usage.

### Modes

| Mode | Behavior |
|------|----------|
| `Off` | VPA calculates recommendations but doesn't apply them. Read-only. |
| `Initial` | VPA sets requests when pods are created but doesn't change running pods. |
| `Auto` | VPA evicts pods and recreates them with updated requests. |

### When to use VPA

- **Right-sizing:** You don't know what resources your app actually needs. Deploy with VPA in `Off` mode, observe recommendations, apply manually.
- **Vertical workloads:** A single-threaded worker that needs more CPU, not more replicas.
- **Complementary to HPA:** VPA right-sizes individual pods, HPA adjusts the count.

**Caution:** VPA and HPA should not both target CPU or memory on the same Deployment. They'll fight each other. Use HPA for scaling and VPA for right-sizing on a metric the HPA doesn't watch (or use VPA in `Off` mode for recommendations only).

---

## Quick Reference

```bash
# Create HPA
kubectl autoscale deployment <name> --min=2 --max=10 --cpu-percent=50 -n <namespace>

# Check HPA status
kubectl get hpa -n <namespace>
kubectl describe hpa <name> -n <namespace>

# Generate load (simple approach)
kubectl run load-generator --image=busybox:1.36 -n <namespace> -- /bin/sh -c \
  "while true; do wget -q -O- http://learn-frontend.learn-ch14.svc.cluster.local; done"

# Watch pods scale
kubectl get pods -n <namespace> -w

# Check Metrics Server
kubectl top pods -n <namespace>
kubectl top nodes

# Delete HPA
kubectl delete hpa <name> -n <namespace>
```

---

> **Sarah:** "The HPA is not a magic fix. It's a feedback loop: observe metrics, calculate desired state, adjust replica count. If the underlying problem is bad resource limits or a database bottleneck, more pods just means more things failing at the same time. Fix the foundation first, then let the HPA handle the elasticity."

**Now let's apply everything: [Challenge 01 — Fix OOMKilled](../challenges/01-fix-oomkilled.md)**
