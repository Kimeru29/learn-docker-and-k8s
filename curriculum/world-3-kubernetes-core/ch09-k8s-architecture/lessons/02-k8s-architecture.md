# Lesson 2: Kubernetes Architecture Deep Dive

## The Machine Behind the Magic

In Lesson 1, you learned *why* Kubernetes exists and the reconciliation philosophy. Now let's look at *how* it works — the actual components that make up a cluster and how they interact.

A Kubernetes cluster has two types of machines: the **Control Plane** (the brain) and **Worker Nodes** (the muscle).

```
┌─────────────────────────────────────────────────────┐
│                    Control Plane                     │
│                                                     │
│  ┌──────────────┐  ┌──────┐  ┌───────────────────┐ │
│  │  API Server  │  │ etcd │  │    Scheduler      │ │
│  └──────┬───────┘  └──┬───┘  └─────────┬─────────┘ │
│         │             │                │            │
│  ┌──────┴─────────────┴────────────────┴──────────┐ │
│  │           Controller Manager                    │ │
│  │  (ReplicaSet, Deployment, Node, Job, ...)      │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────┬──────────────────────────────┘
                       │  API calls (HTTPS)
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Worker Node │ │  Worker Node │ │  Worker Node │
│              │ │              │ │              │
│  ┌─────────┐ │ │  ┌─────────┐ │ │  ┌─────────┐ │
│  │ kubelet │ │ │  │ kubelet │ │ │  │ kubelet │ │
│  └─────────┘ │ │  └─────────┘ │ │  └─────────┘ │
│  ┌──────────┐│ │  ┌──────────┐│ │  ┌──────────┐│
│  │kube-proxy││ │  │kube-proxy││ │  │kube-proxy││
│  └──────────┘│ │  └──────────┘│ │  └──────────┘│
│  ┌──────────┐│ │  ┌──────────┐│ │  ┌──────────┐│
│  │containerd││ │  │containerd││ │  │containerd││
│  └──────────┘│ │  └──────────┘│ │  └──────────┘│
│  [Pods...]   │ │  [Pods...]   │ │  [Pods...]   │
└──────────────┘ └──────────────┘ └──────────────┘
```

---

## Control Plane Components

The Control Plane is the brain of the cluster. In production it runs on dedicated machines separate from workloads (often 3 or 5 for high availability). In kind (local), it runs as a Docker container on your laptop.

### API Server (`kube-apiserver`)

The **single entry point** for all cluster operations. Every command you run with `kubectl` is an HTTP request to the API Server. It:

1. **Authenticates** — who are you?
2. **Authorizes** — are you allowed to do this?
3. **Validates** — is this YAML well-formed and complete?
4. **Persists** — stores the validated resource in etcd

Nothing talks to etcd directly except the API Server. Nothing talks to other components except through the API Server. It's the central nervous system.

Think of it as NoCappuccino's order counter. Every order goes through it. Every barista checks it for their next task. Nobody goes to the kitchen directly.

```
kubectl apply    ──►  API Server  ──►  etcd (store)
                         │
                         ├──►  Scheduler (watches for unscheduled Pods)
                         ├──►  Controller Manager (watches for drift)
                         └──►  kubelet (watches for assigned Pods)
```

### etcd

A **distributed key-value store** that holds the entire cluster state. Every resource — every Pod definition, every Service, every ConfigMap, every Secret — lives in etcd as a key-value pair.

Key facts about etcd:

- It's the **single source of truth** for desired state
- Only the API Server reads/writes to it
- It uses the Raft consensus algorithm for consistency across replicas
- If etcd is lost without a backup, the cluster loses its "memory" — it doesn't know what should be running
- In production, etcd is typically a 3 or 5 node cluster for high availability

You almost never interact with etcd directly. But understanding that it exists helps you understand why `kubectl get` and `kubectl describe` always reflect the desired state — they're reading from etcd through the API Server.

### Scheduler (`kube-scheduler`)

When a new Pod is created but has no node assignment, the Scheduler picks one. Its decision process:

