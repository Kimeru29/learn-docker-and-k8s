# Lesson 4: Pods and Deployments

## The Smallest Thing That Runs

In Docker, the atomic unit is a **container**. In Kubernetes, the atomic unit is a **Pod**.

A Pod is a wrapper around one or more containers that:
- Share the same **network namespace** (they have one IP address between them)
- Share the same **storage volumes** (they can read/write the same mounted directories)
- Are always **scheduled together** on the same node
- Live and die together — if the Pod is deleted, all its containers go with it

In the vast majority of cases, a Pod contains exactly one container. Multi-container Pods are a real pattern (called "sidecar"), but start by thinking of Pod = container.

### Why Not Just Use Containers Directly?

Kubernetes doesn't schedule containers — it schedules Pods. This indirection exists because:

1. Some workloads genuinely need tightly-coupled processes (a web server + a log shipper that must run on the same machine and share a volume)
2. The Pod abstraction gives K8s a consistent unit regardless of what's inside

The practical consequence: you'll always write Pod specs, never bare container specs.

---

## Pod YAML Anatomy

Every Kubernetes resource is defined in a YAML manifest. Here's the most minimal Pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: learn-nginx-pod
  namespace: learn-ch09
  labels:
    app: nginx
    world: w03
    chapter: ch09
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
```

Let's walk through every field:

**`apiVersion: v1`**
The API version that defines this resource type. Pods use the core API (`v1`). Other resources use group-versioned APIs like `apps/v1` (Deployments) or `networking.k8s.io/v1` (Ingress).

**`kind: Pod`**
The type of resource. K8s uses this to know which schema to validate against and which controller to hand it off to.

**`metadata`**
Data *about* the resource.
- `name`: The unique identifier for this resource within its namespace
- `namespace`: Which namespace this resource belongs to
- `labels`: Key-value pairs attached to the resource. Labels are how Kubernetes resources find each other — Services, Deployments, and others use label selectors to target specific Pods.

**`spec`**
The desired state — what you actually want to run.
- `containers`: A list of containers in this Pod
- `name`: A name for this specific container (for logs and exec commands)
- `image`: The container image, same format as Docker (`image:tag`)
- `ports`: Informational only — K8s doesn't use this for network rules, but it documents intent and some tools read it

### The Four Universal Fields

Every Kubernetes resource (Pod, Deployment, Service, ConfigMap, etc.) has these four top-level fields:

| Field | Purpose |
|-------|---------|
| `apiVersion` | Which API schema defines this resource |
| `kind` | What type of resource this is |
| `metadata` | Identity: name, namespace, labels, annotations |
| `spec` | Desired state: what you want |

Once you know these four fields, every K8s manifest becomes readable.

---

## Why You Rarely Create Pods Directly

Here's a trap beginners fall into: creating Pods directly.

```bash
kubectl apply -f pod.yaml   # Creates the Pod
kubectl delete pod learn-nginx-pod -n learn-ch09  # Pod is gone — and stays gone
```

When you delete a Pod directly, it's gone. Nobody recreates it. There's no self-healing.

Pods on their own are mortal. They don't self-heal. For self-healing and scaling, you need a **Deployment**.

---

## Deployments: Declaring Desired State

A **Deployment** is a higher-level resource that manages a set of identical Pods. You tell it:
- What container image to run
- How many replicas you want
- How to roll out updates

The Deployment creates a **ReplicaSet**, which creates and manages the actual Pods. The chain looks like this:

```
Deployment          ← You manage this
  └── ReplicaSet    ← Deployment manages this
        ├── Pod (replica 1)   ← ReplicaSet manages these
        ├── Pod (replica 2)
        └── Pod (replica 3)
```

You typically interact with the Deployment (not the ReplicaSet directly). The ReplicaSet is an implementation detail that Kubernetes manages for you. When you do a rolling update, the Deployment creates a *new* ReplicaSet with the updated image and scales the old one down.

### Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-nginx
  namespace: learn-ch09
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch09
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        world: w03
        chapter: ch09
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
```

#### New Fields Explained

**`spec.replicas: 3`**
How many Pod copies you want running. The ReplicaSet controller ensures this count is always maintained.

**`spec.selector.matchLabels`**
This is how the Deployment knows *which Pods it owns*. Any Pod with `app: nginx` in its labels is considered part of this Deployment. This selector must match the labels in `spec.template.metadata.labels` — if they don't match, the Deployment won't work.

**`spec.template`**
A Pod template — the blueprint for every Pod this Deployment creates. It has `metadata` (with labels) and `spec` (with containers), just like a standalone Pod manifest.

**`resources.requests` and `resources.limits`**
- `requests`: What the container is *guaranteed* to get. The Scheduler uses this to decide which node has enough room.
- `limits`: The maximum the container can use. If it exceeds the memory limit, it gets OOMKilled.
- CPU is measured in millicores: `100m` = 0.1 CPU core
- Memory uses standard suffixes: `64Mi` = 64 mebibytes

Setting resource limits is considered a best practice for production. Without them, a single runaway process can starve other Pods on the node.

---

## Labels and Selectors: The Glue

Labels are the most important organizational concept in Kubernetes. They're how resources find and refer to each other.

```yaml
# On a Pod
metadata:
  labels:
    app: nginx          # Application name
    world: w03          # Game world
    chapter: ch09       # Chapter
    version: "1.25"     # App version
```

