# Lesson 3: Traces

> **Sarah:** "Logs tell you what happened. Metrics tell you how much. Traces tell you *where the time went*. When a customer says 'checkout is slow,' a trace shows you whether the problem is the API, the payment service, the database, or something in between."

---

## The Problem Traces Solve

Imagine a request hits your coffee ordering API. It takes 3.2 seconds. That's too slow. But where did the time go?

```
User → API Gateway → Order Service → Payment Service → Database
                                    → Inventory Service → Database
                   → Notification Service
```

With logs alone, you'd check each service's logs individually. Maybe you find a slow query in the database. Maybe you don't. You're guessing.

With metrics, you know the p99 is 3.2 seconds. But which part of that 3.2 seconds is the bottleneck?

A **distributed trace** follows one request through every service it touches and records how long each step took:

```
 Request: POST /api/orders/create
 Total: 3200ms
 │
 ├── API Gateway (12ms)
 │   └── Auth check (8ms)
 │
 ├── Order Service (3180ms)
 │   ├── Validate order (3ms)
 │   ├── Payment Service (2850ms)  ◄── HERE IS YOUR PROBLEM
 │   │   └── Charge card (2840ms)
 │   ├── Inventory Service (290ms)
 │   │   └── Reserve stock (285ms)
 │   └── Save order (25ms)
 │
 └── Notification Service (5ms, async)
     └── Send confirmation email
```

Now you know: the Payment Service is taking 2.8 seconds. That's 89% of the total request time. You know exactly where to look.

---

## Trace Anatomy

### Trace

A **trace** represents the full journey of a single request through a distributed system. It has a unique **trace ID** that connects all the pieces.

### Span

A **span** represents a single unit of work within a trace. Each span records:

- **Name** — what operation this span represents (`HTTP GET /api/beans`, `SQL SELECT`, `cache.lookup`)
- **Start time** — when the operation started
- **Duration** — how long it took
- **Parent span** — which operation triggered this one
- **Attributes** — key-value metadata (`http.method`, `db.system`, `error`)
- **Status** — OK, Error

### Trace Context

When Service A calls Service B, the trace ID and parent span ID must be **propagated** — typically via HTTP headers:

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```

This header follows the [W3C Trace Context](https://www.w3.org/TR/trace-context/) standard. Service B reads it, creates a new span as a child of Service A's span, and attaches the same trace ID. This is how spans from different services get stitched together into one trace.

```
  Service A                     Service B                     Service C
  ┌─────────┐                   ┌─────────┐                   ┌─────────┐
  │ Span A  │───traceparent───→ │ Span B  │───traceparent───→ │ Span C  │
  │ trace:X │   in HTTP header  │ trace:X │   in HTTP header  │ trace:X │
  │ parent:-│                   │ parent:A│                   │ parent:B│
  └─────────┘                   └─────────┘                   └─────────┘
```

All three spans share the same trace ID (`X`), creating a tree that shows the call chain.

---

## OpenTelemetry (OTel)

OpenTelemetry is the **vendor-neutral, open standard** for instrumenting applications to emit logs, metrics, and traces. It's a CNCF project and has become the industry standard.

### What OpenTelemetry Provides

1. **SDKs** — libraries for every major language (Go, Java, Python, .NET, Node.js, etc.) that instrument your code to emit telemetry data.
2. **Auto-instrumentation** — for many frameworks, OTel can automatically trace HTTP requests, database queries, and messaging without code changes.
3. **Collector** — a service that receives, processes, and exports telemetry data to backends (Jaeger, Zipkin, Tempo, vendor platforms).
4. **Protocol (OTLP)** — a standard protocol for transmitting traces, metrics, and logs.

### The OTel Architecture

```
  Your Application
  (with OTel SDK)
       │
       │ OTLP (gRPC or HTTP)
       ▼
  ┌──────────────────┐
  │ OTel Collector   │
  │  - receive       │
  │  - process       │
  │  - export        │
  └──────────────────┘
       │
       ▼
  Backend (Jaeger, Tempo, Zipkin, vendor)
       │
       ▼
  UI (trace visualization)
```

The Collector is optional — your application can export directly to a backend. But the Collector adds value: it can batch, retry, filter, and route telemetry, keeping that complexity out of your application.

### Auto-Instrumentation Example

In many frameworks, adding tracing requires zero code changes. For example, a Node.js Express app:

```bash
# Install OTel packages
npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node

