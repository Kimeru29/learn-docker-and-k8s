```
  ___ _      ___   ___    _  __    _                _   _ _
 / __| |_   / _ \ / _ \  | |/ /  _| |__   __ _ _ __| |_(_) |_ ___ ___| |_ _   _ _ __ ___
| (__| ' \ | | | | (_) | | ' / | | | '_ \ / _` | '__| __| | __/ _ \/ __| __| | | | '__/ _ \
 \___|_||_| |_| |_|\___/  |_|\_\_,_|_.__/ \__,_|_|  \__|_|\__\___/\___|\__|_| |_|_| \___/

 ⎈ "The Giant Roaster"

    Single Docker Host 💀       Kubernetes Cluster 🚀
    .--------------.            .-----------------------.
    | app  app  app|            | Node 1     Node 2     |
    | 100% CPU     |            | ⎈ pod     ⎈ pod      |
    | OUT OF MEMORY|            | ⎈ pod     ⎈ pod      |
    '--------------'            |                       |
     one machine                | Node 3     auto-heal  |
     = one point                | ⎈ pod     ⎈ pod ← new|
       of failure               '-----------------------'
                                 self-healing + scaling

    (@_@;) Dave at 3 AM: "WHAT DO WE DO" 🆘
    (•‿•)  Sarah: "We Kubernetes." 😎
```

# Chapter 9: The Giant Roaster

## Story

It's 3:07 AM.

Your phone is going off like a fire alarm. Then your laptop. Then your watch, which you didn't even know had notifications enabled.

The screen glows in the dark: **50,000 concurrent users**. A coffee influencer with 2 million followers posted about NoCappuccino's limited-edition Nitro Cold Brew at midnight. The tweet went viral. The post is still going.

Your single Docker host is at 100% CPU. The load average looks like a phone number. The app is crawling, then timing out, then — nothing.

Dave's messages come in rapid-fire, each one more all-caps than the last:

> **Dave 3:08 AM:** THE APP IS DOWN
> **Dave 3:08 AM:** SARAH ARE YOU AWAKE
> **Dave 3:09 AM:** WHAT DO WE DO
> **Dave 3:09 AM:** CAN WE JUST RESTART THE SERVER
> **Dave 3:09 AM:** I AM RESTARTING THE SERVER

You type back before he can make it worse: *"Dave — step away from the keyboard. I've got this."*

You've been waiting for this moment. One machine was never going to be enough. You've read the docs. You've run the tutorials. You've been quietly setting up kind on your laptop for exactly this scenario.

It's time to stop running one Docker host and start running a **cluster**.

Time to meet Kubernetes.

---

## What You'll Learn

By the end of this chapter, you'll be able to:

- Explain why a single Docker host is a single point of failure and what orchestration solves
- Describe the K8s philosophy: declarative state, reconciliation loops, desired vs actual
- Map the Control Plane components: API server, etcd, scheduler, controller manager
- Map the Worker Node components: kubelet, kube-proxy, container runtime
- Explain how these components interact in the reconciliation loop
- Create a local Kubernetes cluster with kind
- Use `kubectl` to explore a cluster: get nodes, get pods -A, describe, cluster-info
- Understand kubeconfig and contexts
- Write Deployment and Pod YAML manifests
- Use `kubectl apply`, `kubectl get`, `kubectl describe`, `kubectl logs`
- Understand Pods, ReplicaSets, and Deployments — and why they form a hierarchy

---

## Prerequisites

- World 2 completed (especially Docker Compose)
- Docker installed and running
- **kind** installed: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
- **kubectl** installed: https://kubernetes.io/docs/tasks/tools/

```bash
docker --version
kind version
kubectl version --client
```

All three should print a version number without errors.

---

## Lessons

| # | Lesson | What You'll Learn |
|---|--------|-------------------|
| 01 | [Why Kubernetes](lessons/01-why-kubernetes.md) | Single point of failure, orchestration concepts, K8s philosophy |
| 02 | [K8s Architecture Deep Dive](lessons/02-k8s-architecture.md) | Control plane, worker nodes, reconciliation mechanics |
| 03 | [Your First Cluster](lessons/03-first-cluster.md) | kind setup, kubectl basics, exploring the cluster |
| 04 | [Pods and Deployments](lessons/04-pods-and-deployments.md) | Pod anatomy, Deployment YAML, ReplicaSets, core kubectl |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Self-Healing](challenges/01-self-healing.md) | Deploy nginx with 3 replicas, delete a pod, watch reconciliation |
| 02 | [Explore Architecture](challenges/02-explore-architecture.md) | Use kubectl to explore the control plane and answer questions |
| 03 | [Debug ImagePullBackOff](challenges/03-debug-imagepullbackoff.md) | Diagnose and fix a Deployment with a typo in the image name |

---

## Verification

Run `challenges/verify.sh` to check all three challenges at once:

```bash
bash curriculum/world-3-kubernetes-core/ch09-k8s-architecture/challenges/verify.sh
```

---

## The Underlying Concepts

Kubernetes is built on the **reconciliation loop** — an infinite cycle where the control plane compares the *desired state* (what you declared in your YAML) against the *actual state* (what's actually running), and takes action to close the gap.

This is why Kubernetes self-heals: you don't tell it "restart this Pod." You tell it "I want 3 replicas of this app running." When a Pod dies, K8s notices the actual count (2) doesn't match the desired count (3) and creates a new one.

The same principle underlies scaling, rolling updates, and node failure recovery. Every controller in Kubernetes follows this pattern. It's reconciliation all the way down.

---

## Post-Chapter Cliffhanger

Once all three challenges pass and the verify script goes green, come back here.

You kept NoCappuccino alive through the traffic spike. By 4 AM, all 3 replicas were running, self-healing was confirmed, and the influencer's followers were actually able to check out.

Dave sent a voice memo at 4:23 AM. You could hear the relief in his voice. "Sarah... you're a wizard. Also — is this kubernetes thing why the coffee machine has been running slow? Never mind. Get some sleep."

But as you lean back, you realize something. Everything is a Deployment. The batch migration job that Marcus wants to run once? A Deployment. The log collector that should run on every node? Also a Deployment. The database that needs stable identity? You guessed it — a Deployment.

There's a problem. Not everything behaves like a web server. Some things run once and stop. Some things need to run on every node. Some things need stable, ordered identity.

Time to learn the full workload toolkit.

See you in Chapter 10: **The Fleet**.