1. **Filtering** — eliminate nodes that can't run the Pod (insufficient CPU/memory, wrong node selector, taints the Pod doesn't tolerate)
2. **Scoring** — rank the remaining nodes by preference (spread workloads evenly, prefer nodes with the image already cached, respect affinity rules)
3. **Binding** — assign the Pod to the highest-scored node

The Scheduler doesn't start the Pod. It only makes the assignment by updating the Pod's `spec.nodeName` field in etcd. The kubelet on that node watches for this change and does the actual work.

Think of it as the barista manager deciding which barista handles which order. The manager doesn't make the coffee — they decide who makes it.

### Controller Manager (`kube-controller-manager`)

A collection of **controllers** running as a single process, each responsible for a specific resource type. Each controller runs its own reconciliation loop:

| Controller | Watches | Acts On |
|-----------|---------|---------|
| **ReplicaSet controller** | ReplicaSets + Pods | Creates/deletes Pods to match desired replica count |
| **Deployment controller** | Deployments | Creates/updates ReplicaSets during rolling updates |
| **Node controller** | Node heartbeats | Marks unreachable nodes, evicts their Pods |
| **Job controller** | Jobs + Pods | Creates Pods for batch tasks, tracks completion |
| **EndpointSlice controller** | Services + Pods | Updates EndpointSlices when backing Pods change |
| **ServiceAccount controller** | Namespaces | Creates default ServiceAccounts in new namespaces |

Each controller is independent. They don't coordinate with each other — they each watch the API Server for changes relevant to their resource type and react. This is why the system is resilient: a bug in one controller doesn't affect others.

