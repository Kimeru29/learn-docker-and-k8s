# Lesson 4: Dashboards & Alerts

> **Sarah:** "A dashboard that shows 47 panels of green charts is not a dashboard. It's wallpaper. A real dashboard answers one question: 'Is the system healthy right now, and if not, where?'"

---

## Building Useful Dashboards

### The Problem with Most Dashboards

You've probably seen dashboards with 20+ panels showing CPU, memory, disk, network, pod counts, request counts, error counts, queue depths, and every other metric someone thought might be useful.

Nobody reads them. They become decoration on a TV screen in the corner of the office.

A useful dashboard is designed to answer specific questions, not display all available data.

### Dashboard Design Principles

**1. Start with the question, not the metric.**

Bad: "Let's show CPU usage because we have CPU data."

Good: "What should an on-call engineer see first when they open this dashboard?"

**2. The Four Golden Signals.**

Google's Site Reliability Engineering book defines four signals that every service dashboard should show:

| Signal | Question it answers | Metric type |
|--------|-------------------|-------------|
| **Latency** | How long do requests take? | Histogram (p50, p95, p99) |
| **Traffic** | How many requests per second? | Counter (rate) |
| **Errors** | What percentage of requests fail? | Counter (rate, ratio) |
| **Saturation** | How close to capacity are we? | Gauge (CPU, memory, queue depth) |

These four panels answer "is the system healthy?" in under 5 seconds.

**3. Layer your dashboards.**

```
Level 1: Overview     "Is anything broken?" (one dashboard, all services)
     │
     ▼
Level 2: Service      "Which service is unhealthy?" (one dashboard per service)
     │
     ▼
Level 3: Deep dive    "What's wrong with this service?" (detailed metrics for investigation)
```

The overview dashboard is what goes on the TV. Service dashboards are for triage. Deep dives are for debugging.

**4. What NOT to put on a dashboard.**

- Raw metric values with no context (what does `42` mean?)
- Metrics that never change or are always the same
- More than 8–10 panels on an overview dashboard
- Metrics without clear units and labels
- Information that requires institutional knowledge to interpret

---

## A Practical Dashboard Layout

For a Kubernetes service like the NoCappuccino API:

```
┌─────────────────────────────────────────────────────────────┐
│                 NoCappuccino API — Overview                  │
├─────────────────────────┬───────────────────────────────────┤
│  Request Rate (req/s)   │  Error Rate (%)                   │
│  ████████████ 142/s     │  ███ 0.3%                         │
│  (rate over last 5m)    │  (5xx / total over last 5m)       │
├─────────────────────────┼───────────────────────────────────┤
│  Latency (p50/p95/p99)  │  Pod Status                       │
│  p50: 45ms              │  Running: 3/3 ✓                   │
│  p95: 180ms             │  Restarts (1h): 0                 │
│  p99: 420ms             │  Ready: 3/3                       │
├─────────────────────────┼───────────────────────────────────┤
│  Memory Usage (per pod) │  CPU Usage (per pod)              │
│  pod-1: 210Mi / 512Mi   │  pod-1: 120m / 500m              │
│  pod-2: 195Mi / 512Mi   │  pod-2: 105m / 500m              │
│  pod-3: 220Mi / 512Mi   │  pod-3: 115m / 500m              │
└─────────────────────────┴───────────────────────────────────┘
```

Six panels. Takes 5 seconds to scan. You immediately know:
- Are we serving traffic? (request rate)
- Is anything broken? (error rate)
- Is it fast enough? (latency)
- Are pods healthy? (pod status)
- Are we close to limits? (memory, CPU)

---

## Grafana Dashboards

Grafana is the standard visualization tool for Prometheus metrics. With kube-prometheus-stack installed, you already have Grafana with pre-built K8s dashboards.

### Creating a Panel

Each Grafana panel runs a PromQL query and visualizes the result. For example:

**Request rate panel:**

```promql
sum(rate(http_requests_total{namespace="learn-ch16"}[5m])) by (service)
```

**Error rate panel:**

```promql
sum(rate(http_requests_total{namespace="learn-ch16",status=~"5.."}[5m]))
/
sum(rate(http_requests_total{namespace="learn-ch16"}[5m]))
* 100
```

**p99 latency panel:**

```promql
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket{namespace="learn-ch16"}[5m])) by (le, service)
)
```

**Pod restart count:**

```promql
sum(kube_pod_container_status_restarts_total{namespace="learn-ch16"}) by (pod)
```

**Memory usage vs limit:**

```promql
# Usage
sum(container_memory_working_set_bytes{namespace="learn-ch16",container!=""}) by (pod)

# Limit
sum(kube_pod_container_resource_limits{namespace="learn-ch16",resource="memory"}) by (pod)
```

### Dashboard Variables

Use Grafana variables to make dashboards reusable:

- `$namespace` — select which namespace to view
- `$service` — filter to a specific service
- `$interval` — adjust the time window

This way one dashboard template works for any service.

---

## Alert Design

### The Purpose of an Alert

An alert exists for one reason: **someone needs to take action right now.**

If an alert fires and the correct response is "look at it later" or "it'll fix itself," that's a bad alert. It trains people to ignore alerts, which means they'll ignore the real ones too.

### Symptoms, Not Causes

