# Interview Readiness Model

This document defines what "interview ready" means in measurable terms and provides calibration material for interview modes.

## Readiness Tiers

### Docker SWE Ready

The learner can confidently answer Docker questions in a backend/senior SWE interview.

**Required competencies (level 3 = competent or higher):**
- docker-cli
- dockerfile
- docker-storage
- docker-networking
- container-runtime
- docker-troubleshooting

**Required milestones:**
- World 1 boss fight passed
- At least one challenge in ch06 (process management) or ch07 (troubleshooting) passed

**Interview calibration:**
- Conceptual interview mode: >= 5 questions answered with >=70% rated "strong" or "adequate"

---

### Kubernetes SWE Ready

The learner can handle Kubernetes questions at the level expected of a backend or senior SWE working with cloud-native systems. Not SRE/CKA level.

**Required competencies (level 3 or higher):**
- All Docker SWE Ready competencies
- k8s-architecture
- k8s-workloads
- k8s-networking
- k8s-configuration
- k8s-health

**Required milestones:**
- World 1 + World 3 boss fights passed
- At least one challenge in ch13 (health/probes) passed

**Interview calibration:**
- Conceptual interview: >= 8 questions answered (mixed Docker + K8s) with >= 70% rated "strong" or "adequate"
- Troubleshooting interview: >= 3 scenarios attempted with >= 2 root causes correctly identified

---

### Platform-Literate Senior SWE

The learner demonstrates breadth across the container/orchestration/platform stack at a level that differentiates senior engineers.

**Required competencies (level 3 or higher):**
- All Kubernetes SWE Ready competencies
- k8s-scheduling
- k8s-security
- At least one of: observability, delivery, incident-response

**Required milestones:**
- World 4 boss fight passed

**Interview calibration:**
- Architecture interview: >= 2 design scenarios with trade-off reasoning rated "adequate" or better

---

## Answer Quality Scale

When the AI evaluates interview answers, use this 3-point scale:

| Rating | Meaning | Signals |
|--------|---------|---------|
| **Strong** | Correct, mechanistic understanding, mentions trade-offs or edge cases without prompting | Uses correct terminology; explains *why*, not just *what*; mentions production implications |
| **Adequate** | Correct core answer but lacks depth or misses nuances | Right answer but surface-level; doesn't explore trade-offs; needs follow-up to show depth |
| **Weak** | Incorrect, confused, or unable to answer | Wrong mechanism; confuses related concepts; guesses without reasoning |

Do not count a question as "answered" if the player skips it or says "I don't know" without attempting.

---

## How to Report Readiness

When the player asks "am I interview ready?" or the AI detects enough evidence, report:

```
=== Interview Readiness ===

Docker SWE Ready:     YES / NO / ALMOST (N competencies below threshold)
Kubernetes SWE Ready: YES / NO / ALMOST / NOT YET (prerequisites not met)
Senior Platform SWE:  YES / NO / ALMOST / NOT YET

Blocking competencies (if any):
  docker-networking: level 2 (practicing) — need level 3
  k8s-health: level 1 (introduced) — need level 3

Recommended next steps:
  1. Complete ch04 networking challenges
  2. Work through ch13 health probes
  3. Try the conceptual interview mode for Docker
```

The readiness check should be available at any time, not only at world boundaries.

---

## Curated Interview Calibration Questions

These anchor questions provide consistent evaluation across AI models and sessions. The AI should draw from these when running interview modes, supplementing with its own follow-ups.

### Docker — Core SWE

**Q1: Container fundamentals**
> "What happens when you run `docker run nginx`? Walk me through the steps."

Expected strong answer covers: image pull (if not cached), layer assembly, container creation (namespaces, cgroups), process startup as PID 1, network namespace, writable layer.
Adequate: mentions pull + start + isolation.
Weak: "it starts nginx."

Follow-up: "What's the difference between an image and a container?"

---

**Q2: Dockerfile layers and caching**
> "Why does the order of instructions in a Dockerfile matter for build speed?"

Expected strong answer: each instruction creates a layer; Docker caches layers; if a layer's inputs change, that layer and all subsequent layers are rebuilt. Putting `COPY package.json` before `COPY . .` means dependency install is cached when only source code changes.
Adequate: mentions caching but doesn't explain the invalidation cascade.
Weak: "it doesn't matter" or "for readability."

Follow-up: "What happens to the cache when you change one line in the middle of a Dockerfile?"

