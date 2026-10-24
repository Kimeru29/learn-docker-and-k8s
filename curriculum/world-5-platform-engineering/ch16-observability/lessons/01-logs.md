# Lesson 1: Logs

> **Sarah:** "The first thing everyone does when something breaks is check the logs. That's fine — but most people's logs are a wall of unstructured text that takes 10 minutes to parse. Let me show you how to log properly."

---

## What Logs Are For

Logs answer the question: **"What happened?"**

A log entry records a discrete event: a request arrived, a query ran, an error occurred, a user logged in. Logs are the narrative of your system — they tell you the story of what happened, in what order, and with what context.

But here's the problem: most logs look like this:

```
Started processing request
Connecting to database...
Query took a long time
Error: something went wrong
Retrying...
```

That tells you almost nothing. What request? Which database? How long is "a long time"? Which error? What was the input?

---

## Structured Logging

Structured logging means emitting logs as key-value pairs — typically JSON — instead of free-form text.

**Unstructured (bad for machines):**

```
2024-03-15 14:23:45 ERROR Failed to process order 12345 for user abc - timeout after 5000ms
```

**Structured (good for machines AND humans):**

```json
{
  "timestamp": "2024-03-15T14:23:45.123Z",
  "level": "error",
  "message": "Failed to process order",
  "order_id": "12345",
  "user_id": "abc",
  "duration_ms": 5000,
  "error": "timeout",
  "service": "order-api",
  "trace_id": "4bf92f3577b34da6"
}
```

Why structured logging matters:

1. **Searchable.** You can filter by `order_id`, `user_id`, `level`, or any field. Try searching for a specific order in a wall of unstructured text.
2. **Parseable.** Log aggregation tools (EFK, Loki, CloudWatch) can index structured fields automatically.
3. **Consistent.** Every log entry has the same shape. No guessing what format a given line is in.
4. **Correlatable.** A `trace_id` field lets you link log entries across services for the same request.

---

## Log Levels

Log levels tell you the severity of an event. Use them consistently:

| Level | When to use | Example |
|-------|------------|---------|
| **DEBUG** | Detailed diagnostic info. Never enable in production by default. | `{"level":"debug","message":"Cache lookup","key":"user:abc","hit":true}` |
| **INFO** | Normal operations. Things that happened and are expected. | `{"level":"info","message":"Order placed","order_id":"12345"}` |
| **WARN** | Something unexpected that isn't broken yet. Worth investigating. | `{"level":"warn","message":"Slow query","duration_ms":4500,"threshold_ms":3000}` |
| **ERROR** | Something is broken. A request failed. An operation didn't complete. | `{"level":"error","message":"Payment failed","error":"gateway_timeout"}` |
| **FATAL** | The process is about to crash. Used rarely. | `{"level":"fatal","message":"Cannot connect to database","retries":5}` |

### What to log

- Request start/end with duration
- Errors with context (what was the input, what failed, what was the error)
- State transitions (order placed, order shipped, order cancelled)
- Authentication events (login, logout, failed login)
- Configuration changes
- Startup and shutdown events

### What NOT to log

- **Passwords, tokens, API keys, PII** — ever. If a log line contains a password, the password is compromised.
- **Every single function call** — logs are for events, not execution traces. That's what traces are for.
- **High-volume data** — logging every row of a database result set will fill your disk and make real errors invisible.
- **Health check requests** — these happen every few seconds and produce noise with zero signal.

---

## Containers and stdout/stderr

In Docker and Kubernetes, the logging contract is simple:

> **Write logs to stdout (standard output) and stderr (standard error). The container runtime handles the rest.**

