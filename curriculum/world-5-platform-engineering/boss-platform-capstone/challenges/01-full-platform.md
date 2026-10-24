# Boss Fight: The Full Platform

> **Sarah:** "Source code to production. Build, deploy, monitor, release, and handle an incident. All of it. One scenario. No training wheels."

---

## Mission Overview

```
Phase 1: BUILD     Build and tag an image properly
Phase 2: DEPLOY    Deploy to K8s with Helm + health probes
Phase 3: MONITOR   Verify Prometheus is scraping, check dashboard
Phase 4: RELEASE   Rolling update to v2 while monitoring
Phase 5: INCIDENT  v2 has a problem — triage, mitigate, document
Phase 6: DOCUMENT  Write the postmortem
```

---

## Setup

```bash
kubectl create namespace learn-boss-w5
kubectl label namespace learn-boss-w5 app=learn-docker-k8s world=w05 chapter=boss
```

Ensure Prometheus is running (from Chapter 16):

```bash
kubectl get pods -n learn-ch16 | grep prometheus
# If not running, re-install from Chapter 16 instructions
```

---

## Phase 1: Build — Properly Tagged Image

### Create the Application

Create a directory `boss-app/` with:

**boss-app/Dockerfile:**

```dockerfile
FROM nginx:1.25-alpine
COPY index.html /usr/share/nginx/html/index.html
HEALTHCHECK --interval=10s --timeout=3s CMD wget -q --spider http://localhost/ || exit 1
EXPOSE 80
```

**boss-app/index.html:**

```html
<!DOCTYPE html>
<html><body>
<h1>NoCappuccino Bean Subscriptions</h1>
<p>Version: 1.0.0</p>
<p>Status: Healthy</p>
</body></html>
```

### Build and Tag

```bash
cd boss-app
git init && git add . && git commit -m "feat: bean subscription service v1.0.0"

GIT_SHA=$(git rev-parse --short HEAD)
VERSION="1.0.0"

# Build with both tags
docker build -t localhost:5001/learn-boss-app:${GIT_SHA} .
docker tag localhost:5001/learn-boss-app:${GIT_SHA} localhost:5001/learn-boss-app:${VERSION}

# Push both
docker push localhost:5001/learn-boss-app:${GIT_SHA}
docker push localhost:5001/learn-boss-app:${VERSION}
```

If using kind without a local registry, load the image:

```bash
kind load docker-image localhost:5001/learn-boss-app:${GIT_SHA} --name learn-k8s
kind load docker-image localhost:5001/learn-boss-app:${VERSION} --name learn-k8s
```

### Success Criteria — Phase 1
- [ ] Image built from a Dockerfile with a HEALTHCHECK
- [ ] Tagged with git SHA AND semver (not `latest`)
- [ ] Pushed to registry (or loaded into kind)

---

## Phase 2: Deploy — Helm Chart with Health Probes

### Create the Helm Chart

```bash
helm create learn-boss-chart
```

Customize the chart:

**learn-boss-chart/values.yaml:**

```yaml
replicaCount: 3

image:
  repository: localhost:5001/learn-boss-app
  tag: "1.0.0"
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

readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10

strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0

labels:
  app: learn-docker-k8s
  world: w05
  chapter: boss
```

Make sure the `templates/deployment.yaml` uses `readinessProbe`, `livenessProbe`, and `strategy` from values. (The scaffolded template may need adjustment.)

### Deploy

```bash
helm install learn-boss ./learn-boss-chart \
  --namespace learn-boss-w5 \
  --set fullnameOverride=learn-boss-app
```

### Verify

```bash
kubectl get deployment learn-boss-app -n learn-boss-w5
kubectl get pods -n learn-boss-w5 -l app.kubernetes.io/instance=learn-boss
# All 3 pods should be Running and Ready
```

### Success Criteria — Phase 2
- [ ] Helm release `learn-boss` exists in `learn-boss-w5`
- [ ] 3 replicas running and ready
- [ ] Readiness and liveness probes configured
- [ ] Rolling update strategy with `maxUnavailable: 0`

---

## Phase 3: Monitor — Verify Observability

### Confirm Prometheus is scraping

```bash
kubectl port-forward svc/learn-prometheus-kube-prom-prometheus -n learn-ch16 9090:9090
```

Open http://localhost:9090 and run a query to verify your boss-app pods are visible:

```promql
kube_pod_status_phase{namespace="learn-boss-w5",phase="Running"}
```

### Check the Dashboard

If Grafana is running (from Ch16), verify you can see the `learn-boss-w5` namespace metrics:

```promql
sum(container_memory_working_set_bytes{namespace="learn-boss-w5",container!=""}) by (pod)
```

### Success Criteria — Phase 3
- [ ] Prometheus can query metrics from `learn-boss-w5` namespace
- [ ] Pod status, CPU, and memory metrics are visible

---

## Phase 4: Release — Rolling Update to v2

### Build v2

Create a new version of the app. Update `boss-app/index.html`:

```html
<!DOCTYPE html>
<html><body>
<h1>NoCappuccino Bean Subscriptions</h1>
<p>Version: 2.0.0</p>
<p>Status: Healthy</p>
<p>NEW: Personalized bean recommendations!</p>
</body></html>
```

Build and push v2:

