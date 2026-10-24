# Challenge 3: GitOps Simulation

> **Sarah:** "Full ArgoCD is overkill for a learning exercise. But the GitOps principle — Git as the source of truth, with reconciliation — we can demonstrate that right now."

---

## The Situation

You'll set up a simplified GitOps workflow:

1. A local Git repository acts as the "source of truth" for K8s manifests
2. You deploy from that repo (simulating the GitOps controller)
3. You make a change in Git, and the cluster updates
4. You introduce a bad change, and roll back via `git revert`

This demonstrates the core GitOps loop without requiring a full ArgoCD installation.

---

## Setup

### Create the GitOps Repo

```bash
mkdir -p learn-gitops-repo/apps/api
cd learn-gitops-repo
git init
```

### Create the Base Manifests

Create `apps/api/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-gitops-api
  namespace: learn-ch17
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch17
    managed-by: gitops
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-gitops-api
  template:
    metadata:
      labels:
        app: learn-gitops-api
        world: w05
        chapter: ch17
    spec:
      containers:
        - name: api
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
```

Create `apps/api/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-gitops-api
  namespace: learn-ch17
  labels:
    app: learn-docker-k8s
    managed-by: gitops
spec:
  selector:
    app: learn-gitops-api
  ports:
    - port: 80
      targetPort: 80
```

### Initial Commit

```bash
git add .
git commit -m "feat: initial API deployment - 2 replicas, nginx:1.25-alpine"
```

---

## Your Mission

### Part 1: Initial Deploy from Git

Simulate the GitOps controller by applying everything from the repo:

```bash
kubectl apply -f apps/api/ -n learn-ch17
```

Verify:

```bash
kubectl get deployment learn-gitops-api -n learn-ch17
kubectl get pods -n learn-ch17 -l app=learn-gitops-api
```

You should see 2 pods running `nginx:1.25-alpine`.

### Part 2: Make a Change via Git

Update the Deployment to scale to 3 replicas. Edit `apps/api/deployment.yaml`:

```yaml
spec:
  replicas: 3   # Changed from 2 to 3
```

Commit the change:

```bash
git add .
git commit -m "scale: increase API replicas to 3 for traffic spike"
```

Now "reconcile" (simulate the controller detecting the Git change):

```bash
kubectl apply -f apps/api/ -n learn-ch17
```

Verify the cluster updated:

```bash
kubectl get deployment learn-gitops-api -n learn-ch17
# Should show 3/3 replicas
```

### Part 3: Detect and Revert Drift

Simulate someone making a manual change (drift):

```bash
kubectl scale deployment learn-gitops-api --replicas=1 -n learn-ch17
```

Check the drift:

```bash
# Cluster says 1 replica
kubectl get deployment learn-gitops-api -n learn-ch17

# Git says 3 replicas
grep "replicas:" apps/api/deployment.yaml
```

Reconcile from Git (like a GitOps controller would):

```bash
kubectl apply -f apps/api/ -n learn-ch17
```

Verify drift was corrected:

```bash
kubectl get deployment learn-gitops-api -n learn-ch17
# Should be back to 3 replicas
```

### Part 4: Bad Deploy + Git Rollback

Introduce a bad change — deploy an image that doesn't exist:

```bash
# Edit apps/api/deployment.yaml — change image to a nonexistent tag
sed -i.bak 's/nginx:1.25-alpine/nginx:99.99.99-does-not-exist/' apps/api/deployment.yaml

git add .
git commit -m "feat: upgrade to nginx 99.99.99 (oops)"

# Apply
kubectl apply -f apps/api/ -n learn-ch17
```

Wait a moment and check:

```bash
kubectl get pods -n learn-ch17 -l app=learn-gitops-api
# Some pods should be in ImagePullBackOff or ErrImagePull
```

Now roll back via Git — just like a real GitOps workflow:

