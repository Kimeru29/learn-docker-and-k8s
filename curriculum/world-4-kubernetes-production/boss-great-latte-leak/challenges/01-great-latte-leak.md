# Boss Fight: The Great Latte Leak

> **Sarah:** "Five things are broken. Dave is unreachable. Marcus wants answers in forty minutes. Here's what I need from you: triage, fix, verify. One at a time. Start with whatever you think is most critical. I'll be right here."

---

## The Situation

It is 6:15 AM. The NoCappuccino production cluster has five simultaneous failures:

1. **An API deployment is stuck** — pods can't start
2. **A worker is crashing repeatedly** — memory issues
3. **Credentials are leaking** — visible in pod environment
4. **A service is unhealthy** — traffic goes to broken pods
5. **A security violation** — overpowered ServiceAccount

All five are in namespace `learn-boss-w4`. You must investigate each one, determine the root cause, and fix it.

---

## Setup: Deploy the Broken State

Create the namespace and apply the broken manifests:

```bash
kubectl create namespace learn-boss-w4
```

Save the following as `boss-broken-state.yaml` and apply it:

```yaml
# ============================================================
# 1. API Deployment (has a problem)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-boss-w4
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
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
    spec:
      containers:
        - name: api
          image: nginx:1.25-alpin     # <-- look carefully
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
  namespace: learn-boss-w4
spec:
  selector:
    app: learn-api
  ports:
    - port: 80
      targetPort: 80

---
# ============================================================
# 2. Worker Deployment (has a problem)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-worker
  namespace: learn-boss-w4
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
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

---
# ============================================================
# 3. App ConfigMap (has a problem)
# ============================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: learn-boss-w4
data:
  LOG_LEVEL: "info"
  API_BASE_URL: "https://api.nocappuccino.internal"
  DB_HOST: "learn-db"
  DB_PORT: "5432"
  DB_USER: "nocap_admin"
  DB_PASSWORD: "Pr0duct10nP@ss!"

---
# App pod that reads from ConfigMap
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-app
  namespace: learn-boss-w4
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: learn-app
  template:
    metadata:
      labels:
        app: learn-app
        world: w04
    spec:
      containers:
        - name: app
          image: nginx:1.25
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: app-config
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"

---
# ============================================================
# 4. Order Service (has a problem)
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-order-service
  namespace: learn-boss-w4
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-order-service
  template:
    metadata:
      labels:
        app: learn-order-service
        world: w04
    spec:
      containers:
        - name: order
          image: nginx:1.25
          ports:
            - containerPort: 80
          # No readiness probe — traffic goes to all pods
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
  name: learn-order-service
  namespace: learn-boss-w4
spec:
  selector:
    app: learn-order-service
  ports:
    - port: 80
      targetPort: 80

---
# ============================================================
# 5. Overpowered ServiceAccount (has a problem)
# ============================================================
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deploy-bot
  namespace: learn-boss-w4

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: deploy-bot-admin
subjects:
  - kind: ServiceAccount
    name: deploy-bot
    namespace: learn-boss-w4
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f boss-broken-state.yaml
```

Now break the order service (simulate 2 of 3 pods returning errors):

```bash
sleep 10  # Wait for pods to start

PODS=$(kubectl get pods -n learn-boss-w4 -l app=learn-order-service -o jsonpath='{.items[*].metadata.name}')
POD_ARRAY=($PODS)

for pod in "${POD_ARRAY[@]:0:2}"; do
  kubectl exec "$pod" -n learn-boss-w4 -- /bin/sh -c \
    'echo "server { listen 80; location / { return 503 \"service unavailable\"; } }" > /etc/nginx/conf.d/default.conf && nginx -s reload' 2>/dev/null
  echo "Broke order-service pod: $pod"
done
```

---

## Your Mission

Investigate and fix all five issues. The order you fix them is up to you — triage based on impact.

### Issue 1: Fix the API Deployment
The `learn-api` pods are stuck. They can't start. Investigate why and fix it.

### Issue 2: Fix the Worker Memory
The `learn-worker` pod keeps getting OOMKilled. Set appropriate resource limits.

### Issue 3: Fix the Credential Leak
Database credentials (`DB_USER`, `DB_PASSWORD`) are in the `app-config` ConfigMap and injected as environment variables. Move them to a Secret named `db-credentials` and mount it as files at `/etc/secrets/` in the `learn-app` pod. Remove credentials from the ConfigMap.

### Issue 4: Fix the Order Service Health
The `learn-order-service` pods show `Running` but two are returning 503 errors. Traffic still flows to them because there's no readiness probe. Add a readiness probe so only healthy pods receive traffic.

### Issue 5: Fix the RBAC Violation
The `deploy-bot` ServiceAccount has a ClusterRoleBinding to `cluster-admin`. That's a critical security violation. Replace it with a Role/RoleBinding that gives `deploy-bot` only the permissions it needs: `get`, `list`, `update` on `deployments` in the `learn-boss-w4` namespace.

---

## Investigation Tools

