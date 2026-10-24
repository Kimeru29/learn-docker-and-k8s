# Challenge 1: Tag Strategy

> **Sarah:** "Dave's last deploy used `latest`. Before that, `latest`. Before that? Also `latest`. Three different versions, same tag. Let's fix that forever."

---

## The Situation

You need to build a container image with a proper tagging strategy, push it to a local registry, and deploy it to Kubernetes using the specific tag — not `latest`.

---

## Setup

### Step 1: Create the Namespace

```bash
kubectl create namespace learn-ch17
kubectl label namespace learn-ch17 app=learn-docker-k8s world=w05 chapter=ch17
```

### Step 2: Set Up a Local Registry

```bash
# Start a local registry (if not already running)
docker run -d --restart=always -p 5001:5000 --name learn-registry registry:2 2>/dev/null || true

# Connect it to the kind network so the cluster can pull from it
docker network connect kind learn-registry 2>/dev/null || true
```

### Step 3: Create a Simple Application

Create a directory called `learn-tag-app` and add a Dockerfile:

```bash
mkdir -p learn-tag-app
```

Create `learn-tag-app/Dockerfile`:

```dockerfile
FROM nginx:1.25-alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

Create `learn-tag-app/index.html`:

```html
<!DOCTYPE html>
<html>
<body>
<h1>NoCappuccino Recommendation API</h1>
<p>Version: BUILD_VERSION</p>
</body>
</html>
```

### Step 4: Initialize a Git Repo

```bash
cd learn-tag-app
git init
git add .
git commit -m "feat: initial NoCappuccino recommendation API"
```

---

## Your Mission

1. **Get the Git SHA** for the current commit:

```bash
GIT_SHA=$(git rev-parse --short HEAD)
echo "Git SHA: $GIT_SHA"
```

2. **Choose a semver version** for this release: `1.0.0`

3. **Build the image** with both tags:

```bash
docker build -t localhost:5001/learn-nocappuccino-api:${GIT_SHA} .
docker tag localhost:5001/learn-nocappuccino-api:${GIT_SHA} localhost:5001/learn-nocappuccino-api:1.0.0
```

4. **Push both tags** to the local registry:

```bash
docker push localhost:5001/learn-nocappuccino-api:${GIT_SHA}
docker push localhost:5001/learn-nocappuccino-api:1.0.0
```

5. **Deploy to Kubernetes** using the **git SHA tag** (not `latest`, not even the semver tag — the SHA is the most precise):

Create `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-nocappuccino-api
  namespace: learn-ch17
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch17
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-nocappuccino-api
  template:
    metadata:
      labels:
        app: learn-nocappuccino-api
        world: w05
        chapter: ch17
    spec:
      containers:
        - name: api
          image: localhost:5001/learn-nocappuccino-api:YOUR_GIT_SHA_HERE
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
  name: learn-nocappuccino-api
  namespace: learn-ch17
spec:
  selector:
    app: learn-nocappuccino-api
  ports:
    - port: 80
      targetPort: 80
```

**Important:** Replace `YOUR_GIT_SHA_HERE` with the actual git SHA before applying.

```bash
kubectl apply -f deployment.yaml
```

6. **Verify** the exact image is running:

```bash
kubectl get pods -n learn-ch17 -o jsonpath='{.items[*].spec.containers[*].image}'
```

The output should show your git SHA tag, NOT `latest`.

---

## Success Criteria

- [ ] Local registry (`learn-registry`) is running
- [ ] Image pushed with a git SHA tag to `localhost:5001/learn-nocappuccino-api`
- [ ] Image pushed with a semver tag (`1.0.0`) to `localhost:5001/learn-nocappuccino-api`
- [ ] Deployment `learn-nocappuccino-api` exists in `learn-ch17` with 2 replicas
- [ ] Pods are running an image with a specific tag (not `latest`)
- [ ] Service `learn-nocappuccino-api` exists in `learn-ch17`

---

## Hints

<details>
<summary>Hint 1: The local registry isn't reachable from kind</summary>

If kind can't pull from the local registry, you may need to configure it. Check that the registry is connected to the `kind` network:

```bash
docker network inspect kind | grep learn-registry
```

If the registry isn't on the kind network:

```bash
docker network connect kind learn-registry
```

You can also use `kind load docker-image` as an alternative to a registry:

```bash
kind load docker-image localhost:5001/learn-nocappuccino-api:${GIT_SHA} --name learn-k8s
```

</details>

<details>
<summary>Hint 2: How to replace the tag in the YAML</summary>

Use `sed` to replace the placeholder:

```bash
sed "s/YOUR_GIT_SHA_HERE/${GIT_SHA}/" deployment.yaml | kubectl apply -f -
```

Or just edit the file manually with your actual SHA.

</details>

<details>
<summary>Hint 3: Verifying the image tag</summary>

```bash
# Check what image the pods are running
kubectl get pods -n learn-ch17 -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# Should show something like:
# learn-nocappuccino-api-abc123  localhost:5001/learn-nocappuccino-api:7e4f2d1
```

If you see `:latest`, you forgot to set the tag.

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch17-delivery/challenges/verify.sh
```

---

> **Sarah:** "Look at that: every pod is running a specific, traceable version. If something breaks, you know exactly what commit is deployed. If you need to roll back, you know exactly what tag to deploy. No more 'which latest?'"

**Next:** [Challenge 02 — Helm Deploy](02-helm-deploy.md)