```bash
git revert HEAD --no-edit
# This creates a new commit that undoes the bad change

# Apply the reverted state
kubectl apply -f apps/api/ -n learn-ch17
```

Verify recovery:

```bash
kubectl get pods -n learn-ch17 -l app=learn-gitops-api
# Should return to healthy nginx:1.25-alpine pods
```

### Part 5: Record the Audit Trail

Check the Git log — this IS your deployment history:

```bash
git log --oneline
```

You should see something like:

```
abc1234 Revert "feat: upgrade to nginx 99.99.99 (oops)"
def5678 feat: upgrade to nginx 99.99.99 (oops)
ghi9012 scale: increase API replicas to 3 for traffic spike
jkl3456 feat: initial API deployment - 2 replicas, nginx:1.25-alpine
```

Every deployment, every change, every rollback — all in Git with author, timestamp, and description.

Create a ConfigMap to record the audit trail:

```bash
GIT_LOG=$(cd learn-gitops-repo && git log --oneline 2>/dev/null || echo "see learn-gitops-repo")
kubectl create configmap learn-gitops-audit \
  --from-literal=strategy="gitops-simulation" \
  --from-literal=source_of_truth="git-repo" \
  --from-literal=rollback_method="git-revert" \
  --from-literal=total_commits="$(cd learn-gitops-repo && git rev-list --count HEAD 2>/dev/null || echo 4)" \
  -n learn-ch17
```

---

## Success Criteria

- [ ] Deployment `learn-gitops-api` exists in `learn-ch17` with `managed-by: gitops` label
- [ ] The deployment is running with healthy pods (not in ImagePullBackOff)
- [ ] The deployment has 3 replicas (the post-scale state)
- [ ] The image is `nginx:1.25-alpine` (the post-revert state)
- [ ] ConfigMap `learn-gitops-audit` exists with the audit trail
- [ ] The local Git repo has at least 4 commits showing the deployment history

---

## Hints

<details>
<summary>Hint 1: sed works differently on macOS</summary>

On macOS, `sed -i` requires a backup extension:

```bash
# macOS
sed -i '.bak' 's/old/new/' file

# Linux
sed -i 's/old/new/' file
```

The challenge uses `sed -i.bak` which works on both. Delete the `.bak` file afterwards if it bothers you.

</details>

<details>
<summary>Hint 2: Pods stuck in ImagePullBackOff</summary>

After the bad deploy, Kubernetes will be trying to pull `nginx:99.99.99-does-not-exist`. When you apply the reverted manifest (back to `nginx:1.25-alpine`), the Deployment controller will create new pods with the correct image and terminate the broken ones.

If old pods linger, wait a moment — the rolling update will replace them.

</details>

<details>
<summary>Hint 3: Where to create the Git repo</summary>

Create `learn-gitops-repo` in your working directory (wherever you've been running challenges). The verification script checks for the `learn-gitops-api` Deployment and `learn-gitops-audit` ConfigMap in the cluster, not the Git repo directly.

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch17-delivery/challenges/verify.sh
```

---

## Reflection

You just demonstrated the core GitOps loop:

1. **Git as source of truth** — manifests live in Git, not on laptops
2. **Declarative deployment** — `kubectl apply` from the repo, not imperative commands
3. **Reconciliation** — drift (manual scaling) was corrected from Git
4. **Rollback via Git** — `git revert` + apply, with a full audit trail
5. **Audit trail** — `git log` is your deployment history

In a real GitOps setup, ArgoCD or Flux replaces the manual `kubectl apply` steps. The controller watches Git continuously and applies changes automatically. But the principle is identical to what you just did.

---

> **Sarah:** "Look at that git log. Four entries. Each one tells you exactly what changed, when, and why. When the auditors ask 'who deployed the broken version and how was it fixed?' you don't check Slack — you check `git log`. That's GitOps."

**Next:** Take the [Chapter 17 Quiz](../quiz.md)
