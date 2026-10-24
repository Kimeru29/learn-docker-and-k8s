# Challenge 3: Network Segmentation

## Briefing

The security team just flagged a concern: every Pod in the cluster can talk to every other Pod. The frontend can directly access the database. The monitoring agent can call the payment API. There's no network segmentation.

"This is how breaches happen," the auditor says. "If an attacker compromises the frontend, they have direct access to the database."

Time to implement NetworkPolicies. The goal: only allow the traffic paths that should exist, and deny everything else.

---

## Objective

Create NetworkPolicies that enforce proper traffic segmentation between frontend, backend, and database tiers.

---

## Setup

First, deploy the three-tier stack. Apply these resources in `learn-ch11`:

**1. Backend Deployment** (should already exist from Challenge 1)

**2. Database Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-database
  namespace: learn-ch11
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch11
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        world: w03
        chapter: ch11
    spec:
      containers:
        - name: database
          image: hashicorp/http-echo:latest
          args:
            - "-text=Database response: OK"
            - "-listen=:5432"
          ports:
            - containerPort: 5432
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
```

**3. Database Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: learn-database-svc
  namespace: learn-ch11
spec:
  selector:
    app: database
  ports:
    - port: 5432
      targetPort: 5432
```

## Requirements

Create the following NetworkPolicies in `learn-ch11`:

1. **`learn-deny-all`** — Default deny all ingress and egress traffic for all Pods in the namespace

2. **`learn-allow-dns`** — Allow all Pods to make DNS queries (UDP and TCP port 53 egress)

3. **`learn-allow-frontend-to-backend`** — Allow frontend Pods (`app: frontend`) to send traffic to backend Pods (`app: backend`) on port 5678

4. **`learn-allow-backend-to-database`** — Allow backend Pods (`app: backend`) to send traffic to database Pods (`app: database`) on port 5432

After applying, verify:
- Frontend can reach backend (via the Service)
- Frontend CANNOT reach database directly
- Backend can reach database
- No other Pod-to-Pod traffic is allowed

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] NetworkPolicy `learn-deny-all` exists in `learn-ch11`
- [ ] NetworkPolicy `learn-allow-dns` exists in `learn-ch11`
- [ ] NetworkPolicy `learn-allow-frontend-to-backend` exists in `learn-ch11`
- [ ] NetworkPolicy `learn-allow-backend-to-database` exists in `learn-ch11`
- [ ] Database Deployment `learn-database` exists

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

Start with the default-deny policy (empty `podSelector: {}` selects all Pods, `policyTypes: [Ingress, Egress]`). Then add allow rules for specific traffic. Remember: Pods won't even resolve DNS without an explicit DNS egress rule.
</details>

<details>
<summary>Hint 2 — Writing the allow rules</summary>

Each allow policy has a `podSelector` (which Pods it applies to) and `ingress`/`egress` rules. For "frontend can reach backend," the policy applies to backend Pods (`podSelector: {matchLabels: {app: backend}}`), with an ingress rule allowing traffic from frontend Pods (`from: [{podSelector: {matchLabels: {app: frontend}}}]`).
</details>

<details>
<summary>Hint 3 — Testing the policies</summary>

After applying the policies, test by exec-ing into a frontend Pod and trying to curl the backend and database. The backend curl should succeed; the database curl should timeout or be refused. Note: kindnet has limited NetworkPolicy support. If policies aren't enforced, install Calico CNI. The verify script checks that the policies exist (not enforcement, which is CNI-dependent).
</details>

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Implemented a defense-in-depth network segmentation: default-deny everything, then allow only the traffic paths that should exist (frontend→backend, backend→database, all→DNS).

**Why it works:** NetworkPolicies are additive firewall rules. When at least one NetworkPolicy selects a Pod, all traffic to/from that Pod is denied unless explicitly allowed. The `podSelector` determines which Pods the policy applies to, and `ingress`/`egress` rules define what's allowed.

**Real-world connection:** This is a standard security pattern called "micro-segmentation" or "zero trust networking." In production, every namespace should have a default-deny policy, and explicit allow rules for each legitimate traffic flow. This limits blast radius — if one service is compromised, the attacker can't reach services they shouldn't.

**Interview angle:** "How do you secure Pod-to-Pod communication in Kubernetes?" — NetworkPolicies. Start with default-deny, add specific allows. Mention that enforcement requires a compatible CNI (Calico, Cilium). Know the difference between `podSelector`, `namespaceSelector`, and `ipBlock`.

**Pro tip:** NetworkPolicies don't encrypt traffic — they only control which Pods can communicate. For encryption in transit, you'd need a service mesh (Istio, Linkerd) or mTLS. Also note: NetworkPolicies are namespace-scoped. A policy in namespace A can't affect Pods in namespace B.