---

**Q3: Multi-stage builds**
> "What problem do multi-stage builds solve and how?"

Expected strong answer: final image doesn't contain build tools (compilers, SDKs), reducing size and attack surface. Build stage has everything needed to compile; final stage copies only the artifact. Mentions concrete size difference (e.g., Go image from 1GB to 20MB).
Adequate: mentions smaller images.
Weak: confuses with multi-container or doesn't understand the mechanism.

Follow-up: "When would you NOT use a multi-stage build?"

---

**Q4: ENTRYPOINT vs CMD**
> "Explain the difference between ENTRYPOINT and CMD. When would you use both together?"

Expected strong answer: ENTRYPOINT is the executable (hard to override), CMD provides default arguments (easily overridden). Together: ENTRYPOINT is fixed behavior, CMD is the overridable default. Mentions exec form vs shell form and the signal-forwarding implication.
Adequate: knows ENTRYPOINT is "the command" and CMD is "arguments" but misses override behavior.
Weak: thinks they're interchangeable.

Follow-up: "What happens to CMD when you pass arguments to `docker run`?"

---

**Q5: Container networking**
> "A container is running but `curl localhost:8080` from the host returns 'connection refused'. The container is healthy. What are the possible causes?"

Expected strong answer: no port mapping (`-p`), app binding to 127.0.0.1 inside the container instead of 0.0.0.0, wrong container port in `-p` mapping, firewall.
Adequate: identifies missing `-p` flag.
Weak: "the container is broken" or "restart it."

Follow-up: "What's the difference between the container's network namespace and the host's?"

---

### Docker — Senior SWE

**Q6: Signal handling and PID 1**
> "Your container takes exactly 10 seconds to stop every time you run `docker stop`. What's likely happening?"

Expected strong answer: the app doesn't handle SIGTERM; Docker waits the grace period then sends SIGKILL. Most common cause is shell form CMD wrapping the process in `/bin/sh` which doesn't forward signals. Fix: use exec form or add signal handler.
Adequate: knows about SIGTERM/SIGKILL but doesn't identify shell form as the cause.
Weak: "it's slow" or "increase the timeout."

Follow-up: "How would you diagnose this?"

---

**Q7: Image security**
> "You deleted a secret from a later layer in your Dockerfile. Is it still accessible?"

Expected strong answer: yes — image layers are immutable and additive. Even if you `RUN rm /secret` in a later layer, the file exists in the earlier layer and can be extracted with `docker history` or by inspecting layers directly. Fix: use build-time secret mounts or inject at runtime.
Adequate: knows layers are immutable but doesn't explain the extraction mechanism.
Weak: thinks deleting removes it.

Follow-up: "How would you handle build-time secrets properly?"

---

### Kubernetes — Core SWE

**Q8: Why Services exist**
> "Kubernetes Pods already have IP addresses. Why do you need Services?"

Expected strong answer: Pod IPs are ephemeral — they change on every restart, scaling event, and rolling update. Services provide a stable virtual IP and DNS name that abstracts over the changing set of Pods. Also provides load balancing across replicas.
Adequate: mentions stable endpoint but doesn't explain why Pod IPs change.
Weak: "for external access" (confuses Service with Ingress/LoadBalancer).

Follow-up: "What happens to the Service's endpoint list when a Pod fails its readiness probe?"

---

**Q9: Readiness vs Liveness probes**
> "What's the difference between a readiness probe and a liveness probe? Give an example where using the wrong one causes problems."

Expected strong answer: readiness removes Pod from Service endpoints (stops traffic); liveness kills and restarts the Pod. Example: if liveness probe checks a database dependency, and the database goes down, all Pods restart simultaneously even though the app is fine — it just can't reach the DB. Should use readiness for dependency checks, liveness only for "is the process irrecoverably broken."
Adequate: knows readiness = traffic, liveness = restart, but can't give the dependency example.
Weak: thinks they're the same or confuses which one restarts.

Follow-up: "When would you add a startup probe?"

---

**Q10: Reconciliation**
> "You `kubectl delete` a Pod that belongs to a Deployment with 3 replicas. What happens and why?"

Expected strong answer: ReplicaSet controller detects actual count (2) < desired count (3), creates a new Pod spec, scheduler assigns it to a node, kubelet starts it. This is the reconciliation loop — Kubernetes continuously compares desired state (in etcd) to actual state and takes corrective action.
Adequate: knows K8s creates a new Pod but can't explain the controller mechanism.
Weak: "the Pod comes back" without understanding why.

