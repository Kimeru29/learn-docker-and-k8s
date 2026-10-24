# Challenge 2: Trace the Request

> **Sarah:** "The recommendation engine calls three backend services. One of them is the bottleneck. Metrics showed us that latency is high — but which service? Time to read a trace."

---

## The Situation

The NoCappuccino recommendation API calls multiple backend services to generate personalized coffee suggestions:

```
User Request
    │
    ▼
┌──────────────────────┐
│  Recommendation API  │  Total: ~2200ms
│  (orchestrator)      │
├──────────────────────┤
│  ├─→ Bean Catalog    │  Fetches bean data
│  ├─→ User Preferences│  Fetches user taste profile
│  └─→ ML Scoring      │  Scores beans against preferences
└──────────────────────┘
```

You have trace data from a production request. Your job: analyze the trace, identify the bottleneck, and document your findings.

---

## The Trace Data

Below is the trace output for a single request to `GET /api/recommendations/user-42`. Study it carefully.

```
Trace ID: 7a8b3c4d5e6f7890abcdef1234567890
Total Duration: 2247ms

SPAN TREE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1] recommendation-api: GET /api/recommendations/user-42
    Duration: 2247ms | Status: OK
    Attributes:
      http.method: GET
      http.url: /api/recommendations/user-42
      http.status_code: 200
      user.id: user-42
    │
    ├── [2] recommendation-api: validate-request
    │   Duration: 3ms | Status: OK
    │   Attributes:
    │     validation.result: pass
    │
    ├── [3] recommendation-api → bean-catalog: GET /internal/beans
    │   Duration: 145ms | Status: OK
    │   Attributes:
    │     http.method: GET
    │     http.url: http://bean-catalog:8080/internal/beans
    │     http.status_code: 200
    │     beans.count: 247
    │   │
    │   └── [4] bean-catalog: db.query SELECT beans
    │       Duration: 128ms | Status: OK
    │       Attributes:
    │         db.system: postgresql
    │         db.operation: SELECT
    │         db.statement: "SELECT * FROM beans WHERE active = true"
    │         db.rows_returned: 247
    │
    ├── [5] recommendation-api → user-preferences: GET /internal/preferences/user-42
    │   Duration: 1842ms | Status: OK
    │   Attributes:
    │     http.method: GET
    │     http.url: http://user-preferences:8080/internal/preferences/user-42
    │     http.status_code: 200
    │   │
    │   ├── [6] user-preferences: cache.lookup
    │   │   Duration: 2ms | Status: OK
    │   │   Attributes:
    │   │     cache.hit: false
    │   │     cache.key: "prefs:user-42"
    │   │
    │   ├── [7] user-preferences: db.query SELECT preferences
    │   │   Duration: 45ms | Status: OK
    │   │   Attributes:
    │   │     db.system: postgresql
    │   │     db.operation: SELECT
    │   │     db.rows_returned: 1
    │   │
    │   └── [8] user-preferences → ml-model: POST /score-preferences
    │       Duration: 1780ms | Status: OK
    │       Attributes:
    │         http.method: POST
    │         http.url: http://ml-model:5000/score-preferences
    │         http.status_code: 200
    │         ml.model_version: v2.3.1
    │         ml.inference_time_ms: 1750
    │         ml.features_count: 47
    │
    ├── [9] recommendation-api → ml-scoring: POST /internal/rank
    │   Duration: 210ms | Status: OK
    │   Attributes:
    │     http.method: POST
    │     http.url: http://ml-scoring:8080/internal/rank
    │     http.status_code: 200
    │     scoring.beans_ranked: 247
    │     scoring.top_results: 10
    │   │
    │   └── [10] ml-scoring: rank-algorithm
    │       Duration: 195ms | Status: OK
    │       Attributes:
    │         algorithm: cosine_similarity
    │         input_size: 247
    │
    └── [11] recommendation-api: format-response
        Duration: 8ms | Status: OK
        Attributes:
          results.count: 10
          response.size_bytes: 4823

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Timeline (approximate):
0ms         500ms       1000ms      1500ms      2000ms      2247ms
|           |           |           |           |           |
[===== bean-catalog 145ms =====]
            [===================== user-preferences 1842ms =====================]
                                                            [= ml-scoring 210ms]
                                                                         [=] fmt
```

