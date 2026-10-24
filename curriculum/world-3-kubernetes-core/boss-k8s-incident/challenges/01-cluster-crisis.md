# Boss Fight: The Cluster Crisis

## Situation Report

Saturday 7:12 AM. Five alerts. No help.

Apply the broken state to your cluster, then diagnose and fix all five issues.

---

## Deploy the Broken State

Create the namespace and apply all broken resources:

```bash
kubectl create namespace learn-boss
```

Apply each broken resource below. **Read them but don't fix them yet** — deploy the broken state first, then diagnose through kubectl.

### Resource 1: Order Service (CrashLoopBackOff)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-order-service
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        world: w03
        chapter: boss
    spec:
      containers:
        - name: order
          image: busybox:1.36
          command: ["sh", "-c", "ech 'Starting order service' && sleep 3600"]
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
```

### Resource 2: Payment Service (Service with no Endpoints)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-payment-service
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment
  template:
    metadata:
      labels:
        app: payment
        world: w03
        chapter: boss
    spec:
      containers:
        - name: payment
          image: hashicorp/http-echo:latest
          args:
            - "-text=Payment processed!"
            - "-listen=:5678"
          ports:
            - containerPort: 5678
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-payment-svc
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  type: ClusterIP
  selector:
    app: payments          # Hmm...
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5678
```

### Resource 3: Analytics PVC (Stuck in Pending)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: learn-analytics-data
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ultra-fast-premium
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-analytics
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: analytics
  template:
    metadata:
      labels:
        app: analytics
        world: w03
        chapter: boss
    spec:
      containers:
        - name: analytics
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Analytics running' && sleep 3600"]
          volumeMounts:
            - name: data
              mountPath: /data
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: learn-analytics-data
```

### Resource 4: Database ConfigMap (Wrong Connection String)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: learn-db-config
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
data:
  DATABASE_HOST: "wrong-hostname.learn-boss.svc.cluster.local"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "nocappuccino"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api-server
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
        world: w03
        chapter: boss
    spec:
      containers:
        - name: api
          image: busybox:1.36
          command: ["sh", "-c", "echo \"Connecting to $(cat /config/DATABASE_HOST):$(cat /config/DATABASE_PORT)/$(cat /config/DATABASE_NAME)\" && sleep 3600"]
          volumeMounts:
            - name: config
              mountPath: /config
              readOnly: true
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
      volumes:
        - name: config
          configMap:
            name: learn-db-config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-database
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        world: w03
        chapter: boss
    spec:
      containers:
        - name: db
          image: hashicorp/http-echo:latest
          args:
            - "-text=Database OK"
            - "-listen=:5432"
          ports:
            - containerPort: 5432
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-database-svc
  namespace: learn-boss
spec:
  selector:
    app: database
  ports:
    - port: 5432
      targetPort: 5432
```

