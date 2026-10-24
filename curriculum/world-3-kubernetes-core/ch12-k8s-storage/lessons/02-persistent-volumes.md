# Lesson 2: Persistent Volumes

## The Problem

emptyDir dies with the Pod. hostPath is node-specific and dangerous. ConfigMaps and Secrets are for configuration, not data.

You need storage that:
1. **Survives Pod deletion** — data persists even when the Pod is gone
2. **Reattaches on restart** — when a new Pod starts, it gets the same data
3. **Is portable** — works across nodes (in most setups)
4. **Is manageable** — you can provision, resize, and reclaim it

Kubernetes solves this with the **PersistentVolume (PV) and PersistentVolumeClaim (PVC)** model.

---

## The PV/PVC Model

Think of it like renting storage:

- **PersistentVolume (PV):** A piece of storage that has been provisioned in the cluster. It's the "physical" storage — like a hard drive available for use.
- **PersistentVolumeClaim (PVC):** A request for storage by a Pod. It's the "lease" — "I need 10Gi of ReadWriteOnce storage."

```
Cluster Admin provisions → PV (10Gi, ReadWriteOnce)
                              │
Developer requests     → PVC (10Gi, ReadWriteOnce)
                              │
                              ▼
                          PVC binds to PV
                              │
Pod mounts             → PVC (by name)
                              │
                              ▼
                          Pod reads/writes data
```

The key insight: **PVCs are what Pods mount, not PVs directly.** This abstraction separates "I need storage" (developer) from "here's where the storage lives" (admin/provisioner).

---

## PersistentVolume (PV)

A PV is a cluster-level resource (not namespaced). It describes a piece of storage:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: learn-pv-manual
  labels:
    app: learn-docker-k8s
    world: w03
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /data/learn-pv
```

**Key fields:**

**`capacity.storage`** — How much storage this PV offers.

**`accessModes`** — How the volume can be mounted:

| Mode | Abbreviation | Meaning |
|------|-------------|---------|
| `ReadWriteOnce` | RWO | Mounted as read-write by a **single node** |
| `ReadOnlyMany` | ROX | Mounted as read-only by **many nodes** |
| `ReadWriteMany` | RWX | Mounted as read-write by **many nodes** |

Most block storage (AWS EBS, Azure Disk, GCE PD) only supports RWO — one node at a time. Network file systems (NFS, EFS, Azure Files) support RWX.

> ⚠️ RWO means one **node**, not one Pod. Multiple Pods on the same node can read/write the same RWO volume.

**`persistentVolumeReclaimPolicy`** — What happens when the PVC is deleted:

| Policy | What Happens |
|--------|-------------|
| `Retain` | PV is kept; data is preserved. Admin must manually reclaim. |
| `Delete` | PV and underlying storage are deleted. Data is gone. |
| `Recycle` | Deprecated. Don't use. |

`Retain` is safer for production — you don't accidentally delete data. `Delete` is convenient for ephemeral environments.

**`storageClassName`** — Links the PV to a StorageClass (covered in Lesson 3). PVCs request a specific StorageClass, and binding only happens between matching PVs and PVCs.

---

## PersistentVolumeClaim (PVC)

A PVC is a namespaced resource — it lives in the same namespace as the Pod that mounts it.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: learn-db-data
  namespace: learn-ch12
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch12
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
```

The PVC says: "I need 1Gi of ReadWriteOnce storage from StorageClass `manual`."

### The Binding Process

When you create a PVC, Kubernetes looks for a PV that:
1. Has enough capacity (>= requested storage)
2. Has a matching access mode
3. Has a matching StorageClass
4. Is in `Available` status (not already bound)

If a match is found, the PVC is **bound** to the PV:

```bash
kubectl get pvc -n learn-ch12
# NAME            STATUS   VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS
# learn-db-data   Bound    learn-pv-manual   1Gi        RWO            manual
```

If no match is found, the PVC stays in **Pending** status until a matching PV becomes available.

---

## Mounting a PVC in a Pod

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-db
  namespace: learn-ch12
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        world: w03
        chapter: ch12
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_PASSWORD
              value: "nocappuccino123"
            - name: PGDATA
              value: "/var/lib/postgresql/data/pgdata"
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: db-storage
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
      volumes:
        - name: db-storage
          persistentVolumeClaim:
            claimName: learn-db-data
```

The Pod references the PVC by name in `volumes[].persistentVolumeClaim.claimName`. The PVC is bound to a PV, so the Pod gets the underlying storage.

**What happens when the Pod restarts:**
1. Pod is deleted
2. PVC remains (it's a separate resource)
3. PV remains (still bound to the PVC)
4. Data on the PV remains untouched
5. New Pod starts, mounts the same PVC
6. New Pod sees the same data

This is how databases survive Pod restarts.

---

## Static Provisioning: The Manual Way

With static provisioning, you create PVs manually before creating PVCs:

```
Step 1: Admin creates PV        → Available
Step 2: Developer creates PVC   → PVC binds to PV → Bound
Step 3: Pod mounts PVC          → Pod has persistent storage
```

This is tedious in practice. Every PVC needs a pre-created PV. If you need 100 databases, you need 100 PVs.

That's why dynamic provisioning exists (Lesson 3).

---

## PVC Lifecycle

```
PVC Created → Pending (waiting for PV)
                │
                ▼
           PV Found → Bound (PVC linked to PV)
                │
                ▼
         Pod mounts PVC → Data accessible
                │
                ▼
         Pod deleted → PVC remains Bound
                │
                ▼
         PVC deleted → Reclaim policy applies:
                         Retain: PV → Released (data preserved)
                         Delete: PV → Deleted (data gone)
```

Important: Deleting a Pod does **not** delete the PVC. Deleting a PVC triggers the reclaim policy on the PV. This separation prevents accidental data loss.

---

## Debugging PVC Issues

### PVC Stuck in Pending

```bash
kubectl get pvc -n learn-ch12
# STATUS: Pending
```

Common causes:
1. **No matching PV:** No PV with the right size, access mode, and StorageClass
2. **Wrong StorageClass:** PVC requests a StorageClass that doesn't exist
3. **Capacity mismatch:** PVC requests more storage than any available PV
4. **No dynamic provisioner:** If using dynamic provisioning, the StorageClass provisioner isn't running

Diagnostic:
```bash
kubectl describe pvc learn-db-data -n learn-ch12
# Look at Events section for the reason
```

### PV in Released State

After a PVC is deleted, the PV enters `Released` state (with `Retain` policy). It can't be bound to a new PVC without manual intervention:

```bash
# Check PV status
kubectl get pv

# To make it Available again, remove the claimRef
kubectl patch pv learn-pv-manual -p '{"spec":{"claimRef": null}}'
```

---

## Summary

| Concept | What it is |
|---------|-----------|
| PersistentVolume (PV) | Provisioned storage in the cluster; cluster-scoped |
| PersistentVolumeClaim (PVC) | Request for storage; namespace-scoped |
| Binding | PVC matches and attaches to a PV |
| Access modes | RWO (one node), ROX (many read-only), RWX (many read-write) |
| Reclaim policy | Retain (keep data), Delete (destroy data) |
| StorageClass | Groups PVs by type; enables dynamic provisioning |
| Static provisioning | Admin creates PVs manually before PVCs |

---

Up next: [Lesson 3 — Dynamic Provisioning](03-dynamic-provisioning.md)

Static provisioning works but doesn't scale. StorageClasses and dynamic provisioning create PVs automatically when PVCs are created.
