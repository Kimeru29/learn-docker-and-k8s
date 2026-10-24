# Challenge 4: Debug DNS

## Briefing

Dave just deployed a new microservice — the recommendation engine. It should call the backend API by Service name. But it's getting `NXDOMAIN` errors. DNS resolution is failing.

"I created the Service! It's right there!" Dave insists.

Something is misconfigured. The Service exists but DNS doesn't resolve it. Your job: spin up a debug Pod, use DNS tools to diagnose the problem, and fix it.

---

## Objective

A Service exists but DNS resolution fails from within the cluster. Use a debug Pod to diagnose the issue using `nslookup`, find the misconfiguration, and fix it.

---

## The Broken Setup

Apply these resources:

**Recommendation Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-recommendations
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
spec:
  replicas: 2
  selector:
    matchLabels:
      app: recommendations
  template:
    metadata:
      labels:
        app: recommendations
        world: w03
        chapter: ch11
    spec:
      containers:
        - name: reco
          image: hashicorp/http-echo:latest
          args:
            - "-text=Recommended: Ethiopian Yirgacheffe"
            - "-listen=:8080"
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

**Broken Service (Dave's work):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-reco-svc
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
spec:
  type: ClusterIP
  selector:
    app: recomendations       # Dave's typo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

Apply both resources. Then try to reach the Service from a debug Pod:

```bash
kubectl run learn-dns-test --rm -it \
  --restart=Never \
  --image=busybox:1.36 \
  -n learn-ch11 \
  -- nslookup learn-reco-svc
```

---

## Your Tasks

1. Apply both manifests
2. Try to reach the recommendation service by name — it won't work
3. Use a debug Pod to check DNS resolution
4. Check Service Endpoints
5. Find the misconfiguration
6. Fix the Service so DNS resolves AND the Service routes to the Pods
7. Verify with a curl from inside the cluster

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] Deployment `learn-recommendations` exists with ready replicas
- [ ] Service `learn-reco-svc` exists in `learn-ch11`
- [ ] Service `learn-reco-svc` has at least one Endpoint (Pods are backing it)
- [ ] In-cluster curl to `http://learn-reco-svc` returns a response

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

The DNS name resolves (the Service exists, so CoreDNS has a record for it). But after DNS resolves to the ClusterIP, the request still fails because the Service has no endpoints. The problem isn't DNS itself — it's what the Service points to.
</details>

<details>
<summary>Hint 2 — Checking Endpoints</summary>

Run `kubectl get endpoints learn-reco-svc -n learn-ch11`. If the endpoints list is empty (`<none>`), the Service's selector isn't matching any Pods. Compare the selector in the Service to the labels on the Pods: `kubectl get pods -n learn-ch11 -l app=recommendations --show-labels`.
</details>

<details>
<summary>Hint 3 — Finding the typo</summary>

Look at the Service's `spec.selector.app` value very carefully. Then look at the Pod's `metadata.labels.app` value. Do they match exactly? Remember: selectors are case-sensitive and exact-match. A single character difference means zero matches.
</details>

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Found a label selector mismatch. The Service was selecting `app: recomendations` (missing an 'm'), but the Pods had `app: recommendations`. Fixing the selector to match the Pod labels populated the Endpoints and made the Service functional.

**Why it works:** Services find backing Pods through label selectors. The EndpointSlice controller continuously watches for Pods matching the selector. If the selector has a typo, no Pods match, and the Service routes to nothing. Fixing the selector triggers an immediate re-evaluation, and the matching Pods appear in Endpoints.

**Real-world connection:** Selector mismatches are one of the most common Service debugging scenarios. The diagnostic workflow is always: check Endpoints → compare selector to Pod labels → fix the mismatch. In production, this often happens during refactoring when someone renames labels but forgets to update the Service.

**Interview angle:** "A Service returns no response. What's your debugging workflow?" — 1. Check Endpoints (are Pods backing it?). 2. If empty, compare the Service selector to Pod labels. 3. If Pods match but Service fails, check Pod readiness. 4. If DNS fails, check CoreDNS Pods and the kube-dns Service.

**Pro tip:** Use `kubectl get pods --show-labels` to see all labels at a glance. For complex selector debugging, `kubectl get pods -l app=recommendations` confirms whether the label filter returns results. If it returns Pods but the Service has no Endpoints, the Service selector is different from what you're testing.
