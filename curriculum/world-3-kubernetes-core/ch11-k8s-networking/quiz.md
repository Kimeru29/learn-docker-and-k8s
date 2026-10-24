# Chapter 11 Quiz: The Service Mesh

Use this quiz to test your understanding before moving to Chapter 12 — or to unlock Chapter 11 if you're skipping ahead. You need 4 out of 5 correct to pass.

---

## Question 1

A frontend Pod needs to call the backend API. The backend has 3 Pods running. Which approach should the frontend use?

**A)** Look up the backend Pod IPs using `kubectl get pods` and hardcode one in the frontend config.

**B)** Call the backend's Service by its DNS name (e.g., `http://learn-backend-svc`), which provides a stable endpoint regardless of Pod IPs.

**C)** Use `kubectl port-forward` to expose the backend, then call `localhost` from the frontend.

**D)** Create a NodePort Service and call the node's external IP from the frontend Pod.

<details>
<summary>Answer</summary>

**B** — Pod IPs are ephemeral; they change on every restart, scaling event, and rolling update. A Service provides a stable ClusterIP and DNS name. Hardcoding IPs (A) breaks whenever Pods restart. Port-forward (C) is for local developer access. NodePort (D) is for external access, not internal communication.
</details>

---

## Question 2

You run `kubectl get endpoints learn-backend-svc -n learn-ch11` and see `<none>`. What is the most likely cause?

**A)** The Service is still starting up. Wait a few more minutes.

**B)** The backend Pods haven't started yet.

**C)** The Service's `selector` does not match the labels on the backend Pods.

**D)** ClusterIP Services don't have Endpoints — only NodePort Services do.

<details>
<summary>Answer</summary>

**C** is the most likely cause. Kubernetes populates Endpoints by finding Pods whose labels match the Service's selector. If there's a typo or mismatch, no Pods match and Endpoints stays empty. All Service types have Endpoints (D is wrong). B is possible but less common than a selector mismatch. A is wrong — Service endpoint updates happen in seconds.
</details>

---

## Question 3

What is the difference between `port` and `targetPort` in a Service spec?

**A)** `port` is for TCP and `targetPort` is for UDP.

**B)** `port` is the port callers use to reach the Service; `targetPort` is the port the container is actually listening on.

**C)** `port` is the internal cluster port; `targetPort` is the external nodePort.

**D)** They are interchangeable — either can be used.

<details>
<summary>Answer</summary>

**B** — `port` is the Service's external-facing port (what callers use: `http://service:80`). `targetPort` is where traffic is forwarded to inside the container. This decoupling lets you change the container's listening port without changing the port that all callers use. They are not interchangeable (D), and neither is related to nodePort (C).
</details>

---

## Question 4

You apply a NetworkPolicy with `podSelector: {}` and `policyTypes: [Ingress, Egress]` and no ingress or egress rules. What happens?

**A)** Nothing — empty selectors are ignored.

**B)** All traffic in the namespace is allowed (the policy is a no-op).

**C)** All ingress and egress traffic for all Pods in the namespace is denied.

**D)** Only DNS traffic is denied; all other traffic is allowed.

<details>
<summary>Answer</summary>

**C** — An empty `podSelector: {}` selects all Pods in the namespace. Specifying `policyTypes: [Ingress, Egress]` without any allow rules means: deny all incoming and outgoing traffic. This is the "default deny" pattern — the first step in securing a namespace. After this, you add specific allow rules for legitimate traffic.
</details>

---

## Question 5

From a Pod in namespace `learn-ch11`, how do you call a Service named `learn-cache-headless` in namespace `learn-ch10`?

**A)** `curl http://learn-cache-headless` — DNS search domains handle it automatically.

**B)** `curl http://learn-cache-headless.learn-ch10` — you must include the target namespace.

**C)** `curl http://learn-ch10/learn-cache-headless` — namespace goes first in the URL.

**D)** You can't call across namespaces — Services are namespace-scoped.

<details>
<summary>Answer</summary>

**B** — The short form `learn-cache-headless` only resolves within the same namespace (thanks to search domains). For cross-namespace calls, include the namespace: `learn-cache-headless.learn-ch10`. The full FQDN is `learn-cache-headless.learn-ch10.svc.cluster.local`. Services are namespace-scoped (D is partially true — the Service lives in one namespace, but any Pod in the cluster can reach it with the right DNS name).
</details>

---

## Score

- **5/5** — Network ninja. Time for storage.
- **4/5** — Solid. One networking concept to review.
- **3/5 or below** — Review Services, DNS, and NetworkPolicies before continuing. Networking is where most K8s debugging happens.
