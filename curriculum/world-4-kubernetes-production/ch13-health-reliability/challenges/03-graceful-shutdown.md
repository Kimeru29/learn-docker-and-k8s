# Challenge 3: Graceful Shutdown

> **Sarah:** "The worker service takes about 30 seconds to finish processing its current batch. When Kubernetes kills it during a rolling update, the default 30-second grace period cuts it close — sometimes too close. Half-processed jobs get lost. We need to give it time to drain properly and signal when it's done."

---

## The Situation

The `learn-worker` Deployment in namespace `learn-ch13` runs a simulated long-running process. When the pod receives SIGTERM, the process needs time to finish its current work before exiting cleanly.

The problem: the default `terminationGracePeriodSeconds` is 30 seconds, and the worker sometimes needs up to 45 seconds to drain. Kubernetes sends SIGKILL at the 30-second mark, killing the process mid-work.

Your job: configure the Deployment so the worker has enough time to shut down gracefully, and add a preStop hook to handle the endpoint propagation delay.

---

## Setup

```bash
kubectl create namespace learn-ch13 2>/dev/null || true
```

Save the following as `worker-deployment.yaml` and apply it:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-worker
  namespace: learn-ch13
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch13
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-worker
  template:
    metadata:
      labels:
        app: learn-worker
        world: w04
        chapter: ch13
    spec:
      # NOTE: No terminationGracePeriodSeconds set (defaults to 30s)
      containers:
        - name: worker
          image: busybox:1.36
          command:
            - /bin/sh
            - -c
            - |
              # Simulate a worker that needs time to drain
              trap 'echo "[$(date +%T)] SIGTERM received, draining..."; sleep 45; echo "[$(date +%T)] Drain complete, exiting."; exit 0' TERM
              echo "[$(date +%T)] Worker started, processing..."
              while true; do
                echo "[$(date +%T)] Working..."
                sleep 5
              done
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

```bash
kubectl apply -f worker-deployment.yaml
```

Wait for the pods to be running:

```bash
kubectl get pods -n learn-ch13 -l app=learn-worker -w
```

---

## Observe the Problem

Try deleting a pod and watch what happens:

```bash
# In one terminal, watch the pod logs
POD_NAME=$(kubectl get pods -n learn-ch13 -l app=learn-worker -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f "$POD_NAME" -n learn-ch13 &

# In another terminal, delete the pod
kubectl delete pod "$POD_NAME" -n learn-ch13

# Watch the output — you should see:
# SIGTERM received, draining...
# Then after 30 seconds (before the 45-second drain completes): the pod is killed
```

The pod is killed before it finishes draining. In a real application, this means lost work.

---

## Your Mission

Modify the `learn-worker` Deployment so that:

1. **`terminationGracePeriodSeconds`** is set high enough for the worker to drain completely (the worker needs up to 45 seconds after SIGTERM)
2. **A preStop hook** is configured that sleeps for 5 seconds (to allow endpoint propagation)
3. After deleting a pod, the worker completes its full drain sequence ("Drain complete, exiting." appears in the logs)
4. The pod is NOT killed by SIGKILL during normal termination

**Remember:** `terminationGracePeriodSeconds` is the **total** time from the start of the preStop hook to SIGKILL. Factor in both the preStop sleep and the drain time.

---

## Hints

<details>
<summary>Hint 1: How much grace time do you need?</summary>

The timeline is:
1. preStop hook runs: 5 seconds sleep
2. SIGTERM is sent to the process
3. The process drains for up to 45 seconds
4. Total needed: 5 + 45 = 50 seconds (at minimum)

Set `terminationGracePeriodSeconds` to at least 60 to give some buffer:

```yaml
spec:
  terminationGracePeriodSeconds: 60
```

</details>

<details>
<summary>Hint 2: Adding the preStop hook</summary>

The preStop hook goes in the container's `lifecycle` section:

```yaml
containers:
  - name: worker
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 5"]
```

This runs before SIGTERM is sent. It gives kube-proxy and other networking components time to remove the pod from routing tables.

</details>

<details>
<summary>Hint 3: Verifying the fix</summary>

After applying the updated Deployment, delete a pod and watch its logs:

```bash
POD_NAME=$(kubectl get pods -n learn-ch13 -l app=learn-worker -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f "$POD_NAME" -n learn-ch13 &
kubectl delete pod "$POD_NAME" -n learn-ch13
```

You should see:
1. "SIGTERM received, draining..." (after the 5s preStop sleep)
2. "Drain complete, exiting." (45 seconds later)
3. The pod exits cleanly — no SIGKILL

Check with `kubectl describe pod` — the termination reason should be `Completed`, not `Error` or `OOMKilled`.

</details>

---

## Verification

```bash
bash curriculum/world-4-kubernetes-production/ch13-health-reliability/challenges/verify.sh
```

Or check manually:

```bash
# Check terminationGracePeriodSeconds is set
kubectl get deployment learn-worker -n learn-ch13 \
  -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}'
# Should be >= 55

# Check preStop hook is configured
kubectl get deployment learn-worker -n learn-ch13 \
  -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop}'

# Delete a pod and confirm graceful shutdown
POD_NAME=$(kubectl get pods -n learn-ch13 -l app=learn-worker -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD_NAME" -n learn-ch13
# Watch the replacement pod's predecessor's logs — "Drain complete" should appear
```

---

> **Sarah:** "Graceful shutdown is one of those things you never think about until a job gets killed mid-processing and a customer's order disappears. A 60-second grace period and a 5-second preStop hook cost nothing. Losing customer data costs everything."

**Finished with Chapter 13 challenges!** Run the full verify script, then take the [Quiz](../quiz.md).