---

## Your Mission

Analyze the trace data above and answer the following questions by creating a ConfigMap with your analysis.

### Questions

1. **Which service is the bottleneck?** Which span consumes the most time?
2. **What is the root cause?** Go deeper — within that slow service, what specific operation takes the most time?
3. **What percentage of total request time does the bottleneck account for?**
4. **Is the bean-catalog service a problem?** Why or why not?
5. **What would you recommend to fix the latency?**

### Create Your Analysis

Create a ConfigMap named `learn-trace-analysis` in the `learn-ch16` namespace:

```bash
kubectl create configmap learn-trace-analysis \
  --from-literal=bottleneck_service="<service-name>" \
  --from-literal=bottleneck_span="<span-description>" \
  --from-literal=bottleneck_duration_ms="<duration>" \
  --from-literal=bottleneck_percentage="<percentage>" \
  --from-literal=recommendation="<your-recommendation>" \
  -n learn-ch16
```

Replace the `<placeholders>` with your findings from the trace.

---

## Success Criteria

- [ ] ConfigMap `learn-trace-analysis` exists in `learn-ch16`
- [ ] `bottleneck_service` correctly identifies the slow service
- [ ] `bottleneck_span` identifies the specific slow operation
- [ ] `bottleneck_duration_ms` is within 100ms of the actual span duration
- [ ] `recommendation` contains a reasonable fix suggestion

---

## Hints

<details>
<summary>Hint 1: How to read the trace</summary>

Look at the duration of each top-level call from the recommendation-api:

- Span [3]: bean-catalog → 145ms
- Span [5]: user-preferences → 1842ms
- Span [9]: ml-scoring → 210ms

One of these is dramatically slower than the others. That's your starting point.

</details>

<details>
<summary>Hint 2: Go one level deeper</summary>

The slow service (user-preferences, 1842ms) makes three internal calls:

- Span [6]: cache.lookup → 2ms (cache MISS)
- Span [7]: db.query → 45ms
- Span [8]: ml-model call → 1780ms

The cache missed (user-42's preferences weren't cached), the database query was fast, but the ML model scoring call took 1780ms — that's 79% of the entire request.

</details>

<details>
<summary>Hint 3: The answer</summary>

```bash
kubectl create configmap learn-trace-analysis \
  --from-literal=bottleneck_service="user-preferences" \
  --from-literal=bottleneck_span="ml-model POST /score-preferences (inference)" \
  --from-literal=bottleneck_duration_ms="1780" \
  --from-literal=bottleneck_percentage="79" \
  --from-literal=recommendation="The ML model inference (v2.3.1) takes 1.78s per request. Options: cache scored preferences, optimize the model, reduce feature count from 47, or pre-compute scores asynchronously." \
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

This trace reveals a pattern you'll see often in production:

1. The **orchestrator** (recommendation-api) looks slow, but it's just waiting.
2. The **first-level dependency** (user-preferences) looks slow, but it's also mostly waiting.
3. The **actual bottleneck** is two levels deep: an ML model inference call that takes 1.78 seconds.

Without traces, you might optimize the wrong service. Metrics would tell you "user-preferences is slow" but not *why*. Only the trace shows the full chain: recommendation-api → user-preferences → ml-model → inference.

---

> **Sarah:** "This is why I love traces. Two minutes of reading a waterfall diagram told us more than an hour of staring at CPU charts. The ML model is the bottleneck, and now the ML team knows exactly what to optimize."

**Next:** [Challenge 03 — Build a Dashboard](03-build-a-dashboard.md)