Alert on **symptoms** (what the user experiences), not **causes** (what's happening internally).

| Type | Alert | Problem |
|------|-------|---------|
| ❌ **Cause** | "CPU above 80%" | CPU might be high because of a healthy traffic spike. Not every CPU spike is a problem. |
| ✅ **Symptom** | "Error rate > 1% for 5 minutes" | Users are seeing errors. Something is broken regardless of the cause. |
| ❌ **Cause** | "Pod restarted" | A single pod restart that was immediately replaced is self-healing, not an incident. |
| ✅ **Symptom** | "p99 latency > 2s for 10 minutes" | Users are experiencing slow responses. Investigate. |

### Alert Severity Levels

| Severity | Response | Example |
|----------|----------|---------|
| **Critical / Page** | Wake someone up. Immediate action needed. | Error rate > 5% for 5 minutes. Service unreachable. |
| **Warning** | Investigate during business hours. | p99 approaching SLO threshold. Disk 80% full. |
| **Info** | Awareness only. No action required. | Deployment completed. Certificate renews in 30 days. |

### Avoiding Alert Fatigue

Alert fatigue is when you get so many alerts that you stop paying attention. It's one of the most common operational failures.

**Rules to prevent alert fatigue:**

1. **Every alert must have a documented response.** If you don't know what to do when it fires, delete the alert.
2. **Set meaningful thresholds.** An alert that fires 10 times a day and resolves by itself is noise.
3. **Use duration windows.** Don't alert on a single data point. Alert when a condition persists (`for: 5m` in Prometheus).
4. **Aggregate, don't enumerate.** One alert for "3 pods restarted in namespace X" is better than three separate pod restart alerts.
5. **Review alerts quarterly.** Delete alerts that haven't led to real action.

### Alert Example (Prometheus AlertManager)

```yaml
groups:
  - name: nocappuccino
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5..",namespace="learn-ch16"}[5m]))
          /
          sum(rate(http_requests_total{namespace="learn-ch16"}[5m]))
          > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate above 1% for 5 minutes"
          description: "{{ $labels.service }} error rate is {{ $value | humanizePercentage }}"
          runbook_url: "https://wiki.internal/runbooks/high-error-rate"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket{namespace="learn-ch16"}[5m])) by (le)
          ) > 2
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "p99 latency above 2 seconds"
          description: "p99 latency is {{ $value }}s"
```

Key elements:
- `expr` — the PromQL query that defines the alert condition
- `for` — how long the condition must be true before firing
- `severity` — determines routing (page vs ticket vs FYI)
- `annotations` — human-readable description and a link to the runbook

---

## SLIs, SLOs, and SLAs

These three concepts define what "healthy" means for your service — in measurable terms.

### SLI — Service Level Indicator

A **quantitative measure** of a specific aspect of service behavior.

Examples:
- "The proportion of requests that complete successfully" (availability)
- "The proportion of requests faster than 500ms" (latency)
- "The proportion of data processing jobs that complete within 1 hour" (freshness)

An SLI is a number, typically expressed as a ratio:

```
SLI = good events / total events

Availability SLI = successful requests / total requests = 99.7%
Latency SLI = requests < 500ms / total requests = 98.1%
```

### SLO — Service Level Objective

A **target value** for an SLI over a time window.

Examples:
- "99.9% of requests should succeed over a 30-day window" (availability SLO)
- "95% of requests should complete in under 500ms over a 7-day window" (latency SLO)

An SLO defines the line between "acceptable" and "we need to take action." If you're above the SLO, invest in features. If you're below, invest in reliability.

### SLA — Service Level Agreement

A **contract** with consequences (usually financial) if the SLO is not met.

Examples:
- "We guarantee 99.9% uptime. If we miss it, customers receive a 10% credit."
- "API response time will be under 500ms for 99% of requests. If not, the SLA is breached."

**SLA ⊂ SLO ⊂ SLI.** Your SLI measures reality. Your SLO is your internal target (usually stricter than the SLA). Your SLA is the external commitment.

```
  SLI: 99.95% availability (measured)
  SLO: 99.9% availability (internal target)
  SLA: 99.5% availability (contractual guarantee)

  ← breach ─── SLA ─── SLO ─── SLI (current) ──→
                │       │        │
                │       │        └── Doing great
                │       └── If SLI drops here, focus on reliability
                └── If SLI drops here, you owe customers money
```

### Error Budgets

An **error budget** is the inverse of the SLO: how much failure you're allowed.

```
SLO: 99.9% availability over 30 days
Error budget: 0.1% of 30 days = 43.2 minutes of downtime allowed per month
```

If your error budget is nearly spent, stop deploying features and fix reliability. If you have plenty of error budget left, ship features faster. The error budget makes the reliability-vs-velocity tradeoff explicit and data-driven.

---

## Quick Reference

| Concept | Key Question |
|---------|-------------|
| Dashboard | "Can I tell if the system is healthy in 5 seconds?" |
| Alert | "Does someone need to take action right now?" |
| SLI | "What number measures user experience?" |
| SLO | "What's our target for that number?" |
| SLA | "What do we contractually owe customers?" |
| Error budget | "How much failure can we tolerate this month?" |

---

> **Sarah:** "We had 147 alerts firing on the old system. Know how many led to real action? Eleven. The rest were noise. We deleted 136 alerts, rewrote the remaining 11 around SLOs, and the on-call engineer's life improved dramatically. Fewer alerts, more signal."

**Next:** [Challenge 01 — Diagnose with Metrics](../challenges/01-diagnose-with-metrics.md)