This is the [12-Factor App](https://12factor.net/logs) approach. Your application doesn't know or care where its logs go. It writes to stdout/stderr. The container runtime (Docker, containerd) captures that output, and the platform (Kubernetes, a log aggregator) routes it.

```
  Your Application
       │
       ▼
  stdout / stderr
       │
       ▼
  Container Runtime (containerd)
       │
       ▼
  Log files on the node (/var/log/containers/)
       │
       ▼
  Log aggregator (Loki, EFK, CloudWatch)
```

### Why stdout/stderr?

- **Portable.** Works with any container runtime, any orchestrator, any log aggregator.
- **Simple.** No log file management inside the container. No log rotation. No permissions issues.
- **Standard.** `kubectl logs` reads stdout/stderr. Every tool in the ecosystem expects this.

### What about stderr?

- **stdout** — normal application output, including INFO and DEBUG logs
- **stderr** — error output (ERROR, FATAL) and diagnostic messages

In practice, many applications send all logs to stdout and use the log level field to distinguish severity. That's fine. The important thing is: don't write logs to a file inside the container.

---

## kubectl logs

The most basic way to read container logs in Kubernetes:

```bash
# Logs from a specific pod
kubectl logs <pod-name> -n learn-ch16

# Follow logs in real-time (like tail -f)
kubectl logs <pod-name> -n learn-ch16 -f

# Logs from a specific container in a multi-container pod
kubectl logs <pod-name> -c <container-name> -n learn-ch16

# Logs from the previous container instance (after a restart)
kubectl logs <pod-name> -n learn-ch16 --previous

# Logs from all pods matching a label
kubectl logs -l app=learn-api -n learn-ch16

# Last 100 lines only
kubectl logs <pod-name> -n learn-ch16 --tail=100

# Logs from the last 5 minutes
kubectl logs <pod-name> -n learn-ch16 --since=5m
```

### Limitations of kubectl logs

- **Single pod** — by default, you see one pod at a time. With multiple replicas, you need to check each or use `-l`.
- **No search** — there's no built-in grep, filter, or query. You pipe to `grep` on the client side.
- **No persistence** — if the pod is deleted, the logs are gone. Kubernetes doesn't store logs long-term.
- **No cross-service correlation** — you can't follow a request across `api`, `worker`, and `database` pods.

For anything beyond basic debugging, you need centralized logging.

---

## Centralized Logging Concepts

Centralized logging collects logs from all pods across the cluster into one place where you can search, filter, and correlate.

### The EFK Stack

```
  Pods (stdout/stderr)
       │
       ▼
  Fluentd / Fluent Bit (collector, runs as DaemonSet on every node)
       │
       ▼
  Elasticsearch (storage + indexing)
       │
       ▼
  Kibana (search + visualization UI)
```

- **Fluentd / Fluent Bit** — log collectors that read from node log files, parse, enrich, and forward logs. Fluent Bit is lighter-weight.
- **Elasticsearch** — a search engine that indexes log entries. Powerful but resource-hungry.
- **Kibana** — web UI for searching and visualizing logs.

### Grafana Loki

A more recent, lighter-weight alternative:

```
  Pods (stdout/stderr)
       │
       ▼
  Promtail (collector, runs as DaemonSet)
       │
       ▼
  Loki (storage — indexes labels, not log content)
       │
       ▼
  Grafana (search + visualization)
```

Loki's key insight: don't index the full text of every log line. Instead, index metadata labels (pod, namespace, container) and store the log content as chunks. This makes Loki much cheaper to run than Elasticsearch, at the cost of full-text search being slower.

### When to use which

| Need | Solution |
|------|----------|
| Quick pod debugging | `kubectl logs` |
| Search logs across pods and time ranges | Loki or EFK |
| Correlate logs with metrics | Loki + Grafana (same UI as your metrics dashboards) |
| Full-text search at massive scale | Elasticsearch + Kibana |
| Already running Prometheus + Grafana | Add Loki — it fits naturally |

---

## Practical Logging Patterns

### Add request IDs

Every inbound request should get a unique ID. Include it in every log line for that request:

```json
{"request_id": "req-abc-123", "message": "Processing order", "order_id": "456"}
{"request_id": "req-abc-123", "message": "Calling payment service", "duration_ms": 230}
{"request_id": "req-abc-123", "message": "Order complete", "status": "success"}
```

Now you can filter by `request_id` and see the full lifecycle of one request.

### Log at boundaries

The most useful log entries happen at system boundaries:

- Request arrives (with method, path, headers)
- External service called (with target, duration, result)
- Database query executed (with duration, row count — never the query parameters if they contain user data)
- Request completed (with status code, total duration)

### Don't log inside tight loops

```python
# BAD: logs 10,000 lines for one request
for item in items:
    log.info(f"Processing item {item.id}")

# GOOD: log the summary
log.info(f"Processed {len(items)} items", extra={"duration_ms": elapsed})
```

---

## Quick Reference

```bash
# Basic pod logs
kubectl logs <pod> -n <namespace>

# Follow logs (real-time)
kubectl logs <pod> -n <namespace> -f

# Previous container logs
kubectl logs <pod> -n <namespace> --previous

# All pods with a label
kubectl logs -l app=<label> -n <namespace>

# Filter with grep (client-side)
kubectl logs <pod> -n <namespace> | grep "error"

# JSON-aware filtering with jq (if logs are structured JSON)
kubectl logs <pod> -n <namespace> | jq 'select(.level == "error")'
```

---

> **Sarah:** "The Great Database Incident of 2024? Know how long it took us to find the root cause? Four hours. Because our logs were unstructured, and I had to read through 200,000 lines of 'connecting to database...' to find the one line that said 'connection pool exhausted.' After that, we switched to structured logging. Same incident today would take five minutes."

**Next:** [Lesson 02 — Metrics](02-metrics.md)