# Run with auto-instrumentation
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

This automatically creates spans for HTTP requests, database queries, and outbound HTTP calls. Similar auto-instrumentation exists for Java (agent), Python (site customization), and .NET (instrumentation libraries).

---

## Reading a Trace

A trace visualization (in Jaeger, Grafana Tempo, or similar) looks like a waterfall diagram:

```
Trace: 4bf92f35  Duration: 3200ms
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

api-gateway        ████                                    12ms
  └─ auth.check    ███                                      8ms

order-service      ████████████████████████████████████████ 3180ms
  ├─ validate      █                                         3ms
  ├─ payment-svc   ████████████████████████████████████     2850ms
  │  └─ charge     ███████████████████████████████████      2840ms  ⚠ SLOW
  ├─ inventory-svc ██████████                                290ms
  │  └─ reserve    █████████                                 285ms
  └─ save-order    █                                          25ms

notification-svc   █                                          5ms
```

What this tells you:

1. The total request took 3.2 seconds.
2. The order-service is the top-level span for most of the work.
3. Inside order-service, payment-svc dominates at 2.85 seconds.
4. Inside payment-svc, the actual card charge operation takes 2.84 seconds.
5. The bottleneck is the payment gateway, not your code.

Without the trace, you might have spent hours looking at your own database, your own code, only to discover the third-party payment provider was the problem.

---

## When to Use Which Pillar

| Question | Pillar | Why |
|----------|--------|-----|
| "What happened at 3:47 AM?" | **Logs** | Logs give you the narrative — the sequence of events |
| "How many errors per second?" | **Metrics** | Metrics give you aggregate numbers over time |
| "Why is this specific request slow?" | **Traces** | Traces show the call chain and timing breakdown |
| "Is the error rate increasing?" | **Metrics** | Trend analysis requires time-series data |
| "Which service is the bottleneck?" | **Traces** | Traces show cross-service latency |
| "What was the error message?" | **Logs** | Error details live in log entries |
| "Is p99 latency within SLO?" | **Metrics** | SLO tracking needs aggregate quantiles |

### The Three Pillars Together

The real power comes from connecting all three:

1. **Metrics** alert you that p99 latency has increased.
2. **Traces** show you which service in the chain is slow.
3. **Logs** from that service tell you the exact error or slow query.

This is why structured logs should include a `trace_id` field — so you can jump from a trace to the exact log entries for that request.

```
Metric alert: "p99 > 2s"
     │
     ▼
Trace: shows payment-service span = 2.8s
     │
     ▼
Logs (filtered by trace_id): "Payment gateway timeout after 2800ms, retrying..."
     │
     ▼
Root cause: Payment provider having an outage
```

---

## Tracing in Kubernetes

In a K8s cluster, tracing backends can be deployed alongside Prometheus and Grafana:

| Backend | Description |
|---------|-------------|
| **Jaeger** | Popular open-source tracing backend. Good UI for trace exploration. |
| **Grafana Tempo** | Trace storage backend that integrates with Grafana. Cheaper to run than Jaeger at scale. |
| **Zipkin** | One of the original distributed tracing systems. Simpler than Jaeger. |

For the challenges in this chapter, we'll focus on understanding trace data and analysis rather than deploying a full tracing backend. The concepts transfer to any tool.

---

## Common Tracing Pitfalls

1. **Missing context propagation.** If Service B doesn't read the `traceparent` header from Service A, the trace breaks. You get two disconnected traces instead of one.
2. **Over-instrumenting.** Creating a span for every function call produces traces with thousands of spans. Focus on service boundaries and significant operations (HTTP calls, database queries, cache lookups).
3. **Sampling.** In production, tracing every request is expensive. Most systems sample a percentage (e.g., 1% of requests). Make sure error and slow requests are always traced.
4. **Async operations.** Message queues, background jobs, and event-driven systems need special handling to propagate trace context through the message.

---

> **Sarah:** "I once spent two hours debugging a slow API call. Checked our code, our database, our cache. Everything looked fine. Finally someone set up tracing and we saw it immediately — the request was spending 4 seconds waiting for a DNS lookup to a misconfigured external service. Two hours to find without traces. Five seconds with them."

**Next:** [Lesson 04 — Dashboards & Alerts](04-dashboards-and-alerts.md)
