# Chapter 16 Quiz: Observability

> **Sarah:** "Five questions. These are the concepts that matter when you're staring at a dashboard at 2 AM and need to figure out what's actually happening."

---

## Question 1

Your application's Prometheus metrics show the following:

```promql
rate(http_requests_total{status="200"}[5m]) = 142
rate(http_requests_total{status="500"}[5m]) = 0.4
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) = 3.2
```

Meanwhile, `kubectl top pods` shows CPU at 15% and memory at 40% of limits.

**What does this data tell you?**

A) Everything is fine — CPU and memory are well within limits.

B) The system is healthy because the error rate is very low (0.28%).

C) There is likely an application-level performance issue — p99 latency is 3.2 seconds despite low resource usage, suggesting the bottleneck is I/O-bound (database, external service) rather than compute-bound.

D) The Prometheus metrics are inaccurate because `kubectl top` shows low resource usage.

<details>
<summary>Answer</summary>

**C.**

Low CPU and memory with high latency is the classic sign of an I/O-bound bottleneck — the application is waiting for something external (database query, API call, network), not doing computation. This is exactly the scenario from Challenge 01: infrastructure metrics are "green" but user experience is poor.

Option A and B focus on individual metrics in isolation. The RED method requires looking at Rate, Errors, AND Duration together. A p99 of 3.2s is likely unacceptable regardless of how "healthy" the CPU looks.

</details>

---

## Question 2

You need to measure how many HTTP requests your API processes per second. You have a Prometheus counter called `http_requests_total`.

**Which PromQL query gives you requests per second?**

A) `http_requests_total`

B) `http_requests_total / 60`

C) `rate(http_requests_total[5m])`

D) `sum(http_requests_total) by (status)`

<details>
<summary>Answer</summary>

**C.**

`rate()` calculates the per-second rate of change for a counter over the specified window. `rate(http_requests_total[5m])` gives you the average requests per second over the last 5 minutes.

Option A gives you the raw counter value (total requests since the process started), not a rate. Option B divides the total by 60, which is meaningless. Option D groups the total by status code but still doesn't give a rate.

</details>

---

## Question 3

In a distributed trace, the `user-preferences` service makes three internal calls:

- Cache lookup: 2ms (cache miss)
- Database query: 45ms
- External ML service: 1800ms

**What is the most impactful optimization?**

A) Switch from PostgreSQL to a faster database to reduce the 45ms query.

B) Implement cache warming or increase cache TTL to avoid the 2ms cache miss.

C) Optimize or cache the ML service response, since it accounts for 97% of the service's internal processing time.

D) Run the three calls in parallel to reduce total time.

<details>
<summary>Answer</summary>

**C.**

The ML service takes 1800ms out of 1847ms total (97%). Even eliminating the database query entirely saves only 45ms. Even running all three in parallel would still take ~1800ms because the ML call dominates.

The highest-impact optimization is caching the ML response (if the same user's preferences don't change often) or optimizing the ML model itself.

Option B is technically correct (cache hits would avoid the ML call entirely) but the framing says "cache miss" — the suggestion to increase TTL or warm the cache IS part of the right answer, but the core optimization is reducing dependence on the 1800ms ML call.

</details>

---

## Question 4

You're designing alerts for the NoCappuccino API. Which of these is the **best** alert?

A) `alert: HighCPU` — fires when CPU usage exceeds 80% for 1 minute.

B) `alert: PodRestarted` — fires every time a pod restarts.

C) `alert: ErrorRateHigh` — fires when the 5xx error rate exceeds 1% of total requests for 5 minutes.

D) `alert: MemoryIncreasing` — fires when memory usage increases by more than 10MB in any 5-minute window.

<details>
<summary>Answer</summary>

**C.**

This alert follows the principle of alerting on **symptoms, not causes**. A 1% error rate sustained for 5 minutes means real users are seeing errors, regardless of what's causing it (CPU, memory, bad deploy, external dependency).

Option A alerts on a cause (high CPU), which might be normal during a traffic spike. Option B has no duration window — a single self-healing restart isn't worth an alert. Option D would fire constantly during normal operation as memory naturally fluctuates.

Good alerts have: symptom-based condition, a meaningful duration (`for: 5m`), and a clear action (investigate error rate, check logs for error patterns).

</details>

---

## Question 5

NoCappuccino's SLO is: "99.9% of requests complete successfully within 500ms, measured over a 30-day window."

On day 15, you've consumed 60% of your error budget.

**What does this mean and what should you do?**

A) You're fine — 60% on day 15 of 30 means you're on track.

B) You're in trouble — at this rate you'll exhaust the error budget by day 25, leaving no margin. Prioritize reliability work over new features.

C) You should immediately roll back all recent deployments to preserve the remaining budget.

D) Error budgets don't matter if customers aren't complaining.

<details>
<summary>Answer</summary>

**B.**

Linear consumption of error budget means 60% consumed on day 15 puts you on pace to exhaust 100% by day 25 — with 5 days still remaining in the window. This means you're consuming reliability budget faster than sustainable.

The correct response is to shift priority toward reliability: investigate what's consuming the budget (bad deploys? infrastructure issues? traffic patterns?), reduce deployment velocity if recent changes are the cause, and focus on fixing the reliability issues before the budget runs out.

Option A is wrong — 60% by the halfway point means you're ahead of the "allowed" consumption rate (you should be at ~50% on day 15). Option C is an overreaction — you still have 40% budget. Option D ignores the entire purpose of SLOs and error budgets.

</details>

---

> **Sarah:** "Five for five? Good. You now understand the three pillars, how to use them together, and how to define 'healthy' with real numbers. That's observability — not just tools, but a way of thinking about systems."