Labels are arbitrary key-value pairs. You define the schema — K8s doesn't enforce any particular labels (though some tools expect certain ones like `app`).

**Selectors** are how other resources match labels:

```yaml
# On a Deployment — "I manage Pods with app=nginx"
selector:
  matchLabels:
    app: nginx

# On a Service — "I route to Pods with app=nginx"
selector:
  app: nginx
```

The relationship is always: **the selector on resource A matches the labels on resource B**. This decoupling means you can change which Pods a Service targets by changing labels, without editing the Service.

```bash
# See labels on Pods
kubectl get pods -n learn-ch09 --show-labels

# Filter Pods by label
kubectl get pods -n learn-ch09 -l app=nginx
kubectl get pods -n learn-ch09 -l world=w03,chapter=ch09
```

---

## The ReplicaSet and Self-Healing

When you apply the Deployment above, here's what happens internally:

1. You POST the Deployment manifest to the API Server
2. API Server stores it in etcd
3. The Deployment controller creates a ReplicaSet with `replicas: 3`
4. The ReplicaSet controller notices 0 Pods exist but 3 are desired — creates 3 Pod specs
5. The Scheduler assigns each Pod to a node
6. kubelet on each node pulls the image and starts the container
7. The ReplicaSet controller watches for changes. If a Pod dies, it creates a replacement.

Step 7 is the self-healing loop. It runs constantly, not just at startup.

---

## Essential kubectl Commands

### Applying Manifests

```bash
# Apply a manifest (create or update)
kubectl apply -f deployment.yaml

# Apply everything in a directory
kubectl apply -f ./manifests/

# Delete resources defined in a manifest
kubectl delete -f deployment.yaml
```

`kubectl apply` is idempotent — you can run it multiple times safely. It compares the manifest to the current cluster state and applies only the differences.

### Getting Resource Status

```bash
# List Pods in the learn-ch09 namespace
kubectl get pods -n learn-ch09

# List Pods with more detail (node, IP address)
kubectl get pods -n learn-ch09 -o wide

# List Deployments
kubectl get deployments -n learn-ch09

# List ReplicaSets
kubectl get replicasets -n learn-ch09

# Watch resources in real time
kubectl get pods -n learn-ch09 --watch
```

**STATUS column cheat sheet:**

| Status | Meaning |
|--------|---------|
| `Pending` | Scheduled but not yet started (pulling image, waiting for node) |
| `Running` | All containers are running |
| `CrashLoopBackOff` | Container keeps crashing; K8s keeps trying with backoff |
| `ImagePullBackOff` | Can't pull the container image (bad tag, no registry access) |
| `Terminating` | Pod is being deleted |
| `OOMKilled` | Container exceeded its memory limit and was killed |
| `Completed` | Container ran to completion (for Jobs) |

### Inspecting Resources

```bash
# Full details on a Pod (events, conditions, container state)
kubectl describe pod <pod-name> -n learn-ch09

# Full details on a Deployment
kubectl describe deployment learn-nginx -n learn-ch09

# Get the YAML of a running resource
kubectl get deployment learn-nginx -n learn-ch09 -o yaml
```

`kubectl describe` is your first debugging tool. The **Events** section at the bottom tells the story of what happened to a resource — image pull failures, scheduling errors, probe failures, all appear there.

### Reading Logs

```bash
# Logs from a specific Pod
kubectl logs <pod-name> -n learn-ch09

# Follow logs in real time
kubectl logs <pod-name> -n learn-ch09 -f

# Logs from a previous container instance (useful after CrashLoopBackOff)
kubectl logs <pod-name> -n learn-ch09 --previous

# Logs from all Pods with a specific label
kubectl logs -l app=nginx -n learn-ch09
```

### Scaling and Rolling Updates

```bash
# Scale to 5 replicas imperatively
kubectl scale deployment learn-nginx --replicas=5 -n learn-ch09

# Check rollout status
kubectl rollout status deployment/learn-nginx -n learn-ch09

# See rollout history
kubectl rollout history deployment/learn-nginx -n learn-ch09

# Rollback to previous version
kubectl rollout undo deployment/learn-nginx -n learn-ch09
```

---

## Summary

| Concept | What it is |
|---------|-----------|
| Pod | The smallest deployable unit; wraps one or more containers sharing network and storage |
| Deployment | Declares desired state for a set of Pods; manages rolling updates and self-healing |
| ReplicaSet | Maintained by Deployment; ensures the correct number of Pod replicas are running |
| Labels | Key-value pairs attached to resources; the primary mechanism for inter-resource relationships |
| Selectors | Filter expressions that match resources by their labels |
| `kubectl apply` | Apply a manifest (create or update) — idempotent |
| `kubectl get` | List resources and their status |
| `kubectl describe` | Full details + events for a resource |
| `kubectl logs` | Container output |
| `resources.requests` | Guaranteed resources; used by Scheduler for placement |
| `resources.limits` | Maximum resources; exceeding memory limit causes OOMKill |

---

Time to put it all into practice. Head to the challenges.

**Challenges:**
- [Challenge 1: Self-Healing](../challenges/01-self-healing.md)
- [Challenge 2: Explore Architecture](../challenges/02-explore-architecture.md)
- [Challenge 3: Debug ImagePullBackOff](../challenges/03-debug-imagepullbackoff.md)
