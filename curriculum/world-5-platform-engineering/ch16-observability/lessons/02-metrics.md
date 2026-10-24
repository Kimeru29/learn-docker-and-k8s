# Lesson 2: Metrics

> **Sarah:** "Logs tell you what happened. Metrics tell you how much and how fast. When a customer says 'it's slow,' you need numbers — not stories."

---

## What Metrics Are

A metric is a **numeric measurement collected over time**. Unlike logs (which record individual events), metrics aggregate behavior into numbers you can graph, alert on, and compare.

Examples:

- **Total requests served:** 142,847 (and counting)
- **Current memory usage:** 312 MB
- **Request duration (p99):** 1.2 seconds
- **Error rate:** 0.3% of requests return 5xx

Metrics are cheap to store (they're just numbers with timestamps), fast to query, and the foundation of every monitoring dashboard you've ever seen.

---

## Metric Types

There are three fundamental metric types. Every monitoring system uses some variant of these.

### Counter

A number that **only goes up** (or resets to zero on restart).

```
http_requests_total{method="GET", path="/api/beans", status="200"} = 48293
http_requests_total{method="GET", path="/api/beans", status="500"} = 17
```

Use counters for:
- Total requests served
- Total errors
- Total bytes transferred
- Total orders placed

To get the **rate** (requests per second), you calculate the change over time. Prometheus does this with `rate()`.

### Gauge

A number that **goes up and down**.

```
node_memory_usage_bytes = 327155712
active_connections = 42
pods_running{namespace="learn-ch16"} = 5
```

Use gauges for:
- Current memory/CPU usage
- Number of active connections
- Queue depth
- Temperature (if you're monitoring actual roasters)

### Histogram

A metric that **samples observations into buckets** to show the distribution.

```
http_request_duration_seconds_bucket{le="0.1"} = 24054
http_request_duration_seconds_bucket{le="0.25"} = 33421
http_request_duration_seconds_bucket{le="0.5"} = 41237
http_request_duration_seconds_bucket{le="1.0"} = 44892
http_request_duration_seconds_bucket{le="+Inf"} = 45102
http_request_duration_seconds_sum = 7851.23
http_request_duration_seconds_count = 45102
```

This tells you: 24,054 requests finished in under 100ms, 33,421 in under 250ms, etc. The difference between buckets tells you where requests cluster.

Use histograms for:
- Request latency distribution
- Response size distribution
- Query execution time

Histograms are how you calculate **percentiles** (p50, p95, p99) — the single most useful metric for understanding user experience.

---

## Prometheus

Prometheus is the standard metrics system for Kubernetes. It's open-source, part of the CNCF, and integrates natively with the K8s ecosystem.

### How Prometheus Works

```
  ┌─────────────┐     scrape (HTTP GET /metrics)     ┌──────────┐
  │  Your App   │ ◄────────────────────────────────── │Prometheus│
  │  /metrics   │                                     │  Server  │
  └─────────────┘                                     │          │
                                                      │  TSDB    │
  ┌─────────────┐     scrape                          │ (storage)│
  │  Another    │ ◄────────────────────────────────── │          │
  │  Service    │                                     └──────────┘
  └─────────────┘                                          │
                                                           ▼
                                                      ┌──────────┐
                                                      │ Grafana  │
                                                      │(dashboard)│
                                                      └──────────┘
```

Key concepts:

1. **Pull-based.** Prometheus **scrapes** your application's `/metrics` endpoint on a schedule (typically every 15–30 seconds). Your application doesn't push metrics — it just exposes them.
2. **Targets.** Prometheus knows which endpoints to scrape through its configuration. In Kubernetes, it auto-discovers targets via Service annotations or ServiceMonitor CRDs.
3. **Time-series database (TSDB).** Prometheus stores metrics as time-series data: a metric name, a set of labels, and a value at each timestamp.
4. **PromQL.** Prometheus has its own query language for slicing and aggregating metrics.

### What a /metrics Endpoint Looks Like

Your application exposes metrics in Prometheus text format:

```
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/api/beans",status="200"} 48293
http_requests_total{method="GET",path="/api/beans",status="500"} 17
http_requests_total{method="POST",path="/api/orders",status="201"} 3841

# HELP http_request_duration_seconds Duration of HTTP requests
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 24054
http_request_duration_seconds_bucket{le="0.5"} 41237
http_request_duration_seconds_bucket{le="1.0"} 44892
http_request_duration_seconds_bucket{le="+Inf"} 45102
http_request_duration_seconds_sum 7851.23
http_request_duration_seconds_count 45102

# HELP process_resident_memory_bytes Resident memory size in bytes
# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes 327155712
```

Most languages and frameworks have libraries that generate this format automatically.

### PromQL Basics

PromQL lets you query and aggregate metrics. Here are the essential queries:

```promql
# Current value of a metric
http_requests_total

# Filter by labels
http_requests_total{status="500"}

# Rate: requests per second over the last 5 minutes
rate(http_requests_total[5m])

# Error rate as a percentage
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
* 100

# p99 latency (99th percentile request duration)
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Average request duration
rate(http_request_duration_seconds_sum[5m])
/
rate(http_request_duration_seconds_count[5m])

# Memory usage across all pods
sum(container_memory_usage_bytes{namespace="learn-ch16"}) by (pod)
```

You don't need to memorize all of this. The pattern is: start with a metric name, filter with labels `{}`, apply a function like `rate()` or `sum()`, and optionally aggregate with `by (label)`.

---

## The RED Method

For **services** (things that handle requests), track these three:

| Signal | What it measures | Prometheus example |
|--------|-----------------|-------------------|
| **Rate** | Requests per second | `rate(http_requests_total[5m])` |
| **Errors** | Failed requests per second | `rate(http_requests_total{status=~"5.."}[5m])` |
| **Duration** | Latency distribution | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` |

The RED method was coined by Tom Wilkie. If every service in your system exposes Rate, Errors, and Duration, you can tell whether it's healthy at a glance.

### Why p99 and not average?

Average latency hides outliers. If 99% of your requests take 50ms and 1% take 10 seconds, the average is ~150ms. That looks fine. But that 1% is real users having a terrible experience.

**p99** (99th percentile) means "99% of requests are faster than this value." If your p99 is 200ms, 99 out of 100 users see sub-200ms responses. That's what you want to track and alert on.

---

## The USE Method

For **resources** (CPU, memory, disk, network), track these three:

| Signal | What it measures | Example |
|--------|-----------------|---------|
| **Utilization** | How busy the resource is (0–100%) | CPU at 78% |
| **Saturation** | How overloaded the resource is (queue depth, throttling) | 15 requests waiting for a thread |
| **Errors** | Resource-specific errors | 3 disk I/O errors |

The USE method was created by Brendan Gregg. It's designed for infrastructure components rather than application services.

### RED vs USE — When to Use Which

| What you're measuring | Method |
|----------------------|--------|
| API gateway, web server, microservice | RED |
| CPU, memory, disk, network interface | USE |
| Database | Both (RED for query throughput/latency, USE for CPU/memory/connections) |

---

## Prometheus in Kubernetes

In a kind cluster, you can deploy Prometheus quickly using Helm:

```bash
# Add the Prometheus community Helm chart repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (Prometheus + Grafana + useful defaults)
helm install learn-prometheus prometheus-community/kube-prometheus-stack \
  --namespace learn-ch16 \
  --create-namespace \
  --set grafana.adminPassword=learn \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

This gives you:
- Prometheus server with automatic K8s target discovery
- Grafana with pre-built dashboards for K8s metrics
- Node exporter (system metrics from each node)
- kube-state-metrics (K8s object state as metrics)
- Default alerting rules

Access Prometheus UI:

```bash
kubectl port-forward svc/learn-prometheus-kube-prom-prometheus -n learn-ch16 9090:9090
# Open http://localhost:9090
```

Access Grafana:

```bash
kubectl port-forward svc/learn-prometheus-grafana -n learn-ch16 3000:80
# Open http://localhost:3000 (admin / learn)
```

---

## What Kubernetes Already Exposes

Even without instrumenting your application, Prometheus on K8s gives you:

| Metric source | What you get |
|--------------|-------------|
| **kubelet / cAdvisor** | Container CPU, memory, network, disk per pod |
| **kube-state-metrics** | Pod status, Deployment replicas, restart counts, node conditions |
| **node-exporter** | Host-level CPU, memory, disk, network |
| **API server** | API request latency, etcd health, admission controller duration |

This is enough to answer: "Is the cluster healthy? Are pods restarting? Is any node running hot?" But it won't tell you about your application's behavior — for that, your app needs to expose its own `/metrics`.

---

## Quick Reference

```bash
# Port-forward to Prometheus
kubectl port-forward svc/learn-prometheus-kube-prom-prometheus -n learn-ch16 9090:9090

# Port-forward to Grafana
kubectl port-forward svc/learn-prometheus-grafana -n learn-ch16 3000:80

# Check what Prometheus is scraping
# Go to http://localhost:9090/targets

# Run a PromQL query
# Go to http://localhost:9090/graph and type a query

# Check if metrics-server is providing resource metrics
kubectl top pods -n learn-ch16
kubectl top nodes
```

---

> **Sarah:** "A counter and a rate function. That's all it takes to answer 'how many requests per second are we serving?' and 'what percentage are errors?' Once you have those two numbers, you know more about your system than most dashboards will ever show you."

**Next:** [Lesson 03 — Traces](03-traces.md)