Follow-up: "What if you delete the ReplicaSet instead?"

---

### Kubernetes — Senior SWE

**Q11: Resource management**
> "A Pod keeps getting OOMKilled. Exit code 137. What's happening and how do you fix it?"

Expected strong answer: 137 = 128 + 9 (SIGKILL). The container exceeded its memory limit. Two possible causes: (1) limit is too low for the workload — increase it based on actual usage from `kubectl top`; (2) the app has a memory leak — the limit is correct but the app is broken. Discusses QoS classes (BestEffort is evicted first) and how requests vs limits affect scheduling.
Adequate: knows 137 = OOMKilled and suggests increasing the limit.
Weak: "restart it" or doesn't know what 137 means.

Follow-up: "What's the difference between CPU throttling and memory OOMKill?"

---

**Q12: Deployment strategies**
> "How would you deploy a new version of an application to Kubernetes with zero downtime?"

Expected strong answer: rolling update with readiness probes. New Pods must pass readiness before old Pods are terminated. Configure maxSurge and maxUnavailable. Mentions that without readiness probes, K8s will route traffic to Pods that aren't ready yet, causing errors during deployment. May mention canary or blue-green as alternatives.
Adequate: says "rolling update" but doesn't mention the readiness probe requirement.
Weak: "just apply the new YAML."

Follow-up: "The new version has a bug. How do you roll back?"

---

**Q13: RBAC**
> "What is RBAC in Kubernetes and why does it matter for application developers, not just admins?"

Expected strong answer: RBAC controls who/what can perform actions on which resources. Developers care because: (1) their ServiceAccount determines what their Pod can access in the K8s API; (2) a Pod with excessive permissions is a security risk; (3) CI/CD service accounts need scoped access. Mentions Role/ClusterRole and RoleBinding.
Adequate: knows RBAC is access control but frames it as only an admin concern.
Weak: doesn't know what RBAC stands for.

Follow-up: "Your Pod needs to read ConfigMaps in its own namespace. How would you set that up?"

---

### Architecture Design

**Q14: System design with containers**
> "Design the containerized deployment for a web application with a REST API, PostgreSQL database, and Redis cache. Start simple, then I'll add constraints."

This is a conversation, not a single answer. Evaluate across rounds:

Round 1 (basic): Docker Compose or K8s Deployments for API and Redis, StatefulSet or managed service for PostgreSQL, proper networking.
Round 2 (scale): "Traffic increased 10x." → HPA on the API, connection pooling, Redis as a shared cache.
Round 3 (reliability): "The API must have zero-downtime deployments." → readiness probes, rolling update strategy, PDB.
Round 4 (security): "Database credentials must not be in plain text." → K8s Secrets (mounted as files, not env vars), RBAC for least privilege.

Evaluate: architectural soundness, awareness of failure modes, trade-off articulation, practical knowledge vs theoretical.

---

### Docker — Troubleshooting

**Q15: Exit code diagnosis**
> "A container exits with code 137. What does that mean and what are the two most likely causes?"

Strong: 137 = 128 + 9 (SIGKILL). Either the container exceeded its memory limit (OOMKilled — check `docker inspect` for `OOMKilled: true`) or it was explicitly killed by `docker kill` or an orchestrator. Distinguishes between "limit too low" and "app has a memory leak."
Adequate: knows 137 means OOM but doesn't explain the math or differentiate causes.
Weak: "something crashed" without identifying SIGKILL.
Follow-up: "How would you distinguish a memory leak from an undersized limit?"

---

**Q16: Build cache invalidation**
> "You changed one line in your application code, but `docker build` re-runs `npm install` from scratch. Why?"

Strong: Dockerfile has `COPY . .` before `RUN npm install`. Every instruction depends on all previous layers. When `COPY . .` changes (any file changed), the cache is invalidated for that layer and all subsequent layers. Fix: copy `package.json` first, install, then `COPY . .`.
Adequate: mentions caching but doesn't explain the invalidation cascade.
Weak: "clear the cache" or "use --no-cache."
Follow-up: "What role does `.dockerignore` play in this?"

---

**Q17: Container vs host networking**
> "You're running a database inside a Docker container. From inside the container, you can connect to it on port 5432. From the host, you get 'connection refused'. What's happening?"

