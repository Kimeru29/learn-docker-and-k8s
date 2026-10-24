# Challenge 3: Secret Hygiene

> **Sarah:** "The security audit found database credentials in three places they shouldn't be: environment variables visible in `kubectl describe`, pod logs from a debug statement, and plain YAML in a ConfigMap. We need to move them to a properly mounted Secret and lock down network access so the frontend can't reach the database directly."

---

## The Situation

The `learn-app` Deployment in namespace `learn-ch15` has two problems:

1. **Database credentials are passed as environment variables** from a ConfigMap. They're visible in `kubectl describe pod`, in `env` output inside the container, and in `/proc/1/environ`.

2. **The frontend pod can talk directly to the database.** There's no NetworkPolicy preventing it. The architecture should enforce: frontend → API → database. The frontend should never reach the database directly.

---

## Setup

```bash
kubectl create namespace learn-ch15 2>/dev/null || true
```

Save the following as `insecure-app.yaml` and apply it:

```yaml
# ConfigMap with credentials (BAD!)
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: learn-ch15
data:
  LOG_LEVEL: "info"
  API_BASE_URL: "https://api.nocappuccino.internal"
  DB_HOST: "learn-db"
  DB_PORT: "5432"
  DB_NAME: "nocappuccino"
  DB_USER: "nocap_admin"
  DB_PASSWORD: "Lat73sAndL0gs!"

---
# App pod using env vars from ConfigMap
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-app
  namespace: learn-ch15
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch15
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
        chapter: ch15
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
# Simulated frontend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch15
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch15
spec:
  replicas: 1
  selector:
    matchLabels:
      app: learn-frontend
  template:
    metadata:
      labels:
        app: learn-frontend
        world: w04
        chapter: ch15
    spec:
      containers:
        - name: frontend
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
# Simulated database
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-db
  namespace: learn-ch15
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch15
spec:
  replicas: 1
  selector:
    matchLabels:
      app: learn-db
  template:
    metadata:
      labels:
        app: learn-db
        world: w04
        chapter: ch15
    spec:
      containers:
        - name: db
          image: nginx:1.25
          ports:
            - containerPort: 5432
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
  name: learn-db
  namespace: learn-ch15
spec:
  selector:
    app: learn-db
  ports:
    - port: 5432
      targetPort: 5432

---
apiVersion: v1
kind: Service
metadata:
  name: learn-app
  namespace: learn-ch15
spec:
  selector:
    app: learn-app
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f insecure-app.yaml
```

Verify the problem exists:

```bash
# Credentials are visible in env vars
kubectl exec deploy/learn-app -n learn-ch15 -- env | grep DB_PASSWORD

# Credentials are in the ConfigMap
kubectl get configmap app-config -n learn-ch15 -o yaml | grep DB_PASSWORD
```

---

## Your Mission

### Part 1: Fix Secret Management

1. **Remove `DB_USER` and `DB_PASSWORD`** from the `app-config` ConfigMap
2. **Create a Secret** named `db-credentials` containing `DB_USER` and `DB_PASSWORD`
3. **Update the `learn-app` Deployment** to:
   - Continue reading non-sensitive config from the ConfigMap (as env vars is OK for non-sensitive data)
   - Read `DB_USER` and `DB_PASSWORD` from the Secret, mounted as **files** (not env vars) at `/etc/secrets/`
4. **Verify** the credentials are not visible in `kubectl describe pod` or `env` output

### Part 2: Add Network Isolation

5. **Create a NetworkPolicy** that prevents the `learn-frontend` pods from directly accessing the `learn-db` Service. Only `learn-app` pods should be able to reach the database on port 5432.

**Note:** NetworkPolicy enforcement requires a CNI that supports it (Calico, Cilium). In kind clusters with the default CNI, the policy object will be created but may not be enforced. The verification script checks that the policy exists and has the correct rules.

---

## Success Criteria

- `app-config` ConfigMap does NOT contain `DB_USER` or `DB_PASSWORD`
- A Secret named `db-credentials` exists with `DB_USER` and `DB_PASSWORD`
- The `learn-app` pod mounts the Secret as files at `/etc/secrets/`
- `kubectl exec learn-app -- env | grep DB_PASSWORD` returns nothing
- `kubectl exec learn-app -- cat /etc/secrets/DB_PASSWORD` returns the password
- A NetworkPolicy exists that restricts database access to `learn-app` pods only

---

## Hints

<details>
<summary>Hint 1: Creating the Secret and updating the ConfigMap</summary>

Create the Secret:

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=nocap_admin \
  --from-literal=DB_PASSWORD='Lat73sAndL0gs!' \
  -n learn-ch15
```

Update the ConfigMap to remove credentials:

```bash
kubectl edit configmap app-config -n learn-ch15
# Remove the DB_USER and DB_PASSWORD lines
```

Or delete and recreate the ConfigMap without the sensitive fields.

</details>

<details>
<summary>Hint 2: Mounting the Secret as files</summary>

Update the `learn-app` Deployment to mount the Secret as a volume:

```yaml
spec:
  containers:
    - name: app
      envFrom:
        - configMapRef:
            name: app-config     # Non-sensitive config stays as env vars
      volumeMounts:
        - name: db-creds
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: db-creds
      secret:
        secretName: db-credentials
        defaultMode: 0400
```

Remove any `env` entries that reference the Secret as environment variables. The credentials are now only available as files.

</details>

<details>
<summary>Hint 3: Creating the NetworkPolicy</summary>

Create a NetworkPolicy on the database that only allows ingress from `learn-app`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-access-policy
  namespace: learn-ch15
spec:
  podSelector:
    matchLabels:
      app: learn-db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: learn-app
      ports:
        - protocol: TCP
          port: 5432
```

This allows only `learn-app` pods to reach the database on port 5432. The `learn-frontend` pods (which have label `app: learn-frontend`, not `app: learn-app`) are blocked.

</details>

---

## Verification

```bash
bash curriculum/world-4-kubernetes-production/ch15-k8s-security/challenges/verify.sh
```

Or manually:

```bash
# ConfigMap should not contain credentials
kubectl get configmap app-config -n learn-ch15 -o yaml | grep -E "DB_PASSWORD|DB_USER"
# Should return nothing

# Secret should exist
kubectl get secret db-credentials -n learn-ch15

# Credentials should be mounted as files, not in env
kubectl exec deploy/learn-app -n learn-ch15 -- env | grep DB_PASSWORD
# Should return nothing

kubectl exec deploy/learn-app -n learn-ch15 -- cat /etc/secrets/DB_PASSWORD
# Should return the password

# NetworkPolicy should exist
kubectl get networkpolicy -n learn-ch15
```

---

> **Sarah:** "Credentials moved from env vars to mounted files. ConfigMap cleaned of sensitive data. Database access restricted to the API layer. Three changes, each one closing a real attack vector the audit flagged."

**Finished with Chapter 15 challenges!** Run the full verify script, then take the [Quiz](../quiz.md).
