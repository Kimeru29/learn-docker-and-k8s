```
 __        __         _     _   _____
 \ \      / /__  _ __| | __| | |___ /
  \ \ /\ / / _ \| '__| |/ _` |   |_ \
   \ V  V / (_) | |  | | (_| |  ___) |
    \_/\_/ \___/|_|  |_|\__,_| |____/

  _  __     _                          _
 | |/ /   _| |__   ___ _ __ _ __   ___| |_ ___  ___
 | ' / | | | '_ \ / _ \ '__| '_ \ / _ \ __/ _ \/ __|
 | . \ |_| | |_) |  __/ |  | | | |  __/ ||  __/\__ \
 |_|\_\__,_|_.__/ \___|_|  |_| |_|\___|\__\___||___/

  ⎈  C O R E

     One Docker Host          →         A Cluster
    .--------------.              .-----------------------.
    | app  app  app |              | Node 1     Node 2     |
    | 100% CPU      |              | ⎈ pod     ⎈ pod      |
    | OUT OF MEMORY |              | ⎈ pod     ⎈ pod      |
    '--------------'              |                       |
     one failure                  | Node 3     auto-heal  |
     = total outage               | ⎈ pod     ⎈ pod ← new|
                                  '-----------------------'
                                   self-healing + scaling

    (@_@;) Dave: "THE SERVER MELTED"
    (•‿•)  Sarah: "Time for orchestration."
```

# World 3: Kubernetes Core

## From One Host to a Cluster

NoCappuccino survived the traffic spike — barely. But that night exposed the fundamental limit of a single Docker host: one machine, one point of failure, zero room for growth.

World 3 takes you from running containers on one machine to orchestrating them across a cluster. You'll learn how Kubernetes thinks (declarative desired state, reconciliation loops), how its components work together (API server, etcd, scheduler, controllers, kubelet), and how to deploy, network, and persist data in a K8s cluster.

By the end of this world, you'll be comfortable deploying workloads, debugging cluster issues, and understanding what's happening under the hood when things go wrong.

---

## Story Arc

A coffee influencer with 2 million followers tweeted about NoCappuccino's Nitro Cold Brew at midnight. 50,000 concurrent users hit the single Docker host. CPU pegged at 100%. Memory exhausted. The app went down.

Dave's solution: "Can't we just buy a bigger server?"

Sarah's answer: "We need a cluster. We need Kubernetes."

Across four chapters and a boss fight, you'll build NoCappuccino's Kubernetes infrastructure from scratch — starting with the architecture, deploying different workload types, connecting services through cluster networking, and making data survive pod restarts.

Then Saturday morning hits, and five things break at once.

---

## Chapters

| # | Chapter | Title | What You'll Learn |
|---|---------|-------|-------------------|
| 09 | [K8s Architecture](ch09-k8s-architecture/) | "The Giant Roaster" | Control plane, worker nodes, kind cluster, pods, deployments, kubectl |
| 10 | [Workloads](ch10-workloads/) | "The Fleet" | Jobs, CronJobs, StatefulSets, DaemonSets, labels, selectors |
| 11 | [K8s Networking](ch11-k8s-networking/) | "The Service Mesh" | Services, DNS, Ingress, NetworkPolicies, pod networking |
| 12 | [K8s Storage](ch12-k8s-storage/) | "The Persistent Roast" | PV, PVC, StorageClasses, dynamic provisioning, ConfigMap volumes |
| 🏆 | [Boss Fight](boss-k8s-incident/) | "The Cluster Crisis" | Five simultaneous K8s failures — triage them all |

---

## Competencies

This world develops the following competency areas:

| Competency | Description |
|-----------|-------------|
| `k8s-architecture` | Control plane, nodes, reconciliation, API objects, declarative state |
| `k8s-workloads` | Pods, Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs, CronJobs |
| `k8s-networking` | Services, Ingress, CoreDNS, NetworkPolicies, CNI concepts |
| `k8s-storage` | PV, PVC, StorageClasses, dynamic provisioning, StatefulSet storage |
| `k8s-configuration` | ConfigMaps, Secrets, env injection, volume mounts |

---

## Prerequisites

- **World 2: Docker Engineering** completed (especially Docker Compose, troubleshooting, and security fundamentals)
- Docker installed and running
- **kind** installed: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
- **kubectl** installed: https://kubernetes.io/docs/tasks/tools/

Verify your tools:

```bash
docker --version
kind version
kubectl version --client
```

All three should print a version number without errors.

---

## Estimated Time

**12–16 hours** across all chapters and the boss fight.

---

## Progression

Chapters are **linear** — each builds on the previous:

```
ch09 (Architecture) → ch10 (Workloads) → ch12 (Storage)
                    ↘                  ↗
                      ch11 (Networking)
                                        → Boss Fight
```

ch10 and ch11 both depend on ch09. ch12 depends on ch10. The boss fight requires all four chapters.

---

## Naming Convention

All Kubernetes resources in this world use:

- **Namespace:** `learn-chXX` (e.g., `learn-ch09`, `learn-ch10`)
- **Labels:** `app=learn-docker-k8s`, `world=w03`, `chapter=chXX`
- **Prefix:** `learn-` on all resource names
- **Cluster:** `learn-k8s` (kind cluster)

---

## After This World

When all four chapters and the boss fight are complete, you'll unlock:

- **World 4: Kubernetes Production** — health probes, deployment strategies, scheduling, security
- **Architecture Interview Mode** — design deployments for real scenarios and defend your tradeoffs
- **Deep Dive: Advanced Networking** — trace a packet from browser to pod through iptables and CNI