Strong: no `-p 5432:5432` port mapping. The container has its own network namespace. Without publishing the port, the service is only reachable inside the container's network or from containers on the same Docker network. Also considers: app binding to 127.0.0.1 instead of 0.0.0.0.
Adequate: identifies missing port mapping.
Weak: "the database isn't running."
Follow-up: "What if you needed another container to reach it but didn't want it exposed to the host?"

---

**Q18: Docker volume behavior**
> "You `docker rm` a container that was using a named volume. Is the volume also deleted?"

Strong: no. Named volumes persist independently of containers. `docker rm` only removes the container. The volume remains until explicitly `docker volume rm` or `docker volume prune`. This is by design — volumes are meant to persist data beyond container lifecycle. Anonymous volumes may be cleaned up by `docker system prune`.
Adequate: correctly says volume survives.
Weak: thinks volume is deleted with the container.
Follow-up: "What's the difference between a named volume and a bind mount in terms of lifecycle?"

---

### Docker — Senior SWE (continued)

**Q19: Distroless and scratch images**
> "What is a distroless or scratch base image, and when would you use one?"

Strong: `scratch` is an empty image — no OS, no shell, no utilities. Only works for statically compiled binaries (Go, Rust). `distroless` (from Google) has a minimal runtime (libc, ca-certificates) but no shell or package manager. Both reduce attack surface dramatically. Tradeoff: impossible to `docker exec` for debugging.
Adequate: knows they're small and secure but doesn't explain the debugging tradeoff.
Weak: confuses with Alpine.
Follow-up: "How would you debug a production issue in a container with no shell?"

---

**Q20: Health check vs readiness**
> "In Docker Compose, what does a health check actually do, and how is it different from Kubernetes readiness probes?"

Strong: Docker health check marks the container as `healthy`/`unhealthy` and can be used by `depends_on: condition: service_healthy` for startup ordering. It does NOT stop traffic — Docker doesn't have a Service abstraction. K8s readiness probes remove the Pod from Service endpoints, actually stopping traffic. Different mechanisms, different consequences.
Adequate: knows health checks exist in both but doesn't articulate the traffic-routing difference.
Weak: thinks they're the same thing.
Follow-up: "What happens if you use `restart: always` with a health check that keeps failing?"

---

### Kubernetes — Core SWE (continued)

**Q21: ConfigMap vs Secret**
> "When should you use a ConfigMap versus a Secret in Kubernetes?"

Strong: ConfigMaps for non-sensitive configuration (feature flags, URLs, config files). Secrets for sensitive data (passwords, tokens, certificates). Secrets are base64-encoded (not encrypted by default!), and etcd stores them — encryption at rest must be configured separately. Mounting secrets as files is safer than env vars because env vars are visible in `kubectl describe pod` and `/proc/<pid>/environ`.
Adequate: knows ConfigMap = config, Secret = sensitive, but thinks base64 = encrypted.
Weak: doesn't know the difference.
Follow-up: "Why is mounting secrets as environment variables considered less secure than mounting as files?"

---

**Q22: Namespace isolation**
> "A developer asks: 'If I deploy my app in a separate namespace, is it isolated from other namespaces?' What's your answer?"

Strong: namespaces provide logical separation (resource quotas, RBAC boundaries, name scoping) but NOT network isolation by default. Pods in different namespaces can communicate freely unless NetworkPolicies are applied. DNS works cross-namespace: `service-name.other-namespace.svc.cluster.local`.
Adequate: knows namespaces are logical but may not mention NetworkPolicies.
Weak: thinks namespaces provide full isolation.
Follow-up: "How would you prevent a pod in namespace A from reaching a pod in namespace B?"

---

**Q23: Why Pods not containers**
> "Why does Kubernetes have Pods instead of just running containers directly?"

Strong: a Pod is a group of containers that share network namespace (same IP, localhost communication) and storage. This enables sidecar patterns (log shippers, service mesh proxies, init containers for setup). The Pod is the atomic unit of scheduling — all containers in a Pod are co-located on the same node. Most Pods have one container, but the multi-container capability is fundamental to K8s architecture.
Adequate: mentions shared networking but doesn't explain sidecar patterns.
Weak: "Pods are just Kubernetes containers."
Follow-up: "Give me an example of when you'd put two containers in the same Pod."

---

**Q24: Label selectors**
> "Your Service shows 0 endpoints even though the Pods are Running. What's the most likely cause?"