### Resource 5: Recommendation Service (Port Mismatch)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-reco-service
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 2
  selector:
    matchLabels:
      app: reco-service
  template:
    metadata:
      labels:
        app: reco-service
        world: w03
        chapter: boss
    spec:
      containers:
        - name: reco
          image: hashicorp/http-echo:latest
          args:
            - "-text=Try Ethiopian Yirgacheffe!"
            - "-listen=:5678"
          ports:
            - containerPort: 5678
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-reco-svc
  namespace: learn-boss
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  type: ClusterIP
  selector:
    app: reco-service
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080         # Hmm... the container listens on 5678
```

---

## Your Mission

After deploying all broken resources, diagnose and fix each issue:

1. **CrashLoopBackOff** — Find why the order-service Pods keep crashing and fix it
2. **Zero Endpoints** — Find why the payment Service has no endpoints and fix it
3. **PVC Pending** — Find why the analytics PVC won't bind and fix it
4. **Wrong ConfigMap** — Fix the database connection string in the ConfigMap so it points to the actual database Service
5. **Port Mismatch** — Find why the recommendation Service connects but gets no response, and fix it

### Triage Guidance

Sarah's advice: *"Start with what's fastest to diagnose. CrashLoopBackOff and selector mismatches show their symptoms immediately in `kubectl describe`. Storage issues show in PVC events. Work from quickest to most complex."*

But you choose the order. Every fix counts.

---

## Success Criteria

The verify script checks each fix independently:

- [ ] `learn-order-service` — all Pods Running (no CrashLoopBackOff)
- [ ] `learn-payment-svc` — has at least one Endpoint
- [ ] `learn-analytics-data` PVC — is Bound
- [ ] `learn-db-config` ConfigMap — DATABASE_HOST matches `learn-database-svc` (the actual Service)
- [ ] `learn-reco-svc` — in-cluster curl to the Service returns the expected response

---

## Hints

These are intentionally vague. This is the boss fight.

<details>
<summary>Hint 1 — Where to start</summary>

Run `kubectl get all -n learn-boss` to see the full picture. Then `kubectl get pvc -n learn-boss` for storage. Look for anything not in `Running`, `Bound`, or `Complete` status. Start with the issues that have the most obvious symptoms.
</details>

<details>
<summary>Hint 2 — CrashLoopBackOff</summary>

`kubectl logs <pod-name> -n learn-boss` shows what happened before the crash. If the container exits immediately, the issue is often the command itself. Shell commands are unforgiving with typos.
</details>

<details>
<summary>Hint 3 — Service Connectivity</summary>

`kubectl get endpoints <service-name> -n learn-boss` shows what Pods back a Service. If empty, compare the Service's `spec.selector` with the Pod's `metadata.labels`. If endpoints exist but connections fail, compare the Service's `targetPort` with the container's actual listening port — they must match.
</details>

<details>
<summary>Hint 4 — PVC Pending</summary>

`kubectl describe pvc <name> -n learn-boss` shows why it's Pending. Check the Events. Then `kubectl get storageclasses` to see what's available.
</details>

<details>
<summary>Hint 5 — ConfigMap fix</summary>

The ConfigMap has a wrong hostname. What's the actual Service name for the database? Check `kubectl get services -n learn-boss`. The DATABASE_HOST should be the Service name (or FQDN).
</details>

---

## Verification

```bash
bash curriculum/world-3-kubernetes-core/boss-k8s-incident/challenges/verify.sh
```

---

## Post-Mission Debrief

*(Read this after all five checks pass.)*

**What you did:** Triaged and resolved five simultaneous Kubernetes failures:

1. **CrashLoopBackOff:** Fixed a typo in the container command (`ech` → `echo`). The shell command was invalid, causing the container to exit immediately with a non-zero code. Kubernetes kept restarting it with exponential backoff.

2. **Zero Endpoints:** Fixed a label selector mismatch on the payment Service (`payments` → `payment`). The Service couldn't find its backing Pods because the selector didn't match any labels.

3. **PVC Pending:** Changed the StorageClass from `ultra-fast-premium` (doesn't exist) to `standard` (the available class in kind). Required deleting and recreating the PVC.

4. **Wrong ConfigMap:** Updated the `DATABASE_HOST` in the ConfigMap to `learn-database-svc` (or the full FQDN `learn-database-svc.learn-boss.svc.cluster.local`). The ConfigMap volume auto-updated in the Pod.

5. **Port Mismatch:** Fixed the recommendation Service `targetPort` (8080 → 5678) to match the container's actual listening port. The Service had Endpoints and DNS worked, but traffic was forwarded to a port nothing was listening on — a subtler failure than a selector mismatch because `kubectl get endpoints` shows IPs (looks healthy) but the connection silently fails.

**The diagnostic workflow you used:**
```
kubectl get all -n learn-boss          → see the big picture
kubectl get pvc -n learn-boss          → check storage
kubectl describe <resource> <name>     → read Events
kubectl logs <pod-name>                → container output
kubectl get endpoints <svc-name>       → Service backing
kubectl get pods --show-labels         → label verification
```

**Real-world connection:** This is what a real on-call incident looks like. Multiple independent failures at the same time. No runbook covers this exact combination. You triage, diagnose, and fix — one issue at a time. The skills you used (describe, logs, endpoints, labels, StorageClass) are the same ones production SREs use daily.

**Interview angle:** "Tell me about a time you debugged a production K8s issue." — Walk through your triage process: assess the symptoms, use kubectl to diagnose, identify root cause, apply the fix, verify. Mention that you check the most common causes first (selector mismatches, image issues, StorageClass mismatches) before going deeper.

**Pro tip:** In real incidents, document what you find as you go. A quick "CrashLoop: typo in command" note saves 20 minutes when writing the postmortem. And always verify your fix before moving to the next issue — a half-fix that looks green but isn't is worse than a known failure.
