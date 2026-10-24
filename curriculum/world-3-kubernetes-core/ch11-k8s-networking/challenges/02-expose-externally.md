# Challenge 2: Expose Externally

## Briefing

The backend is working internally. But Marcus needs to demo the API to investors — from his laptop browser, not from inside a Pod.

"Can't you just... make it accessible from outside?" Marcus asks.

You can. A NodePort Service exposes a port on the cluster node that forwards traffic to your Pods. For a kind cluster, this is the simplest way to get external access.

---

## Objective

Create a NodePort Service that exposes the backend (or a new service) from outside the cluster. Verify you can reach it using `kubectl port-forward` or the node's IP + port.

---

## Requirements

1. Create a Deployment named `learn-web` in `learn-ch11`:
   - Image: `hashicorp/http-echo:latest`
   - Args: `-text=NoCappuccino is live!` and `-listen=:5678`
   - Replicas: 2
   - Pod labels: `app: web`, `world: w03`, `chapter: ch11`

2. Create a NodePort Service named `learn-web-nodeport` in `learn-ch11`:
   - Type: `NodePort`
   - Selector: `app: web`
   - Port: 80, targetPort: 5678
   - NodePort: 30080

3. Verify the Service has endpoints
4. Use `kubectl port-forward` to test access from your laptop:
   ```bash
   kubectl port-forward service/learn-web-nodeport 8080:80 -n learn-ch11
   # Then in another terminal: curl localhost:8080
   ```

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] Deployment `learn-web` exists in `learn-ch11` with at least 1 ready replica
- [ ] Service `learn-web-nodeport` exists in `learn-ch11`
- [ ] Service type is `NodePort`
- [ ] Service has at least one Endpoint

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

A NodePort Service is just like a ClusterIP Service but with `type: NodePort` and an optional `nodePort` field in the ports section. Everything else (selector, port, targetPort) works the same.
</details>

<details>
<summary>Hint 2 — Testing access</summary>

In kind, the node is a Docker container. You can use `kubectl port-forward` to test without worrying about kind's networking configuration. `kubectl port-forward service/learn-web-nodeport 8080:80 -n learn-ch11` creates a tunnel from localhost:8080 to the Service.
</details>

<details>
<summary>Hint 3 — Verifying the Service</summary>

Check that the Service has endpoints: `kubectl get endpoints learn-web-nodeport -n learn-ch11`. If endpoints are empty, the selector doesn't match. Then verify the nodePort: `kubectl get service learn-web-nodeport -n learn-ch11 -o jsonpath='{.spec.ports[0].nodePort}'`.
</details>

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Created a Deployment and a NodePort Service. The NodePort Service allocates both a ClusterIP (internal) and a nodePort (external). Traffic to the nodePort on any cluster node is forwarded to the Service's backing Pods.

**Why it works:** NodePort builds on ClusterIP. kube-proxy programs iptables rules that listen on the nodePort on every node. Traffic hitting that port is DNAT'd to the ClusterIP, which then distributes it to Pod IPs.

**Real-world connection:** NodePort is common in bare-metal and development clusters. In production cloud environments, you'd typically use a LoadBalancer Service (which provisions a cloud load balancer) or an Ingress Controller for HTTP routing.

**Interview angle:** "What's the difference between ClusterIP, NodePort, and LoadBalancer?" — ClusterIP: internal only. NodePort: adds external port on every node (30000-32767). LoadBalancer: adds a cloud-provisioned external IP. Each type includes the features of the previous type.

**Pro tip:** The nodePort range is 30000-32767 by default. If you omit `nodePort`, Kubernetes picks a random one in that range. In production, use Ingress instead of NodePort for HTTP services — Ingress gives you host/path routing, TLS, and a single entry point.
