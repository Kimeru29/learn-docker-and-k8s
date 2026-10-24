```
   ____ _     _  __
  / ___| |__ / |/ /_
 | |   | '_ \| | '_ \
 | |___| | | | | (_) |
  \____|_| |_|_|\___/

  ___  _                              _   _ _ _ _
 / _ \| |__  ___  ___ _ ____   ____ _| |_(_) (_) |_ _   _
| | | | '_ \/ __|/ _ \ '__\ \ / / _` | __| | | | __| | | |
| |_| | |_) \__ \  __/ |   \ V / (_| | |_| | | | |_| |_| |
 \___/|_.__/|___/\___|_|    \_/ \__,_|\__|_|_|_|\__|\__, |
                                                     |___/

  🔍 "The Glass Roaster"

     Dashboard says:   ✅ ALL GREEN
     Customers say:    😤 "It's slow"
     Reality:          ??? (we can't see inside)

     ┌─────────────────────────────────────────┐
     │   The Three Pillars of Observability    │
     │                                         │
     │   📋 LOGS      What happened?           │
     │   📊 METRICS   How much / how fast?     │
     │   🔗 TRACES    Where did the time go?   │
     └─────────────────────────────────────────┘

     (•_•) Sarah: "You can't fix what you can't see."
```

# Chapter 16: The Glass Roaster — Observability

## The Story

The dashboard is green. All pods are Running. Health probes pass. The HPA is happy.

But customers are complaining. The coffee recommendation engine takes 8 seconds to respond. The bean subscription checkout times out intermittently. Three support tickets this week about "slow loading."

You check the Deployment. Healthy. You check the pods. Running. You check CPU and memory. Normal.

Sarah leans over. "The dashboard is lying to you. Not deliberately — it's just not showing you the right things. 'Running' means the process hasn't crashed. It doesn't mean the process is fast, correct, or useful."

She pulls up a blank screen. "We need to see inside the system. Not just 'is it alive?' but 'is it working well?' That's the difference between monitoring and observability."

---

## What You'll Learn

By the end of this chapter, you will be able to:

- Implement structured logging in containers and understand log aggregation concepts
- Deploy Prometheus to scrape metrics from applications and infrastructure
- Understand distributed tracing and how OpenTelemetry connects the dots across services
- Build dashboards that answer "is the system healthy?" — not just "is it running?"
- Design alerts that wake you up for the right reasons and let you sleep through the noise
- Explain and apply SLIs, SLOs, and SLAs to define what "healthy" means

---

## Prerequisites

- World 4 completed (kind cluster, Deployments, Services, probes, resources)
- `kubectl` connected to your `learn-k8s` cluster
- Helm installed (`helm version` returns a version)
- Namespace `learn-ch16` will be created during challenges

---

## Estimated Time

- Lessons: ~90 minutes
- Challenges: ~2–3 hours
- Quiz: ~15 minutes
- Total: ~4–5 hours

---

## Lessons

| # | Lesson | What You'll Learn |
|---|--------|-------------------|
| 01 | [Logs](lessons/01-logs.md) | Structured logging, log levels, stdout/stderr, kubectl logs, centralized logging concepts |
| 02 | [Metrics](lessons/02-metrics.md) | Counters, gauges, histograms, Prometheus, PromQL basics, RED and USE methods |
| 03 | [Traces](lessons/03-traces.md) | Distributed tracing, OpenTelemetry, spans, trace context, when to use which pillar |
| 04 | [Dashboards & Alerts](lessons/04-dashboards-and-alerts.md) | Useful dashboards, alert design, SLIs/SLOs/SLAs, avoiding alert fatigue |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Diagnose with Metrics](challenges/01-diagnose-with-metrics.md) | Deploy Prometheus, examine metrics, find a latency bottleneck |
| 02 | [Trace the Request](challenges/02-trace-the-request.md) | Analyze distributed traces to find which service is slow |
| 03 | [Build a Dashboard](challenges/03-build-a-dashboard.md) | Create a Grafana dashboard that answers "is the system healthy?" |

To verify your work: `bash curriculum/world-5-platform-engineering/ch16-observability/challenges/verify.sh`

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Observability** | The ability to understand a system's internal state from its external outputs |
| **Structured logging** | Logs emitted as key-value pairs (usually JSON) instead of free-form text |
| **Metric** | A numeric measurement collected over time (counter, gauge, histogram) |
| **Counter** | A metric that only goes up (total requests, total errors) |
| **Gauge** | A metric that goes up and down (current memory usage, active connections) |
| **Histogram** | A metric that samples observations into buckets (request duration distribution) |
| **Prometheus** | Open-source metrics collection system that scrapes targets on a schedule |
| **PromQL** | Prometheus Query Language for querying time-series metric data |
| **RED method** | Rate, Errors, Duration — the three metrics every service should expose |
| **USE method** | Utilization, Saturation, Errors — the three metrics for every resource |
| **Distributed trace** | A record of a request's journey through multiple services |
| **Span** | A single unit of work within a trace (one service call, one database query) |
| **OpenTelemetry** | Vendor-neutral standard for logs, metrics, and traces instrumentation |
| **SLI** | Service Level Indicator — a quantitative measure of service behavior |
| **SLO** | Service Level Objective — a target value or range for an SLI |
| **SLA** | Service Level Agreement — a contract with consequences if the SLO is breached |
| **Grafana** | Open-source platform for metric visualization and dashboarding |

---

> **Sarah:** "Observability isn't a tool you install. It's a practice. The tools are just how you get there."

**Next:** Start with [Lesson 01 — Logs](lessons/01-logs.md)
