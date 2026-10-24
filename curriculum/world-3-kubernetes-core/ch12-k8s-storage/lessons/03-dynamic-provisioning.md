# Lesson 3: Dynamic Provisioning

## The Problem With Static Provisioning

Static provisioning requires an admin to create PVs before developers can create PVCs. For one database, this is fine. For 50 microservices that each need their own storage? That's 50 PVs to create and manage manually.

**Dynamic provisioning** solves this: when a PVC is created, Kubernetes automatically creates a PV to satisfy it. No manual PV creation needed.

---

## StorageClasses: The Recipe for Storage

A **StorageClass** defines *how* storage should be provisioned. It's a recipe that says: "When someone asks for storage of this type, here's how to create it."

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: rancher.io/local-path     # Who creates the PV
reclaimPolicy: Delete                   # What happens when PVC is deleted
volumeBindingMode: WaitForFirstConsumer # When to bind
```

### Key Fields

**`provisioner`** — The storage driver that creates PVs. Each environment has its own:

| Environment | Provisioner | Creates |
|------------|-------------|---------|
| kind | `rancher.io/local-path` | Local directories on the node |
| AWS | `ebs.csi.aws.com` | EBS volumes |
| GCP | `pd.csi.storage.gke.io` | Persistent Disks |
| Azure | `disk.csi.azure.com` | Azure Disks |

**`reclaimPolicy`** — Same as PV reclaim policy:
- `Delete`: PV and data are deleted when PVC is deleted (default for dynamic)
- `Retain`: PV is kept; admin must clean up manually

**`volumeBindingMode`:**
- `Immediate`: Bind PVC to PV as soon as PVC is created
- `WaitForFirstConsumer`: Wait until a Pod actually mounts the PVC, then create the PV on the same node as the Pod

`WaitForFirstConsumer` is better for cloud environments — it ensures the PV is created in the same availability zone as the Pod.

---

## kind's Default StorageClass

kind comes with a StorageClass pre-installed:

```bash
kubectl get storageclasses
```

```
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   5d
```

The `(default)` annotation means: any PVC that doesn't specify a StorageClass will use this one.

### Using the Default StorageClass

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: learn-db-data
  namespace: learn-ch12
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  # No storageClassName specified → uses the default StorageClass
```

Or explicitly:

```yaml
spec:
  storageClassName: standard   # Explicitly use the "standard" StorageClass
```

When you create this PVC, the `rancher.io/local-path` provisioner automatically creates a PV:

```bash
kubectl get pvc -n learn-ch12
# NAME            STATUS   VOLUME                                     CAPACITY   STORAGECLASS
# learn-db-data   Bound    pvc-abc123-def456-789                      1Gi        standard

kubectl get pv
# NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS
# pvc-abc123-def456-789                      1Gi        RWO            Delete           Bound
```

Notice: the PV was auto-created with an auto-generated name. No manual PV creation needed.

---

## Dynamic Provisioning Workflow

```
1. Developer creates PVC          → storageClassName: standard
2. StorageClass provisioner        → creates PV automatically
3. PVC binds to auto-created PV   → Status: Bound
4. Pod mounts PVC                  → data path ready
5. Pod deleted                     → PVC and PV remain
6. New Pod starts                  → mounts same PVC → same data
7. PVC deleted                     → reclaimPolicy: Delete → PV and data gone
```

Compare to static:
```
1. Admin creates PV manually       ← extra step
2. Developer creates PVC           → binds to PV
3. Pod mounts PVC                  → data path ready
...
```

---

## Volume Expansion

Some StorageClasses support volume expansion — growing a PVC after creation:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable
provisioner: rancher.io/local-path
allowVolumeExpansion: true       # Enable expansion
```

To expand:

```bash
kubectl patch pvc learn-db-data -n learn-ch12 \
  -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
```

**Important:** You can only **increase** storage, never decrease. And the Pod usually needs to restart for the filesystem to grow.

> Note: kind's `local-path` provisioner has limited expansion support. In cloud environments, volume expansion works seamlessly with CSI drivers.

---

## StorageClass for Different Tiers

In production, you might have multiple StorageClasses:

```yaml
# Fast SSD storage for databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
reclaimPolicy: Retain    # Don't delete database data

---
# Cheap HDD storage for logs
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cheap-hdd
provisioner: ebs.csi.aws.com
parameters:
  type: sc1
reclaimPolicy: Delete    # OK to delete log archives
```

Developers choose the right tier:

```yaml
# Database PVC
spec:
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 100Gi

# Log archive PVC
spec:
  storageClassName: cheap-hdd
  resources:
    requests:
      storage: 500Gi
```

---

## StatefulSet + Dynamic Provisioning

StatefulSets have a special field for storage: `volumeClaimTemplates`. This creates a unique PVC for each Pod:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: learn-db
  namespace: learn-ch12
spec:
  serviceName: learn-db-headless
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:          # Creates a PVC per Pod
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: standard
        resources:
          requests:
            storage: 1Gi
```

This creates:
- `data-learn-db-0` — PVC for Pod 0
- `data-learn-db-1` — PVC for Pod 1
- `data-learn-db-2` — PVC for Pod 2

Each Pod gets its own storage. If `learn-db-1` is deleted and recreated, it reattaches to `data-learn-db-1` — same data.

**Remember:** Deleting the StatefulSet does NOT delete the PVCs. This is by design — data protection.

---

## Cloud Provider Storage

In real cloud environments, the StorageClass provisioner talks to the cloud API:

```
PVC created → StorageClass → CSI Driver → Cloud API → Disk provisioned
                                                         │
                                                         ▼
                                                    PV created → bound to PVC
```

| Cloud | Storage Type | CSI Driver |
|-------|-------------|-----------|
| AWS | EBS (block) | `ebs.csi.aws.com` |
| AWS | EFS (file) | `efs.csi.aws.com` |
| GCP | Persistent Disk | `pd.csi.storage.gke.io` |
| Azure | Azure Disk | `disk.csi.azure.com` |
| Azure | Azure Files | `file.csi.azure.com` |

The concepts are identical to what you're learning with kind. Only the provisioner changes.

---

## Summary

| Concept | What it is |
|---------|-----------|
| StorageClass | Recipe for creating PVs; defines provisioner, reclaim policy, binding mode |
| Dynamic provisioning | PV is auto-created when PVC is created |
| Default StorageClass | Used when PVC doesn't specify a StorageClass |
| `WaitForFirstConsumer` | Delay PV creation until a Pod mounts the PVC |
| `allowVolumeExpansion` | Enable PVC size increases |
| `volumeClaimTemplates` | StatefulSet feature; creates per-Pod PVCs |
| CSI | Container Storage Interface; standard for storage drivers |

---

Time to put storage into practice. Head to the challenges.

**Challenges:**
- [Challenge 1: Persist Database](../challenges/01-persist-database.md) — Data survives Pod deletion
- [Challenge 2: Shared Storage](../challenges/02-shared-storage.md) — ConfigMap volumes with updates
- [Challenge 3: Storage Troubleshooting](../challenges/03-storage-troubleshooting.md) — Fix a PVC stuck in Pending
