```
  ___ _     _ ___   _  __    _           _
 / __| |_  / |_  ) | |/ /  _| |__   ___ | |_ ___  _ __ __ _  __ _  ___
| (__| ' \ | | / /  | ' < | | '_ \ / __|| __/ _ \| '__/ _` |/ _` |/ _ \
 \___|_||_||_|/___| |_|\_\_,_|_.__/ \__ \| || (_) | | | (_| | (_| |  __/
                                   |___/ \__\___/|_|  \__,_|\__, |\___|
                                                             |___/
 ⎈ "The Persistent Roast"

    Pod restarts → data gone?        PVC bound → data survives!
    ┌─────────────┐                  ┌─────────────┐
    │  Database   │                  │  Database   │
    │  Pod v1     │  ← deleted       │  Pod v2     │  ← recreated
    │  [data]     │                  │  [data]     │  ← same data!
    └──────┬──────┘                  └──────┬──────┘
           │                                │
           ✕ lost                    ┌──────┴──────┐
                                     │     PVC     │
                                     │  (persists) │
                                     └─────────────┘

    (◎_◎;) Dave: "Where did the data go?!"
    (•‿•)  Sarah: "It went with the Pod.
                    That's why we need PVCs."
```

# Chapter 12: The Persistent Roast

## Story

A customer support ticket just came in. Subject: "My order history is gone."

You check the logs. The database Pod restarted during a routine rolling update. When it came back, the database was empty. A fresh PostgreSQL instance with no data.

Dave is confused: "But I used volumes in Docker Compose! Why doesn't Kubernetes keep the data?"

"It does," you explain. "But you have to tell it to. Kubernetes volumes work differently from Docker volumes. You need a PersistentVolumeClaim."

This chapter is about making data survive Pod restarts — and understanding the storage model that makes it possible.

---

## What You'll Learn

By the end of this chapter, you'll be able to:

- Explain the difference between ephemeral and persistent storage in Kubernetes
- Use `emptyDir` for temporary shared storage between containers
- Understand when `hostPath` is appropriate (and when it's dangerous)
- Mount ConfigMaps and Secrets as volumes
- Explain the PersistentVolume (PV) and PersistentVolumeClaim (PVC) model
- Understand access modes (RWO, ROX, RWX) and reclaim policies
- Use StorageClasses for dynamic provisioning
- Diagnose PVC binding issues

---

## Prerequisites

- Chapter 10 completed (workload types, StatefulSets)
- kind cluster `learn-k8s` running

```bash
kubectl cluster-info --context kind-learn-k8s
kubectl create namespace learn-ch12
```

---

## Lessons

| # | Lesson | What You'll Learn |
|---|--------|-------------------|
| 01 | [Volumes in Pods](lessons/01-volumes-in-pods.md) | emptyDir, hostPath, ConfigMap, Secret volumes |
| 02 | [Persistent Volumes](lessons/02-persistent-volumes.md) | PV, PVC, access modes, reclaim policies, binding |
| 03 | [Dynamic Provisioning](lessons/03-dynamic-provisioning.md) | StorageClasses, automatic PV creation, volume expansion |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Persist Database](challenges/01-persist-database.md) | Deploy a database with a PVC, survive a Pod deletion |
| 02 | [Shared Storage](challenges/02-shared-storage.md) | Use ConfigMap volumes, update and verify propagation |
| 03 | [Storage Troubleshooting](challenges/03-storage-troubleshooting.md) | Diagnose and fix a PVC stuck in Pending |

---

## Verification

```bash
bash curriculum/world-3-kubernetes-core/ch12-k8s-storage/challenges/verify.sh
```

---

## Post-Chapter Cliffhanger

Once all three challenges pass, come back here.

The data is safe. Databases survive restarts. ConfigMaps propagate to Pods. Storage binds correctly. NoCappuccino's infrastructure has persistence.

Dave takes a deep breath. "So the data is really safe now? Like, even if I accidentally delete a Pod at 3 AM?"

"Especially then," you say. "That's the whole point."

A quiet Friday evening. You're about to close your laptop when five alerts fire simultaneously.

A Deployment stuck in CrashLoopBackOff. A Service routing to zero endpoints. A PVC stuck in Pending. A ConfigMap with the wrong connection string. And DNS resolution failing for one specific service.

The Saturday morning cluster crisis has arrived.

See you at the Boss Fight: **The Cluster Crisis**.
