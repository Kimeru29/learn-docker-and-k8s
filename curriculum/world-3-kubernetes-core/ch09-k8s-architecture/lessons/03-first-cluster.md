# Lesson 3: Your First Cluster

## Setting Up kind

**kind** (Kubernetes IN Docker) runs a full Kubernetes cluster as Docker containers on your laptop. Each node in the cluster is a Docker container. It's the fastest way to get a real K8s environment locally.

### Verify Your Prerequisites

```bash
docker --version          # Need Docker running
kind version              # Should print v0.x.x
kubectl version --client  # Should print Client Version
```

### Create Your Cluster

```bash
kind create cluster --name learn-k8s
```

This command:
1. Pulls the kind node image (a Docker image with K8s pre-installed)
2. Starts a Docker container acting as the control plane + worker node
3. Configures kubectl to point at this cluster

You'll see output like:
```
Creating cluster "learn-k8s" ...
 ✓ Ensuring node image (kindest/node:v1.x.x) ...
 ✓ Preparing nodes ...
 ✓ Writing configuration ...
 ✓ Starting control-plane ...
 ✓ Installing CNI ...
 ✓ Installing StorageClass ...
Set kubectl context to "kind-learn-k8s"
```

### Verify the Cluster

```bash
kubectl cluster-info --context kind-learn-k8s
kubectl get nodes
```

Expected output for `kubectl get nodes`:
```
NAME                     STATUS   ROLES           AGE   VERSION
learn-k8s-control-plane  Ready    control-plane   1m    v1.x.x
```

`STATUS: Ready` means the node is healthy and ready to accept workloads.

---

## Understanding kubeconfig

kubectl needs to know *which cluster* to talk to and *how to authenticate*. This configuration lives in `~/.kube/config` — a YAML file that stores connection details for one or more clusters.

### The Three Pieces

A kubeconfig has three main sections:

```yaml
# Simplified structure
clusters:
  - name: kind-learn-k8s
    cluster:
      server: https://127.0.0.1:PORT   # API Server address
      certificate-authority-data: ...    # TLS cert to verify the server

users:
  - name: kind-learn-k8s
    user:
      client-certificate-data: ...      # Your identity
      client-key-data: ...

contexts:
  - name: kind-learn-k8s
    context:
      cluster: kind-learn-k8s          # Which cluster
      user: kind-learn-k8s             # Which identity
      namespace: default                # Default namespace
```

- **Clusters** — where to connect (API Server URL + TLS cert)
- **Users** — how to authenticate (client cert, token, or cloud provider auth)
- **Contexts** — a cluster + user + default namespace combo

A context ties a cluster and user together. When you switch contexts, you switch which cluster kubectl talks to.

### Context Commands

```bash
kubectl config get-contexts       # List all contexts
kubectl config current-context    # Show active context
kubectl config use-context kind-learn-k8s  # Switch to a context
```

You should see `kind-learn-k8s` as your current context. This means all kubectl commands go to your local kind cluster, not any production cluster.

> ⚠️ **Real-world safety tip:** In production, teams often use tools like `kubectx` or shell prompt indicators to always know which cluster they're targeting. Accidentally running `kubectl delete` against production instead of dev is a real war story. Always check your context.

---

## Exploring the Cluster

Now that you have a running cluster, let's use kubectl to see what's already inside.

### What's Running in kube-system?

Kubernetes ships with several system components running as Pods in the `kube-system` namespace:

```bash
kubectl get pods -n kube-system
```

You'll see something like:
```
NAME                                             READY   STATUS    RESTARTS   AGE
coredns-5dd5756b68-4xk7r                        1/1     Running   0          5m
coredns-5dd5756b68-j8f2p                        1/1     Running   0          5m
etcd-learn-k8s-control-plane                     1/1     Running   0          5m
kindnet-abc12                                    1/1     Running   0          5m
kube-apiserver-learn-k8s-control-plane           1/1     Running   0          5m
kube-controller-manager-learn-k8s-control-plane  1/1     Running   0          5m
kube-proxy-xyz34                                 1/1     Running   0          5m
kube-scheduler-learn-k8s-control-plane           1/1     Running   0          5m
```

Look at this list and map it to the architecture from Lesson 2:
- `kube-apiserver` — the API Server
- `etcd` — the cluster database
- `kube-scheduler` — Pod placement
- `kube-controller-manager` — reconciliation controllers
- `kube-proxy` — network rules for Services
- `coredns` — DNS for Service name resolution
- `kindnet` — the CNI plugin for Pod networking