**The ReplicaSet controller in detail (this is the reconciliation loop you'll see most):**

```
1. Watch API Server for ReplicaSet changes or Pod deletions
2. For each ReplicaSet:
   a. Count existing Pods with matching labels
   b. Compare to spec.replicas
   c. If too few: create new Pod specs (API Server → etcd → Scheduler picks node)
   d. If too many: delete excess Pods (oldest first by default)
3. Repeat
```

---

## Worker Node Components

Worker Nodes are the machines that actually run your containerized workloads. Each node runs three components:

### kubelet

An **agent** running on every worker node. It's the most important component on the node — it does the hands-on work:

1. Watches the API Server for Pods scheduled to this node
2. Pulls the container images (via the container runtime)
3. Starts and stops containers
4. Runs health checks (liveness, readiness, startup probes)
5. Reports Pod status and node status back to the API Server
6. Manages container logs and resource usage reporting

The kubelet is the reason the control plane knows what's actually running. Without kubelet reporting back, the controllers would be blind.

**Important:** kubelet runs as a system process on the node, not as a container. It has to be — it's responsible for starting all the containers. It can't be containerized because it needs to manage the container runtime.

### kube-proxy

Maintains **network rules** (iptables or IPVS) on each node to implement Service routing. When traffic arrives for a Service's ClusterIP, kube-proxy's rules ensure it gets forwarded to one of the Service's backing Pods.

kube-proxy watches the API Server for Service and EndpointSlice changes. When a Service is created, updated, or when its backing Pods change, kube-proxy updates the node's network rules.

You'll learn more about this in Chapter 11 (Networking). For now, know that kube-proxy is why Services work — it's the traffic cop at every intersection.

### Container Runtime

The software that actually runs containers. Kubernetes uses the **Container Runtime Interface (CRI)** to support multiple runtimes:

- **containerd** — the default in most modern K8s installations and kind
- **CRI-O** — common in OpenShift environments

As of Kubernetes 1.24, Docker (dockershim) is no longer supported as a runtime. kind uses containerd. When you specify `image: nginx:1.25` in a manifest, containerd pulls and runs it.

---

## How They All Interact: A Deployment in Motion

Let's trace what happens when you run `kubectl apply -f deployment.yaml` for a Deployment with `replicas: 3`:

```
Step 1: kubectl sends HTTP POST to API Server
        API Server validates, stores Deployment in etcd

Step 2: Deployment controller (in Controller Manager) notices
        new Deployment → creates a ReplicaSet

Step 3: ReplicaSet controller notices new ReplicaSet with
        replicas: 3, current Pods: 0
        → creates 3 Pod specs in etcd (nodeName: "")

Step 4: Scheduler notices 3 Pods with no nodeName
        → evaluates nodes, assigns each Pod to a node
        → updates Pod specs in etcd with nodeName

Step 5: kubelet on each assigned node notices new Pod
        → pulls the container image via containerd
        → starts the container
        → reports Pod status back to API Server

Step 6: kube-proxy on each node notices new Pods
        → updates iptables rules for any matching Services

Step 7: Controllers continue watching. If a Pod dies:
        → kubelet reports Pod status change
        → ReplicaSet controller detects gap (2 < 3)
        → creates new Pod spec → Scheduler assigns → kubelet starts
```

Notice: **no component tells another component what to do**. They all independently watch the API Server and react to changes. This is the "watch and react" architecture that makes Kubernetes resilient.

---

## The Control Loop, Mechanically

Let's get precise about what "reconciliation" means at the implementation level:

```
┌──────────────────────────────────────────────────────┐
│                    API Server                         │
│                                                       │
│  Deployment ──creates──► ReplicaSet ──creates──► Pods │
│   (desired)               (mechanism)     (actual)    │
│                                                       │
│  Each level watches the level it manages:             │
│    • Deployment controller watches Deployments        │
│    • ReplicaSet controller watches ReplicaSets + Pods │
│    • Scheduler watches unassigned Pods                │
│    • kubelet watches Pods assigned to its node        │
└──────────────────────────────────────────────────────┘
```

Every controller uses **watches** (long-polling HTTP connections to the API Server) to get notified of changes in near-real-time. When a Pod is deleted:

1. kubelet detects the container exited and reports to API Server
2. API Server updates the Pod status in etcd
3. ReplicaSet controller's watch fires — it re-counts Pods
4. Count < desired → create a new Pod spec
5. Scheduler's watch fires — assigns the new Pod to a node
6. kubelet's watch fires — starts the new container

This cascade happens in seconds for Pod-level failures. Node failures take longer (5 minutes by default) because the Node controller waits before declaring a node dead — it could just be a brief network partition.

---

## kind: Where It All Runs Locally

In a production cluster, control plane and worker nodes are separate machines. In **kind** (Kubernetes IN Docker), the entire cluster runs as Docker containers on your laptop:

```
Your Laptop
├── Docker Engine
│   ├── Container: learn-k8s-control-plane
│   │   ├── kube-apiserver
│   │   ├── etcd
│   │   ├── kube-scheduler
│   │   ├── kube-controller-manager
│   │   ├── kubelet
│   │   ├── kube-proxy
│   │   └── containerd (running your Pods as nested containers)
│   │
│   └── (optional: learn-k8s-worker, learn-k8s-worker2, ...)
```

Each kind "node" is a Docker container running all the K8s components needed for that node type. Your Pods run as containers *inside* these node containers. It's containers all the way down.

This is why kind is great for learning — it's a real Kubernetes cluster with real reconciliation, real etcd, real scheduling. The only difference from production is scale and where the nodes run.

---

## Summary

| Component | Type | Role |
|-----------|------|------|
| API Server | Control Plane | Central entry point; validates and persists all resources |
| etcd | Control Plane | Distributed key-value store; cluster's database |
| Scheduler | Control Plane | Assigns unscheduled Pods to nodes |
| Controller Manager | Control Plane | Collection of controllers running reconciliation loops |
| kubelet | Worker Node | Starts containers, runs probes, reports status |
| kube-proxy | Worker Node | Maintains iptables/IPVS rules for Service routing |
| containerd | Worker Node | Container runtime; pulls images and runs containers |

| Concept | What it means |
|---------|--------------|
| Watch | Long-polling HTTP connection to API Server for change notifications |
| Reconciliation | Compare desired to actual, take action to close the gap |
| etcd is the truth | All desired state lives in etcd; controllers read and react |
| No direct communication | Components don't talk to each other — they all talk to the API Server |

---

Up next: [Lesson 3 — Your First Cluster](03-first-cluster.md)

You understand the architecture on paper. Now let's build one and explore it with kubectl.