Strong: label selector mismatch — the Service's `spec.selector` doesn't match the Pod's `metadata.labels`. Check with `kubectl get endpoints <svc>` (empty = selector issue) and `kubectl get pods --show-labels`. Also: Pods might be Running but not passing readiness probes (which removes them from endpoints).
Adequate: identifies selector mismatch.
Weak: "the Service is broken" or "restart it."
Follow-up: "How does the readiness probe affect whether a Pod appears in the endpoint list?"

---

### Kubernetes — Senior SWE (continued)

**Q25: StatefulSet vs Deployment**
> "When would you use a StatefulSet instead of a Deployment?"

Strong: StatefulSets for workloads needing stable network identity (pod-0, pod-1, pod-2), stable persistent storage (each replica gets its own PVC), and ordered startup/shutdown. Examples: databases, ZooKeeper, Kafka, Elasticsearch. Deployments are for stateless apps where any replica is interchangeable. StatefulSets require a headless Service.
Adequate: knows StatefulSets are for stateful apps but doesn't explain stable identity or ordered operations.
Weak: "use StatefulSets for databases, Deployments for everything else" without knowing why.
Follow-up: "What happens if a StatefulSet Pod is deleted — how is the replacement different from a Deployment Pod replacement?"

---

**Q26: CPU throttling vs OOMKill**
> "What's the difference between hitting a CPU limit and hitting a memory limit in Kubernetes?"