These are real Pods. Kubernetes manages its own infrastructure using Kubernetes. The control plane components run as **static Pods** — managed directly by kubelet on the control plane node, not by the API Server.

### Inspecting a Node

```bash
kubectl get nodes
kubectl describe node learn-k8s-control-plane
```

`kubectl describe node` gives you a wealth of information:

- **Roles:** `control-plane` (this node runs the control plane components)
- **Conditions:** Is the node Ready? Is it under memory or disk pressure?
- **Capacity:** How much CPU and memory the node has
- **Allocatable:** How much is available for Pods (capacity minus system reservations)
- **Non-terminated Pods:** What's currently running on this node
- **Allocated resources:** CPU and memory consumed by running Pods
- **Events:** Recent activity on this node

```bash
# Just see the conditions
kubectl get nodes -o wide

# Check what labels are on the node
kubectl get nodes --show-labels
```

### Listing All Resources

```bash
# List all namespaces
kubectl get namespaces

# List everything across all namespaces
kubectl get all -A
```

The `-A` flag means "all namespaces." Without it, kubectl only shows resources in the `default` namespace.

You'll see the system namespaces:
- `default` — where resources go if you don't specify a namespace
- `kube-system` — system components
- `kube-public` — cluster-wide readable resources (rarely used directly)
- `kube-node-lease` — node heartbeat leases (internal)

### Checking Events

Events are Kubernetes' activity log. They tell you what happened and when:

```bash
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

Events are critical for debugging. When something goes wrong, events tell the story — image pulls, scheduling decisions, probe failures, node conditions.

---

## Creating the Chapter Namespace

Kubernetes uses **namespaces** to isolate resources within a cluster. Think of them as folders. We'll do all our chapter work in `learn-ch09` to keep things organized and safe.

```bash
kubectl create namespace learn-ch09
kubectl get namespaces
```

You'll see the system namespaces plus your new `learn-ch09`.

For the rest of this chapter, most commands will include `-n learn-ch09` to target this namespace explicitly.

> **Why not just use `default`?** Namespaces provide isolation. When you're done with a chapter, you can delete the entire namespace and all its resources in one command. This is also how teams in production separate environments (dev, staging, prod) or teams (team-a, team-b).

---

## kubectl Cheat Sheet: The Essentials

You'll use these commands constantly. Memorize the first five; reference the rest.

```bash
# Create/update resources from a YAML file
kubectl apply -f <file.yaml>

# List resources
kubectl get pods -n <namespace>
kubectl get deployments -n <namespace>
kubectl get services -n <namespace>
kubectl get all -n <namespace>

# Detailed view of a resource
kubectl describe pod <pod-name> -n <namespace>
kubectl describe node <node-name>

# Read container logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> -f  # follow

# Run a command inside a container
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Delete resources
kubectl delete -f <file.yaml>
kubectl delete pod <pod-name> -n <namespace>

# Watch resources update in real time
kubectl get pods -n <namespace> --watch

# Get resource YAML (see what K8s stores internally)
kubectl get pod <pod-name> -n <namespace> -o yaml
```

### The `-o` flag (output format)

```bash
kubectl get pods -o wide          # Extra columns: node, IP
kubectl get pods -o yaml          # Full YAML representation
kubectl get pods -o json          # JSON format
kubectl get pods -o name          # Just the resource names
kubectl get pods -o jsonpath='{.items[*].metadata.name}'  # Extract specific fields
```

---

## Summary

| Concept | What it is |
|---------|-----------|
| kind | Tool to run a K8s cluster as Docker containers locally |
| kubeconfig | File (~/.kube/config) storing cluster connection details |
| Context | A cluster + user + namespace combo; determines where kubectl sends commands |
| Namespace | A virtual partition within a cluster for isolating resources |
| kube-system | Namespace where K8s system components run |
| Static Pods | Pods managed directly by kubelet, not the API Server |
| Events | Activity log for cluster resources; critical for debugging |
| `kubectl describe` | Detailed view including events, conditions, and configuration |
| `kubectl get -A` | List resources across all namespaces |

---

Up next: [Lesson 4 — Pods and Deployments](04-pods-and-deployments.md)

You have a running cluster and can explore it. Now let's deploy something.
