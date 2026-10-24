# Chapter 15 Quiz: Kubernetes Security

> **Sarah:** "Five questions. These are the security concepts that matter in real clusters."

---

## Question 1

A pod uses the `default` ServiceAccount in its namespace. A developer runs `kubectl auth can-i get secrets --as=system:serviceaccount:production:default -n production` and gets `yes`.

**What is the security risk, and how should you fix it?**

A) There is no risk — the default ServiceAccount should be able to read secrets so pods can function.

B) Every pod in the namespace can read every Secret, including database credentials and API keys. Fix: create dedicated ServiceAccounts with minimum permissions and set `automountServiceAccountToken: false` on pods that don't need API access.

C) The risk is minimal because Secrets are encrypted. Fix: enable etcd encryption.

D) The risk only exists if someone can exec into a pod. Fix: disable `kubectl exec`.

<details>
<summary>Answer</summary>

**B.**

If the default ServiceAccount can read secrets, every pod in that namespace — every container, every sidecar, every init container — can access every Secret in the namespace. If any of those containers is compromised (vulnerability, dependency injection, container escape), the attacker gets all secrets.

The fix is threefold:
1. Create dedicated ServiceAccounts with only the permissions each workload needs
2. Set `automountServiceAccountToken: false` on pods that don't need Kubernetes API access
3. Remove permissions from the default ServiceAccount

Option C is wrong — etcd encryption protects at-rest data but doesn't prevent API access. Option D is wrong — secrets can be exfiltrated through the token mounted at `/var/run/secrets/kubernetes.io/serviceaccount/`.

</details>

---

## Question 2

A Deployment has this security context:

```yaml
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

The container image's Dockerfile ends with `USER root`. **What happens when the pod starts?**

A) The pod starts successfully but runs as a non-root user because `runAsNonRoot` overrides the Dockerfile.

B) The pod fails to start with an error: the container wants to run as root but `runAsNonRoot: true` prevents it.

C) The pod starts but the root filesystem is read-only, so the container can't write any files and crashes.

D) The `capabilities: drop: ALL` causes the pod to fail because root requires capabilities.

<details>
<summary>Answer</summary>

**B.**

`runAsNonRoot: true` is a validation check, not a user override. It tells Kubernetes: "reject this container if it would run as root (UID 0)." Since the Dockerfile specifies `USER root`, the container's default user is UID 0, and the pod fails to start.

To fix this, either:
1. Change the Dockerfile to use a non-root user (`USER 1000`)
2. Add `runAsUser: 1000` to the security context to override the Dockerfile's USER instruction

Option A is wrong — `runAsNonRoot` doesn't change the user, it just prevents root. You need `runAsUser` to actually change the user.

</details>

---

## Question 3

Database credentials are passed to a pod as environment variables:

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-creds
        key: password
```

**Name two ways these credentials can be leaked, and what is the recommended alternative?**

A) Credentials can be leaked via `kubectl logs` and `kubectl get events`. The alternative is to use ConfigMaps instead.

B) Credentials can be leaked via `kubectl exec -- env` (shows all env vars) and `/proc/1/environ` (environment of PID 1 is readable). The alternative is to mount the Secret as a file.

C) Credentials cannot be leaked because they come from a Secret, which is encrypted.

D) Credentials can only be leaked if someone has `kubectl exec` access. The alternative is to disable exec.

<details>
<summary>Answer</summary>

**B.**

Environment variables are visible in multiple places:
- `kubectl exec <pod> -- env` prints all environment variables including secrets
- `/proc/1/environ` inside the container contains the full environment in plaintext
- `docker inspect` on the container shows the environment
- Any log output that prints the environment (common in debug mode)
- Core dumps include the process environment

The recommended alternative is **mounting the Secret as a file** at a specific path (e.g., `/etc/secrets/password`). File-mounted secrets are not visible in `env` output, `/proc/1/environ`, or `kubectl describe`. They're only readable by explicitly opening the file.

Option C is wrong — Secrets are base64-encoded, not encrypted. Even if etcd encryption is enabled, the Secret value is available in plaintext to any pod that references it.

</details>

---

## Question 4

You create this NetworkPolicy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

**Which of the following is true?**

A) Only frontend pods can reach the API on port 8080. The API can still reach any pod (egress is unaffected).

B) Only frontend pods can reach the API on any port. Other pods are blocked on all ports.

C) The API can only be reached by frontend pods on port 8080, AND the API can only send traffic to frontend pods.

D) This policy has no effect unless there is also a default-deny policy in the namespace.

<details>
<summary>Answer</summary>

**A.**

This NetworkPolicy:
- Applies to pods with `app: api` (the `podSelector`)
- Controls **Ingress** only (incoming traffic)
- Allows traffic from pods with `app: frontend` on TCP port 8080
- Implicitly denies all other ingress to `app: api` pods

Key points:
- **Egress is unaffected** because `policyTypes` only includes `Ingress`. The API can still reach any pod or external address.
- **No default-deny is needed** for this to take effect. Once any NetworkPolicy selects a pod, that pod's ingress is restricted to what the policies explicitly allow.
- The allowed port is specifically 8080, not all ports.

Option D is a common misconception. A NetworkPolicy takes effect the moment it selects a pod — it doesn't require a separate default-deny policy.

</details>

---

## Question 5

You want to enforce that no pod in the `production` namespace can run as root, use privileged mode, or mount host paths. **What is the recommended Kubernetes-native approach?**

A) Create a NetworkPolicy that blocks root containers.

B) Apply Pod Security Standards by labeling the namespace with `pod-security.kubernetes.io/enforce: restricted`.

C) Create an RBAC Role that denies `create` permissions for pods with root security contexts.

D) Set `runAsNonRoot: true` on every Deployment manually and hope no one forgets.

<details>
<summary>Answer</summary>

**B.**

Pod Security Standards (PSS) are the Kubernetes-native mechanism for enforcing security policies at the namespace level. By labeling a namespace:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

The Pod Security Admission controller rejects any pod that doesn't meet the `restricted` standard. This includes:
- Must run as non-root
- Must drop all capabilities
- No privileged mode
- No host namespaces or host paths
- Must set seccomp profile

Option A is wrong — NetworkPolicies control network traffic, not pod security contexts. Option C is wrong — RBAC controls API access (who can create/read/delete resources), not the content of those resources. Option D works but relies on human diligence and will eventually fail.

</details>

---

> **Sarah:** "Five for five? Good. RBAC, security contexts, secret management, network isolation, and Pod Security Standards. Those are the five pillars of Kubernetes security. The audit report is going to look very different next time."
