# Challenge 3: Build a Dashboard

> **Sarah:** "Anyone can make a dashboard. The question is: can you build one that tells an on-call engineer what's broken in 5 seconds?"

---

## The Situation

Prometheus and Grafana are running. Metrics are being collected. But nobody has built a dashboard that answers the question: **"Is the NoCappuccino platform healthy right now?"**

Your job: create a Grafana dashboard that shows the key signals for the `learn-ch16` namespace.

---

## Setup

If you haven't already, ensure Prometheus and Grafana are running from Challenge 01.

Access Grafana:

```bash
kubectl port-forward svc/learn-prometheus-grafana -n learn-ch16 3000:80
```

Open http://localhost:3000 and log in with `admin` / `learn`.

---

## Your Mission

Create a Grafana dashboard called **"NoCappuccino Platform Health"** with the following panels. Each panel should use PromQL queries against the `learn-ch16` namespace.

### Required Panels

**Panel 1: Request Rate (if application metrics are available)**

If your application exposes `http_requests_total`, use:

```promql
sum(rate(http_requests_total{namespace="learn-ch16"}[5m])) by (service)
```

If application metrics are not available, use a container-level proxy:

```promql
# Container network receive rate (a proxy for incoming traffic)
sum(rate(container_network_receive_bytes_total{namespace="learn-ch16"}[5m])) by (pod)
```

**Panel 2: Pod Restart Count**

```promql
sum(kube_pod_container_status_restarts_total{namespace="learn-ch16"}) by (pod)
```

A rising restart count indicates instability. Healthy pods have zero restarts.

**Panel 3: Memory Usage per Pod**

```promql
sum(container_memory_working_set_bytes{namespace="learn-ch16",container!=""}) by (pod)
```

Show this alongside the memory limit:

```promql
sum(kube_pod_container_resource_limits{namespace="learn-ch16",resource="memory"}) by (pod)
```

**Panel 4: CPU Usage per Pod**

```promql
sum(rate(container_cpu_usage_seconds_total{namespace="learn-ch16",container!=""}[5m])) by (pod)
```

**Panel 5: Pod Status Overview**

```promql
# Running pods
count(kube_pod_status_phase{namespace="learn-ch16",phase="Running"})

# Not-running pods (any phase that isn't Running)
count(kube_pod_status_phase{namespace="learn-ch16",phase!="Running"})
```

Use a stat panel or gauge to show this prominently.

**Panel 6: Deployment Replica Health**

```promql
# Available replicas
kube_deployment_status_replicas_available{namespace="learn-ch16"}

# Desired replicas
kube_deployment_spec_replicas{namespace="learn-ch16"}
```

Show both — if available < desired, something is wrong.

---

## How to Create the Dashboard

### Option A: Grafana UI (Recommended for Learning)

1. In Grafana, click **+** → **New Dashboard**
2. Click **Add visualization**
3. Select the **Prometheus** data source
4. Enter the PromQL query
5. Set the panel title and choose visualization type (Time series, Stat, Gauge, Table)
6. Repeat for each panel
7. Save the dashboard as **"NoCappuccino Platform Health"**

### Option B: Dashboard JSON Export

After creating the dashboard in Grafana, export it as JSON:

1. Click the **Share** icon on the dashboard
2. Select **Export** → **Save to file**
3. Save the JSON file

Then create a ConfigMap with the dashboard JSON so it persists:

```bash
kubectl create configmap learn-dashboard \
  --from-file=dashboard.json=<path-to-exported-json> \
  -n learn-ch16
```

### Option C: Dashboard ConfigMap (for verification)

If you prefer, create a ConfigMap describing your dashboard panels:

```bash
kubectl create configmap learn-dashboard \
  --from-literal=dashboard_name="NoCappuccino Platform Health" \
  --from-literal=panel_1="request_rate_or_network_traffic" \
  --from-literal=panel_2="pod_restart_count" \
  --from-literal=panel_3="memory_usage_vs_limit" \
  --from-literal=panel_4="cpu_usage_per_pod" \
  --from-literal=panel_5="pod_status_overview" \
  --from-literal=panel_6="deployment_replica_health" \
  -n learn-ch16
```

---

## Success Criteria

- [ ] Grafana is accessible and a dashboard named "NoCappuccino Platform Health" exists (or a `learn-dashboard` ConfigMap with the panel descriptions)
- [ ] The dashboard covers: traffic/request rate, pod restarts, memory usage, CPU usage, pod status, and deployment health
- [ ] The dashboard can answer "is the system healthy?" in under 10 seconds

---

## Dashboard Review Checklist

Go through this checklist to make sure your dashboard is useful:

| ✅ | Question |
|----|----------|
| | Can you tell if pods are healthy at a glance? |
| | Can you see if any pods are restarting? |
| | Can you tell if memory usage is approaching limits? |
| | Can you see if CPU is under pressure? |
| | Can you tell if a Deployment has fewer replicas than desired? |
| | Is there anything on the dashboard that doesn't help with "is it healthy?" |

If any panel doesn't help answer the health question, remove it. If you're missing a signal that would help, add it.

---

## Hints

<details>
<summary>Hint 1: Which visualization type for each panel?</summary>

- **Request rate / traffic:** Time series (line graph)
- **Pod restarts:** Stat panel (single number, ideally with thresholds — green at 0, red at >0)
- **Memory usage:** Time series with two series (usage and limit) or a gauge showing percentage
- **CPU usage:** Time series (line graph)
- **Pod status:** Stat panel (count of running vs not-running)
- **Deployment health:** Table showing deployment name, desired, available

</details>

<details>
<summary>Hint 2: How to add threshold colors</summary>

In Grafana panel settings:
1. Go to the **Thresholds** section
2. Set a green threshold for normal values
3. Set a yellow/red threshold for concerning values

For pod restarts: green = 0, red = 1+
For memory usage percentage: green < 70%, yellow < 90%, red ≥ 90%

</details>

<details>
<summary>Hint 3: Quick ConfigMap creation</summary>

If you don't want to build the full Grafana dashboard, the ConfigMap approach works for verification:

```bash
kubectl create configmap learn-dashboard \
  --from-literal=dashboard_name="NoCappuccino Platform Health" \
  --from-literal=panel_1="request_rate_or_network_traffic" \
  --from-literal=panel_2="pod_restart_count" \
  --from-literal=panel_3="memory_usage_vs_limit" \
  --from-literal=panel_4="cpu_usage_per_pod" \
  --from-literal=panel_5="pod_status_overview" \
  --from-literal=panel_6="deployment_replica_health" \
  -n learn-ch16
```

</details>

---

## Verification

```bash
bash curriculum/world-5-platform-engineering/ch16-observability/challenges/verify.sh
```

---

## Reflection

A good dashboard is not about showing more data. It's about showing the **right** data.

The six panels you built follow the Four Golden Signals pattern (adapted for Kubernetes):
- **Traffic** → request rate / network traffic
- **Errors** → pod restarts, not-ready pods
- **Latency** → (requires application metrics, which you identified in Challenge 01)
- **Saturation** → memory and CPU relative to limits

When application-level metrics (RED method) are available, you'd add error rate and p99 latency panels. That's the gap between infrastructure observability and application observability — and now you know where the gap is.

---

> **Sarah:** "Save that dashboard. Next time someone says 'is production okay?' you don't check Slack — you check the dashboard. And if the dashboard says 'fine' but customers disagree, you now know it's a Lesson 01 problem: your dashboard is measuring the wrong thing."

**Next:** Take the [Chapter 16 Quiz](../quiz.md)
