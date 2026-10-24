# Challenge 1: Fix OOMKilled

> **Sarah:** "The worker pod has restarted 6 times in the last hour. Exit Code 137 every time. That's OOMKilled — the kernel killed it because it exceeded its memory limit. Or maybe it has no limit and it consumed everything until the node's OOM killer fired. Either way, we need to diagnose it and fix it."

---

## The Situation

The `learn-worker` Deployment in namespace `learn-ch14` has a pod that keeps getting OOMKilled. It restarts, runs for a bit, gets killed again, and is now in `CrashLoopBackOff`.

Your job: diagnose the problem using `kubectl describe` and events, then set appropriate memory requests and limits so the pod runs stably.

---

## Setup

```bash
kubectl create namespace learn-ch14
```

Save the following as `oom-worker.yaml` and apply it:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-worker
  namespace: learn-ch14
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch14
spec:
  replicas: 1
  selector:
    matchLabels:
      app: learn-worker
  template:
    metadata:
      labels:
        app: learn-worker
        world: w04
        chapter: ch14
    spec:
      containers:
        - name: worker
          image: nginx:1.25
          resources:
            requests:
              memory: "4Mi"
              cpu: "25m"
            limits:
              memory: "8Mi"
              cpu: "50m"
```

```bash
kubectl apply -f oom-worker.yaml
```

Wait about 30 seconds and check the pod status:

```bash
kubectl get pods -n learn-ch14 -l app=learn-worker
```

You should see the pod in `OOMKilled` or `CrashLoopBackOff` state.

---

## Your Mission

1. **Diagnose** the OOMKilled condition using `kubectl describe` and `kubectl get events`
2. **Identify** the root cause: is the memory limit too low, or is the app misbehaving?
3. **Fix** the Deployment by setting appropriate memory requests and limits
4. **Verify** the pod runs stably without OOMKilled restarts

**Success criteria:**
- The `learn-worker` pod is `Running` with `READY 1/1` and zero recent restarts
- Memory `requests` are set to at least `32Mi`
- Memory `limits` are set to at least `64Mi`
- The pod's QoS class should be `Burstable` or `Guaranteed`

---

## Investigation

Start by reading the evidence:

```bash
# Check current status
kubectl get pods -n learn-ch14 -l app=learn-worker

# Get detailed information
kubectl describe pod -l app=learn-worker -n learn-ch14

# Check events
kubectl get events -n learn-ch14 --sort-by='.lastTimestamp'
```

Look for:
- `Reason: OOMKilled` in the pod description
- `Exit Code: 137` in the last termination state
- The current `limits.memory` value — is it realistic for an nginx process?

---

## Hints

<details>
<summary>Hint 1: Understanding the diagnosis</summary>

Run `kubectl describe pod -l app=learn-worker -n learn-ch14` and look at:

```
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
```

Then look at the container's resource limits:

```
Limits:
  memory:  8Mi
```

A basic nginx process uses roughly 5–20 MB just to start. 8Mi is not enough for nginx to initialize. The limit is too low for the workload.

</details>

<details>
<summary>Hint 2: What values to set</summary>

For a basic nginx container:
- `requests.memory`: `32Mi` to `64Mi` (normal operating range)
- `limits.memory`: `64Mi` to `128Mi` (headroom for spikes)

Update the Deployment YAML and apply it. Or use `kubectl edit`:

```bash
kubectl edit deployment learn-worker -n learn-ch14
```

Change the `resources` section to reasonable values.

</details>

<details>
<summary>Hint 3: Verifying the fix</summary>

After applying the fix, wait for the new pod to be created:

```bash
kubectl rollout status deployment/learn-worker -n learn-ch14
```

Then check that the pod is stable:

```bash
kubectl get pods -n learn-ch14 -l app=learn-worker
# Should show Running, 1/1 Ready, 0 restarts

# Check the QoS class
kubectl get pod -l app=learn-worker -n learn-ch14 \
  -o jsonpath='{.items[0].status.qosClass}'
# Should be Burstable (requests != limits) or Guaranteed (requests == limits)
```

</details>

---

## Verification

```bash
bash curriculum/world-4-kubernetes-production/ch14-scheduling/challenges/verify.sh
```

Or check manually:

```bash
# Pod is Running with no recent restarts
kubectl get pods -n learn-ch14 -l app=learn-worker

# Memory limit is sufficient
kubectl get deployment learn-worker -n learn-ch14 \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
```

---

> **Sarah:** "Exit Code 137, every time. The diagnosis was two commands: `kubectl describe` and then reading the memory limit. 8Mi for nginx. The fix was one YAML change. The lesson: always set resource limits, and always set them to values the application can actually run within."

**Next:** [Challenge 02 — Spread Pods](02-spread-pods.md)
