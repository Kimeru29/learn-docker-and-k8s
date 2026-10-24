# Challenge 02: K8s Service Routing

> "A Kubernetes Service is just iptables rules under the hood — at least in the default kube-proxy mode. Let's prove it."
> — Sarah

---

## The Situation

You have a Kubernetes cluster running (via kind). A Deployment with 2 replicas is exposed via a ClusterIP Service. Sarah wants you to find the iptables rules that kube-proxy created for this Service and explain how traffic gets from the ClusterIP to the actual pods.

---

## Setup

> ⚠️ This challenge requires a kind cluster. If you don't have one running from the main curriculum, create one:
> ```bash
> kind create cluster --name learn-k8s 2>/dev/null || true
> ```

Deploy the investigation target:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-dd-net-echo
  namespace: default
  labels:
    app: learn-docker-k8s
    track: deep-dive
spec:
  replicas: 2
  selector:
    matchLabels:
      app: learn-dd-net-echo
  template:
    metadata:
      labels:
        app: learn-dd-net-echo
        track: deep-dive
    spec:
      containers:
      - name: echo
        image: hashicorp/http-echo:latest
        args: ["-text=hello from NoCappuccino"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: learn-dd-net-echo-svc
  namespace: default
  labels:
    app: learn-docker-k8s
    track: deep-dive
spec:
  selector:
    app: learn-dd-net-echo
  ports:
  - port: 80
    targetPort: 5678
  type: ClusterIP
EOF
```

Wait for pods to be ready:

```bash
kubectl wait --for=condition=ready pod -l app=learn-dd-net-echo --timeout=60s
```

---

## Your Mission

### Part 1: Find the Service's ClusterIP

Get the ClusterIP assigned to `learn-dd-net-echo-svc`.

### Part 2: Find the Pod IPs

Get the IPs of both pods backing the Service.

### Part 3: Find the iptables Rules

Enter the kind node and find the iptables rules kube-proxy created for this Service. You need to find:

1. The `KUBE-SERVICES` rule that matches the ClusterIP
2. The `KUBE-SVC-*` chain that does load balancing
3. The `KUBE-SEP-*` chains that DNAT to individual pod IPs

### Part 4: Write the Report

Create `/tmp/learn-dd-net-k8s/report.txt`:

```
CLUSTER_IP=<the Service's ClusterIP>
POD_IP_1=<first pod's IP>
POD_IP_2=<second pod's IP>
SERVICE_PORT=80
TARGET_PORT=5678
IPTABLES_RULES_FOUND=yes
```

---

## Requirements

1. The Deployment `learn-dd-net-echo` must have 2 ready replicas
2. The Service `learn-dd-net-echo-svc` must exist
3. Report file at `/tmp/learn-dd-net-k8s/report.txt` with accurate data
4. `CLUSTER_IP` must match the actual Service ClusterIP
5. Both `POD_IP_1` and `POD_IP_2` must match actual pod IPs (order doesn't matter)

---

## Success Criteria

```bash
bash curriculum/deep-dives/advanced-networking/challenges/verify.sh
```

---

## Hints

<details>
<summary>Hint 1 — Getting the Service and Pod IPs</summary>

```
kubectl get svc learn-dd-net-echo-svc -o jsonpath='{.spec.clusterIP}'
kubectl get pods -l app=learn-dd-net-echo -o jsonpath='{.items[*].status.podIP}'
```

</details>

<details>
<summary>Hint 2 — Entering the kind node</summary>

Kind nodes are Docker containers. Enter one with:

```
docker exec -it learn-k8s-control-plane bash
```

Once inside, you can run iptables commands directly. Use:

```
iptables-save -t nat | grep <cluster-ip>
```

This will show all rules that reference the Service's ClusterIP.

</details>

<details>
<summary>Hint 3 — Reading the chains</summary>

The chain structure is:

1. `KUBE-SERVICES` matches the ClusterIP and jumps to a `KUBE-SVC-*` chain
2. `KUBE-SVC-*` uses probabilistic matching to distribute to `KUBE-SEP-*` chains
3. Each `KUBE-SEP-*` chain has a DNAT rule pointing to a specific pod IP:port

To see the full chain for your service:

```bash
# Find the SVC chain name:
iptables-save -t nat | grep <cluster-ip>

# Then find the SEP chains:
iptables-save -t nat | grep <KUBE-SVC-chain-name>
```

For the report, you just need to confirm the rules exist and the IPs match. Set `IPTABLES_RULES_FOUND=yes` after confirming.

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You traced the iptables rule chain that kube-proxy creates for a Kubernetes Service — from the `KUBE-SERVICES` entry point through `KUBE-SVC-*` load balancing to `KUBE-SEP-*` endpoint DNAT rules.

**Why it works:**
kube-proxy watches the Kubernetes API for Service and Endpoint changes. When it detects a new Service, it programs iptables rules on every node that intercept traffic destined for the Service's ClusterIP and DNAT it to one of the backing pod IPs. Load balancing is done using the iptables `statistic` module with random probability.

**Real-world connection:**
When a Service isn't routing traffic to pods, checking the iptables rules tells you exactly what's wrong: missing rules (kube-proxy isn't running), no KUBE-SEP entries (no endpoints — check if pods match the selector), or stale entries (pods were replaced but rules weren't updated).

**Interview angle:**
"How does a Kubernetes Service route traffic to pods?" This is a core K8s interview question. The answer: kube-proxy (in iptables mode) creates DNAT rules for each Service. Traffic to the ClusterIP is intercepted by iptables, load-balanced across endpoint chains using random probability, and rewritten to a pod IP. Alternatives include IPVS mode (better for large clusters) and eBPF (Cilium).

**Pro tip:**
For large clusters with thousands of Services, iptables mode becomes slow — every packet traverses a long chain of rules. IPVS mode (`--proxy-mode=ipvs`) uses hash tables for O(1) lookup. Cilium replaces kube-proxy entirely with eBPF programs for even better performance.

</details>

---

## Cleanup

```bash
kubectl delete deployment learn-dd-net-echo 2>/dev/null
kubectl delete service learn-dd-net-echo-svc 2>/dev/null
rm -rf /tmp/learn-dd-net-k8s
```