Strong: CPU: CFS throttling — the process gets fewer CPU cycles, runs slower, but is never killed. Invisible to K8s (no events, no restarts). Memory: the OOM killer terminates the process immediately (SIGKILL, exit 137). The Pod restarts. CPU is elastic (throttleable); memory is binary (you have it or you're dead).
Adequate: knows one throttles and the other kills.
Weak: thinks both restart the Pod.
Follow-up: "How do CPU limits interact with Java applications that detect 'available processors' at startup?"

---

**Q27: Node failure**
> "A worker node in your cluster loses network connectivity. What happens to the Pods running on that node?"

Strong: the kubelet stops sending heartbeats. After ~5 minutes (configurable via `--node-monitor-grace-period`), the node controller marks the node `NotReady`. After another timeout, it taints the node and begins evicting Pods. The Pods' owning controllers (Deployment, StatefulSet) create replacements on healthy nodes. For StatefulSets, the old Pod must be confirmed terminated before a replacement starts (to avoid split-brain). During the gap, the Service stops routing to those Pods (no heartbeat = no endpoints).
Adequate: knows Pods get rescheduled but doesn't explain the timing or StatefulSet caveat.
Weak: "Kubernetes immediately restarts them on another node."
Follow-up: "Why does Kubernetes wait 5 minutes before declaring a node dead?"

---

**Q28: Taints and tolerations**
> "Explain taints and tolerations. Give a practical example."

Strong: taints are applied to nodes ("don't schedule here unless you tolerate this"). Tolerations are applied to Pods ("I can handle this taint"). Example: taint GPU nodes with `gpu=true:NoSchedule` so only Pods with the corresponding toleration get scheduled there. Prevents regular workloads from wasting GPU resources. Also used for: dedicated nodes, node maintenance (`NoExecute` evicts existing Pods).
Adequate: knows the mechanism but gives only abstract examples.
Weak: confuses with node selectors or affinity.
Follow-up: "What's the difference between `NoSchedule`, `PreferNoSchedule`, and `NoExecute`?"

---

### Kubernetes — Troubleshooting

**Q29: ImagePullBackOff**
> "Your Deployment's Pods are stuck in ImagePullBackOff. Walk me through your diagnosis."

Strong: `kubectl describe pod` → Events section shows why the pull failed. Common causes: typo in image name/tag, private registry without imagePullSecrets, rate limiting (Docker Hub anonymous pulls), nonexistent tag, network issues. Check: is the image name correct? Can you `docker pull` it manually? Is imagePullSecrets configured if needed?
Adequate: checks events but doesn't enumerate common causes.
Weak: "just delete and recreate the Pod."
Follow-up: "How would you handle Docker Hub rate limits in a production cluster?"

---

**Q30: Pod stuck in Pending**
> "A Pod has been Pending for 10 minutes. How do you diagnose it?"

Strong: `kubectl describe pod` → Events. Pending means the scheduler couldn't place it. Common causes: insufficient CPU/memory on any node (requests exceed available), nodeSelector/affinity that matches no nodes, PVC stuck in Pending (wrong StorageClass), taints without tolerations, pod topology constraints. Check: `kubectl describe node` for allocatable vs requested resources.
Adequate: checks describe but doesn't systematically enumerate scheduler reasons.
Weak: "wait longer."
Follow-up: "How would you determine if the issue is resource pressure vs affinity constraints?"

---

**Q31: CrashLoopBackOff diagnosis**
> "Pods are in CrashLoopBackOff. What's your systematic approach?"

Strong: 1. `kubectl logs <pod>` (current and `--previous` for the crashed instance). 2. Check the exit code in `kubectl describe pod` (1 = app error, 127 = command not found, 137 = OOMKilled, 139 = segfault). 3. Check if the container starts then immediately dies (missing config, wrong command) vs runs for a while then crashes (memory leak, dependency failure). 4. Check probes — a liveness probe killing a slow-starting container creates CrashLoop. 5. Check resource limits — OOMKilled looks like CrashLoop.
Adequate: checks logs but doesn't use exit codes systematically.
Weak: "increase the restart backoff."
Follow-up: "How would you distinguish between a CrashLoop caused by a liveness probe vs one caused by an application bug?"

---

### Architecture — Design (continued)

**Q32: Stateless vs stateful migration**
> "Your team has a monolithic application with in-memory session storage. How would you containerize it for Kubernetes?"

Strong: in-memory sessions make the app stateful — if the Pod dies, sessions are lost. Three approaches: (1) externalize sessions to Redis/Memcached (best — makes the app stateless), (2) use sticky sessions via Service `sessionAffinity: ClientIP` (works but reduces load balancing effectiveness), (3) use StatefulSets (overkill for sessions). Recommends option 1 because it follows 12-Factor stateless process design and enables HPA without session loss.
Adequate: identifies the session problem but only proposes one solution.
Weak: "just deploy it as a Deployment."
Follow-up: "What happens to active user sessions during a rolling update if you choose option 1?"

---

**Q33: Database in Kubernetes**
> "Should you run your production database in Kubernetes? What are the tradeoffs?"

Strong: depends on team expertise and requirements. Running in K8s (StatefulSet + PVC): consistent deployment model, same monitoring, same CI/CD. But: storage performance depends on CSI driver, backups are more complex, operator expertise required. Managed databases (RDS, Cloud SQL): simpler operations, built-in backups, HA, but separate from K8s deployment model. Many teams use managed databases for production and K8s-hosted databases for dev/test. No universally right answer.
Adequate: identifies tradeoffs but has a strong opinion without nuance.
Weak: "always" or "never" without reasoning.
Follow-up: "If you do run PostgreSQL in K8s, what Kubernetes features would you use to ensure data safety?"

---

**Q34: Zero-downtime deployment design**
> "Walk me through designing a zero-downtime deployment pipeline for a REST API on Kubernetes."

Strong: covers the full chain: (1) readiness probes so new Pods only receive traffic when ready, (2) rolling update strategy with maxUnavailable=0 (always have enough capacity), (3) graceful shutdown (SIGTERM handling + terminationGracePeriodSeconds), (4) preStop hook with a short sleep to handle in-flight requests during endpoint de-registration, (5) PDB to survive voluntary disruptions, (6) health check endpoint that reflects actual readiness (DB connection, cache warm). Bonus: mentions that the preStop sleep handles the race between endpoint removal and traffic routing.
Adequate: mentions readiness probes and rolling updates but misses graceful shutdown or PDB.
Weak: "just do a rolling update."
Follow-up: "What's the race condition between endpoint de-registration and traffic routing, and how does a preStop hook fix it?"

---

**Q35: Observability strategy**
> "Your team is deploying microservices to Kubernetes. What's your observability strategy?"

Strong: three pillars — logs (structured, to stdout, aggregated centrally), metrics (RED method: rate/errors/duration for each service, USE method: utilization/saturation/errors for infrastructure, Prometheus for collection, Grafana for dashboards), traces (distributed tracing with OpenTelemetry for request flow across services). SLIs/SLOs to define what "healthy" means. Alerts on symptoms (error rate, latency) not causes (CPU usage). Avoids alert fatigue by alerting on SLO burn rate.
Adequate: mentions logs/metrics/traces but doesn't articulate the strategy.
Weak: "use Datadog" without understanding what to observe.
Follow-up: "How would you set up an SLO for your API and what would you alert on?"
