# Challenge 1: Diagnose with Metrics

> **Sarah:** "A customer reports the coffee recommendation engine is slow. Your pods are healthy. CPU is normal. Memory is fine. But latency has tripled. Time to look at the metrics — not the surface-level ones."

---

## The Situation

The NoCappuccino recommendation API has been deployed. Health probes pass. CPU and memory are within limits. But request latency has increased from ~200ms to ~2 seconds, and customers are complaining.

Your job: deploy Prometheus, examine the metrics, and find the bottleneck.

---

## Setup

### Step 1: Create the Namespace

```bash
kubectl create namespace learn-ch16
kubectl label namespace learn-ch16 app=learn-docker-k8s world=w05 chapter=ch16
```

### Step 2: Deploy Prometheus + Grafana

Install kube-prometheus-stack via Helm:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install learn-prometheus prometheus-community/kube-prometheus-stack \
  --namespace learn-ch16 \
  --set grafana.adminPassword=learn \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --wait --timeout 5m
```

Wait for all pods to be running:

```bash
kubectl get pods -n learn-ch16 -w
```

### Step 3: Deploy the Slow Application

Save the following as `slow-app.yaml` and apply it:

```yaml
# A simple application that exposes Prometheus metrics
# It has a simulated slow database query that causes high latency
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-recommendation-api
  namespace: learn-ch16
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch16
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-recommendation-api
  template:
    metadata:
      labels:
        app: learn-recommendation-api
        world: w05
        chapter: ch16
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: api
          image: nginx:1.25
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "250m"
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: learn-recommendation-api
  namespace: learn-ch16
  labels:
    app: learn-recommendation-api
spec:
  selector:
    app: learn-recommendation-api
  ports:
    - port: 80
      targetPort: 8080
      name: http
```

```bash
kubectl apply -f slow-app.yaml
```

### Step 4: Verify Deployment

```bash
kubectl get pods -n learn-ch16 -l app=learn-recommendation-api
kubectl get svc -n learn-ch16 learn-recommendation-api
```

---

## Your Mission

1. **Access Prometheus** and verify it can scrape targets in the cluster.

```bash
kubectl port-forward svc/learn-prometheus-kube-prom-prometheus -n learn-ch16 9090:9090
```

Open http://localhost:9090/targets and confirm targets are being scraped.

2. **Explore available metrics.** In the Prometheus UI (http://localhost:9090/graph), run these queries to explore what's available:

```promql
# Pod CPU usage in the learn-ch16 namespace
sum(rate(container_cpu_usage_seconds_total{namespace="learn-ch16",container!=""}[5m])) by (pod)

# Pod memory usage
sum(container_memory_working_set_bytes{namespace="learn-ch16",container!=""}) by (pod)

# Pod restart count
sum(kube_pod_container_status_restarts_total{namespace="learn-ch16"}) by (pod)

# Deployment desired vs available replicas
kube_deployment_status_replicas_available{namespace="learn-ch16"}
```

3. **Investigate the scenario.** The recommendation API's CPU and memory look normal. The issue is at the application level — simulated by the slow response patterns.

   Examine these infrastructure metrics and confirm they do NOT explain the latency:
   - CPU usage per pod (should be low)
   - Memory usage per pod (should be well within limits)
   - Pod restart count (should be zero)

4. **Understand the diagnosis.** Since infrastructure metrics look healthy but latency is high, this is an **application-level problem** — not a resource problem. The metrics confirm what customers reported: the system is "healthy" by infrastructure standards but slow by user-experience standards.

   Write down your diagnosis: what the metrics showed, what they didn't show, and what additional instrumentation (application-level metrics) would be needed to pinpoint the exact bottleneck (e.g., a slow database query, a slow external call).

5. **Create a ConfigMap** named `learn-diagnosis` in `learn-ch16` with your findings:

```bash
kubectl create configmap learn-diagnosis \
  --from-literal=finding="Infrastructure metrics (CPU, memory, restarts) are normal. The bottleneck is at the application level, not the infrastructure level. Application-level metrics (request duration histograms, database query duration) are needed to identify the specific slow operation." \
  --from-literal=method="RED" \
  --from-literal=missing_metric="http_request_duration_seconds histogram" \
  -n learn-ch16
```

---

## Success Criteria

- [ ] Prometheus is deployed and running in `learn-ch16`
- [ ] You can access the Prometheus UI and see active scrape targets
- [ ] The `learn-recommendation-api` Deployment is running with 2 healthy pods
- [ ] A ConfigMap named `learn-diagnosis` exists in `learn-ch16` with your findings
- [ ] The ConfigMap contains keys: `finding`, `method`, and `missing_metric`

---

## Hints

<details>
<summary>Hint 1: Prometheus isn't scraping my app</summary>

Check the Prometheus targets page at http://localhost:9090/targets. If your app isn't listed, verify the pod annotations match what Prometheus expects. The kube-prometheus-stack uses ServiceMonitor CRDs by default, but also supports annotation-based discovery when configured.

For this challenge, the key metrics come from kube-state-metrics and cAdvisor (container metrics), which are already being scraped by default.

</details>

<details>
<summary>Hint 2: What should I look for in the metrics?</summary>

The point of this challenge is recognizing what metrics CAN'T tell you. Infrastructure metrics (CPU, memory) show the hardware is fine. But they don't show application-level behavior (request latency, database query time, external service calls).

This is why applications need to expose their own `/metrics` endpoint with RED method metrics: Rate, Errors, Duration.

</details>

<details>
<summary>Hint 3: How do I create the diagnosis ConfigMap?</summary>

The diagnosis should state that infrastructure metrics are healthy, the bottleneck is application-level, and the RED method would require a `http_request_duration_seconds` histogram metric from the application to identify the specific slow operation.

```bash
kubectl create configmap learn-diagnosis \
  --from-literal=finding="Infrastructure metrics normal. Application-level metrics needed." \
  --from-literal=method="RED" \
  --from-literal=missing_metric="http_request_duration_seconds histogram" \
  -n learn-ch16
```

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch16-observability/challenges/verify.sh
```

---

> **Sarah:** "You just learned the most important lesson in observability: healthy infrastructure doesn't mean healthy application. CPU and memory being normal while latency triples is the most common 'invisible' production issue. The RED method exists specifically because infrastructure metrics aren't enough."

**Next:** [Challenge 02 — Trace the Request](02-trace-the-request.md)
