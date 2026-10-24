# Challenge 2: Helm Deploy

> **Sarah:** "Same app, three environments, three different configs. With raw YAML, that's three files that will inevitably drift apart. With Helm, it's one chart and three values files."

---

## The Situation

Package the NoCappuccino API as a Helm chart. Deploy it to two simulated environments (dev and staging) with different configurations. Then upgrade the staging release and roll back.

---

## Setup

Make sure the `learn-ch17` namespace exists and you have a running image from Challenge 01 (or use `nginx:1.25-alpine` as a fallback).

---

## Your Mission

### Part 1: Create the Helm Chart

Create a chart from scratch:

```bash
helm create learn-nocappuccino
```

This scaffolds a chart directory. You'll customize it.

**Edit `learn-nocappuccino/Chart.yaml`:**

```yaml
apiVersion: v2
name: learn-nocappuccino
description: NoCappuccino coffee recommendation API
version: 0.1.0
appVersion: "1.0.0"
```

**Edit `learn-nocappuccino/values.yaml`** (these are defaults):

```yaml
replicaCount: 1

image:
  repository: nginx
  tag: "1.25-alpine"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  requests:
    memory: "32Mi"
    cpu: "50m"
  limits:
    memory: "64Mi"
    cpu: "100m"

config:
  logLevel: "info"
  appName: "NoCappuccino API"

labels:
  app: learn-docker-k8s
  world: w05
  chapter: ch17
```

**Edit `learn-nocappuccino/templates/deployment.yaml`** to use your values (the scaffolded template is fine — just make sure `image` and `resources` reference `.Values`).

### Part 2: Create Environment Values Files

Create `learn-nocappuccino/values-dev.yaml`:

```yaml
replicaCount: 1
config:
  logLevel: "debug"
  appName: "NoCappuccino API (DEV)"
resources:
  requests:
    memory: "32Mi"
    cpu: "50m"
  limits:
    memory: "64Mi"
    cpu: "100m"
```

Create `learn-nocappuccino/values-staging.yaml`:

```yaml
replicaCount: 2
config:
  logLevel: "info"
  appName: "NoCappuccino API (STAGING)"
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "250m"
```

### Part 3: Deploy to Dev

```bash
helm install learn-api-dev ./learn-nocappuccino \
  -f ./learn-nocappuccino/values-dev.yaml \
  --namespace learn-ch17 \
  --set fullnameOverride=learn-api-dev
```

Verify:

```bash
kubectl get deployment learn-api-dev -n learn-ch17
kubectl get pods -n learn-ch17 -l app.kubernetes.io/instance=learn-api-dev
```

### Part 4: Deploy to Staging

```bash
helm install learn-api-staging ./learn-nocappuccino \
  -f ./learn-nocappuccino/values-staging.yaml \
  --namespace learn-ch17 \
  --set fullnameOverride=learn-api-staging
```

Verify staging has 2 replicas:

```bash
kubectl get deployment learn-api-staging -n learn-ch17
```

### Part 5: Upgrade Staging

Upgrade the staging release with a new image tag:

```bash
helm upgrade learn-api-staging ./learn-nocappuccino \
  -f ./learn-nocappuccino/values-staging.yaml \
  --namespace learn-ch17 \
  --set fullnameOverride=learn-api-staging \
  --set image.tag="1.25"
```

Check the release history:

```bash
helm history learn-api-staging --namespace learn-ch17
```

You should see two revisions.

### Part 6: Rollback

Roll back to the previous version:

```bash
helm rollback learn-api-staging 1 --namespace learn-ch17
```

Verify the rollback:

```bash
helm history learn-api-staging --namespace learn-ch17
# Should show revision 3 (the rollback)
```

---

## Success Criteria

- [ ] Helm chart `learn-nocappuccino` exists with `Chart.yaml` and `values.yaml`
- [ ] Helm release `learn-api-dev` exists in `learn-ch17` with 1 replica
- [ ] Helm release `learn-api-staging` exists in `learn-ch17` with 2 replicas
- [ ] `helm history learn-api-staging` shows at least 2 revisions (upgrade + rollback counts)
- [ ] Both releases use the same chart with different values

---

## Hints

<details>
<summary>Hint 1: helm create generates too much — simplify it</summary>

The `helm create` scaffold includes ingress, service account, HPA, and tests you don't need. You can delete the extra templates:

```bash
rm learn-nocappuccino/templates/ingress.yaml
rm learn-nocappuccino/templates/hpa.yaml
rm learn-nocappuccino/templates/serviceaccount.yaml
rm -rf learn-nocappuccino/templates/tests/
```

Keep `deployment.yaml`, `service.yaml`, `_helpers.tpl`, and `NOTES.txt`.

</details>

<details>
<summary>Hint 2: Template rendering issues</summary>

If `helm install` fails with template errors, render the templates locally first:

```bash
helm template learn-api-dev ./learn-nocappuccino \
  -f ./learn-nocappuccino/values-dev.yaml \
  --set fullnameOverride=learn-api-dev
```

This shows you the rendered YAML without deploying. Check for YAML syntax issues.

</details>

<details>
<summary>Hint 3: Rollback isn't working</summary>

`helm rollback` expects a revision number:

```bash
# See available revisions
helm history learn-api-staging --namespace learn-ch17

# Rollback to revision 1
helm rollback learn-api-staging 1 --namespace learn-ch17
```

After rollback, `helm history` shows a new revision (3) that represents the rollback to revision 1's state.

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch17-delivery/challenges/verify.sh
```

---

> **Sarah:** "One chart, two environments, different configs. The dev has 1 replica with debug logging. Staging has 2 replicas with info logging. Production will have 5 replicas with warn logging — same chart, just another values file. And when that staging upgrade broke? Rollback in one command, not 45 minutes."

**Next:** [Challenge 03 — GitOps Simulation](03-gitops-simulation.md)