```bash
# Overview of everything in the namespace
kubectl get all -n learn-boss-w4

# Check for problem pods
kubectl get pods -n learn-boss-w4

# Investigate specific pods
kubectl describe pod <pod-name> -n learn-boss-w4
kubectl logs <pod-name> -n learn-boss-w4

# Check ConfigMap for leaked credentials
kubectl get configmap app-config -n learn-boss-w4 -o yaml

# Check RBAC
kubectl auth can-i --list \
  --as=system:serviceaccount:learn-boss-w4:deploy-bot

# Check endpoints (which pods receive traffic)
kubectl get endpoints learn-order-service -n learn-boss-w4
```

---

## Hints

Work through these one at a time. Only read the hint for the issue you're stuck on.

<details>
<summary>Hint 1: API ImagePullBackOff</summary>

Run `kubectl describe pod -l app=learn-api -n learn-boss-w4` and read the Events section. Look at the exact image name in the error message. Compare it character-by-character to valid Docker Hub image tags.

The image tag has a typo. Fix it with `kubectl set image` or by editing the Deployment YAML.

</details>

<details>
<summary>Hint 2: Worker OOMKilled</summary>

Run `kubectl describe pod -l app=learn-worker -n learn-boss-w4`. Look for `Reason: OOMKilled` and `Exit Code: 137`. Check the memory limit — is 8Mi enough for nginx to start?

Increase `requests.memory` and `limits.memory` to at least 64Mi and 128Mi respectively.

</details>

<details>
<summary>Hint 3: Credential Leak</summary>

The `app-config` ConfigMap contains `DB_USER` and `DB_PASSWORD`. Remove them from the ConfigMap. Create a Secret:

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=nocap_admin \
  --from-literal=DB_PASSWORD='Pr0duct10nP@ss!' \
  -n learn-boss-w4
```

Update the `learn-app` Deployment to mount the Secret as files at `/etc/secrets/` instead of using `envFrom` for credentials.

</details>

<details>
<summary>Hint 4: Order Service Readiness</summary>

Add a readiness probe to the `learn-order-service` Deployment:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  periodSeconds: 5
  failureThreshold: 3
```

After applying, Kubernetes will detect the two broken pods and remove them from the Service endpoints. Only the healthy pod receives traffic.

</details>

<details>
<summary>Hint 5: RBAC Violation</summary>

Delete the overpowered ClusterRoleBinding:

```bash
kubectl delete clusterrolebinding deploy-bot-admin
```

Create a namespace-scoped Role and RoleBinding:

```bash
kubectl create role deploy-bot-role \
  --verb=get,list,update \
  --resource=deployments \
  -n learn-boss-w4

kubectl create rolebinding deploy-bot-binding \
  --role=deploy-bot-role \
  --serviceaccount=learn-boss-w4:deploy-bot \
  -n learn-boss-w4
```

Verify: `kubectl auth can-i delete pods --as=system:serviceaccount:learn-boss-w4:deploy-bot -n learn-boss-w4` should return `no`.

</details>

---

## Verification

When you think all five issues are fixed:

```bash
bash curriculum/world-4-kubernetes-production/boss-great-latte-leak/challenges/verify.sh
```

---

## The Debrief

*After all five checks pass...*

It's 8:34 AM.

You push back from your desk. The incident channel is quiet. The monitoring dashboard — the same one that was screaming two hours ago — is green across the board.

- API: 3/3 pods Running ✓
- Worker: stable, no OOMKills in 30 minutes ✓
- Credentials: moved to Secret, not in logs ✓
- Order Service: readiness probe active, traffic to healthy pods only ✓
- deploy-bot: namespace-scoped permissions ✓

Sarah reads through your fixes. She's quiet for a moment, then nods.

"Five simultaneous failures. No CTO. Morning rush bearing down. And you handled all of them."

She doesn't oversell it. That's how you know she means it.

---

At 9:02 AM, a Slack message arrives from somewhere over the Pacific.

**@dave** (via in-flight Wi-Fi he wasn't supposed to have): `checking dashboards. everything is... green?`

**@dave**: `who fixed the API`

**@dave**: `and why does the worker have actual memory limits now`

**@dave**: `also why are the DB creds not in the logs anymore`

**@dave**: `AND we have RBAC now?`

**@dave**: `you know what, I don't need to know how. I just need to know it's fixed. incredible work.`

**@dave**: `going to get a coffee. they have a NoCappuccino kiosk at narita btw`

Marcus pings at 9:14 AM: `morning rush metrics look great. investor demo went perfectly. what did you do? the API p99 is the best it's been in weeks.`

You don't answer Marcus yet. You're writing up the post-mortem.

Sarah smiles. "Always write the post-mortem."

---

> **Sarah:** "That was a real production incident. Five problems, zero hand-holding, clock ticking. And you triaged, diagnosed, and fixed every single one. You didn't just learn Kubernetes — you learned how to operate it under pressure. That's the difference between knowing the tools and knowing the job."
>
> "Welcome to the team — for real this time."