```bash
cd boss-app
git add . && git commit -m "feat: v2.0.0 personalized recommendations"
GIT_SHA_V2=$(git rev-parse --short HEAD)

docker build -t localhost:5001/learn-boss-app:2.0.0 .
docker push localhost:5001/learn-boss-app:2.0.0

# Or for kind:
kind load docker-image localhost:5001/learn-boss-app:2.0.0 --name learn-k8s
```

### Deploy v2 via Helm Upgrade

```bash
helm upgrade learn-boss ./learn-boss-chart \
  --namespace learn-boss-w5 \
  --set fullnameOverride=learn-boss-app \
  --set image.tag=2.0.0
```

Watch the rolling update:

```bash
kubectl rollout status deployment/learn-boss-app -n learn-boss-w5
kubectl get pods -n learn-boss-w5 -w
```

### Success Criteria — Phase 4
- [ ] v2.0.0 deployed via `helm upgrade`
- [ ] Rolling update completed with zero downtime (maxUnavailable: 0)
- [ ] All pods running the new image

---

## Phase 5: INCIDENT — The Memory Leak

🔴 **ALERT: Something is wrong with v2.**

Shortly after the v2 rollout, you notice (simulated):
- Pod restarts are increasing
- Memory usage is climbing toward limits

Simulate the incident by deploying a broken v3 that has insufficient resources:

```bash
helm upgrade learn-boss ./learn-boss-chart \
  --namespace learn-boss-w5 \
  --set fullnameOverride=learn-boss-app \
  --set image.tag=2.0.0 \
  --set resources.limits.memory="8Mi" \
  --set resources.requests.memory="4Mi"
```

Wait for the problem to manifest:

```bash
kubectl get pods -n learn-boss-w5 -w
# Pods will start OOMKilled / CrashLoopBackOff
```

### Your Response

Follow the incident response process:

1. **Triage:** Check pod status, events, describe the failing pods
2. **Identify:** Find the OOMKilled pods and the memory limit that's too low
3. **Mitigate:** Roll back with Helm:

```bash
# Check history
helm history learn-boss -n learn-boss-w5

# Roll back to the last good revision
helm rollback learn-boss <good-revision> -n learn-boss-w5
```

4. **Verify recovery:**

```bash
kubectl get pods -n learn-boss-w5
# All pods should be Running and stable
```

### Success Criteria — Phase 5
- [ ] Identified the OOMKilled problem
- [ ] Rolled back using `helm rollback`
- [ ] All pods recovered to Running state
- [ ] No pods in CrashLoopBackOff or OOMKilled

---

## Phase 6: Document — The Postmortem

Write a postmortem for the entire boss fight scenario:

```bash
kubectl create configmap learn-boss-postmortem \
  --from-literal=summary="During the v2.0.0 rollout of the bean subscription service, a configuration error reduced memory limits to 8Mi, causing OOMKilled pods. The rolling update replaced healthy v2 pods with broken ones. Mitigated by Helm rollback to the previous revision." \
  --from-literal=severity="SEV2" \
  --from-literal=timeline="Phase 1-4: Built, tagged, deployed, monitored, and upgraded successfully. Phase 5: Memory limit misconfiguration caused OOMKilled. Detected within 2 minutes via pod restarts. Rolled back via helm rollback within 5 minutes. All pods healthy." \
  --from-literal=root_cause="Memory resource limits were set to 8Mi during the upgrade, which is below the nginx minimum. The Helm values override reduced limits without validation." \
  --from-literal=action_items="1. [P1] Add resource limit validation to Helm chart (minimum thresholds). 2. [P1] Add pre-upgrade dry-run check that verifies resource values. 3. [P2] Set up Prometheus alert for OOMKilled events. 4. [P2] Add memory usage to rolling update canary criteria." \
  --from-literal=lessons_learned="Build pipeline and tagging worked well. Helm rollback was fast and effective. The gap: no validation on resource values during upgrade. Need automated guardrails." \
  -n learn-boss-w5
```

### Success Criteria — Phase 6
- [ ] ConfigMap `learn-boss-postmortem` exists with all sections
- [ ] Postmortem covers: summary, severity, timeline, root cause, action items, lessons

---

## Final Verification

```bash
bash curriculum/world-5-platform-engineering/boss-platform-capstone/challenges/verify.sh
```

---

## Graduation

If all checks pass, you've completed World 5 — and the entire Learn Docker & Kubernetes curriculum.

```
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │   🏆  WORLD 5 COMPLETE: Platform Engineering                 │
  │                                                              │
  │   You built a container image with proper tags.              │
  │   You deployed it with Helm to a Kubernetes cluster.         │
  │   You monitored it with Prometheus.                          │
  │   You performed a controlled rolling update.                 │
  │   You handled a production incident mid-rollout.             │
  │   You wrote the postmortem.                                  │
  │                                                              │
  │   From "docker run hello-world" to a full platform.          │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

---

> **Sarah:** "Look at what you just did. You took an application from source code to production, monitored it, released a new version, handled an incident mid-rollout, rolled back in under 5 minutes, and wrote the postmortem. That's not a tutorial. That's the job. Welcome to platform engineering."
>
> **Dave:** "Wait, we have a platform now? Since when?"
>
> **Marcus:** "Since they built it. While you were getting coffee."
>
> **Sarah:** (★‿★) "Typical."
