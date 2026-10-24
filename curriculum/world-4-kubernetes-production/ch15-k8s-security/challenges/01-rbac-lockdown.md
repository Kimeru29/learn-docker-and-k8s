# Challenge 1: RBAC Lockdown

> **Sarah:** "The monitoring team needs read access to pods in our namespace — but nothing else. No creating, no deleting, no secrets, no access to other namespaces. Let's build them a ServiceAccount with exactly the permissions they need and verify it can't do anything it shouldn't."

---

## The Situation

The monitoring system needs a ServiceAccount that can read pod information in the `learn-ch15` namespace. Currently, it uses the `default` ServiceAccount, which has broader access than necessary.

Your job: create a ServiceAccount with the minimum permissions needed, and verify it cannot exceed those permissions.

---

## Setup

```bash
kubectl create namespace learn-ch15
```

Apply a test deployment (something for the monitoring SA to read):

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: learn-ch15
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: ch15
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-api
  template:
    metadata:
      labels:
        app: learn-api
        world: w04
        chapter: ch15
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
EOF
```

---

## Your Mission

1. **Create a ServiceAccount** named `pod-reader` in namespace `learn-ch15`

2. **Create a Role** named `pod-reader-role` in namespace `learn-ch15` that allows:
   - `get`, `list`, `watch` on `pods`
   - Nothing else (no `create`, no `delete`, no `secrets`, no `deployments`)

3. **Create a RoleBinding** named `pod-reader-binding` that binds the Role to the ServiceAccount

4. **Verify** the permissions:
   - `pod-reader` CAN get and list pods in `learn-ch15`
   - `pod-reader` CANNOT create or delete pods in `learn-ch15`
   - `pod-reader` CANNOT get secrets in `learn-ch15`
   - `pod-reader` CANNOT get pods in the `default` namespace

---

## Verification Commands

Use `kubectl auth can-i` to test each permission:

```bash
# Should return "yes"
kubectl auth can-i get pods \
  --as=system:serviceaccount:learn-ch15:pod-reader \
  -n learn-ch15

kubectl auth can-i list pods \
  --as=system:serviceaccount:learn-ch15:pod-reader \
  -n learn-ch15

# Should return "no"
kubectl auth can-i create pods \
  --as=system:serviceaccount:learn-ch15:pod-reader \
  -n learn-ch15

kubectl auth can-i delete pods \
  --as=system:serviceaccount:learn-ch15:pod-reader \
  -n learn-ch15

kubectl auth can-i get secrets \
  --as=system:serviceaccount:learn-ch15:pod-reader \
  -n learn-ch15

kubectl auth can-i get pods \
  --as=system:serviceaccount:learn-ch15:pod-reader \
  -n default
```

---

## Hints

<details>
<summary>Hint 1: Creating the ServiceAccount</summary>

```bash
kubectl create serviceaccount pod-reader -n learn-ch15
```

Or apply a YAML manifest:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reader
  namespace: learn-ch15
```

</details>

<details>
<summary>Hint 2: Creating the Role</summary>

```bash
kubectl create role pod-reader-role \
  --verb=get,list,watch \
  --resource=pods \
  -n learn-ch15
```

Or as YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader-role
  namespace: learn-ch15
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

</details>

<details>
<summary>Hint 3: Creating the RoleBinding</summary>

```bash
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader-role \
  --serviceaccount=learn-ch15:pod-reader \
  -n learn-ch15
```

Or as YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: learn-ch15
subjects:
  - kind: ServiceAccount
    name: pod-reader
    namespace: learn-ch15
roleRef:
  kind: Role
  name: pod-reader-role
  apiGroup: rbac.authorization.k8s.io
```

</details>

---

## Verification

```bash
bash curriculum/world-4-kubernetes-production/ch15-k8s-security/challenges/verify.sh
```

---

> **Sarah:** "That's least privilege in action. The monitoring SA can see pods — that's all it needs. It can't touch secrets, can't delete anything, can't see other namespaces. If that ServiceAccount token is ever compromised, the blast radius is minimal."

**Next:** [Challenge 02 — Harden Pods](02-harden-pods.md)
