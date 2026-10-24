# Chapter 12 Quiz: The Persistent Roast

Use this quiz to test your understanding before the Boss Fight — or to unlock Chapter 12 if you're skipping ahead. You need 4 out of 5 correct to pass.

---

## Question 1

A database Pod is running without a PVC. The Pod gets deleted during a rolling update. What happens to the data?

**A)** The data is automatically backed up before the Pod is deleted.

**B)** The data is preserved on the node and reattached when the new Pod starts.

**C)** The data is lost. Container filesystems are ephemeral — they're reset when the container restarts.

**D)** The data is moved to etcd for safekeeping.

<details>
<summary>Answer</summary>

**C** — Without a PVC, the database writes data to the container's ephemeral filesystem (an overlay mount from the container image). When the container is deleted, the overlay is removed and the data is gone. This is by design — containers are meant to be disposable. For persistent data, you must use a PVC.
</details>

---

## Question 2

What is the relationship between a PersistentVolume (PV) and a PersistentVolumeClaim (PVC)?

**A)** A PV is a namespace-scoped resource that directly mounts storage into a Pod.

**B)** A PV is a piece of provisioned storage (cluster-scoped). A PVC is a request for storage (namespace-scoped). The PVC binds to a matching PV, and Pods mount the PVC.

**C)** A PV and PVC are the same thing with different names.

**D)** A PVC creates a PV automatically — there is no separate PV resource.

<details>
<summary>Answer</summary>

**B** — PVs represent actual storage (provisioned by an admin or dynamically). PVCs represent requests ("I need 10Gi of RWO storage"). Kubernetes binds a PVC to a matching PV based on capacity, access mode, and StorageClass. Pods mount PVCs by name. This separation decouples storage provisioning from consumption.
</details>

---

## Question 3

You create a PVC requesting `storageClassName: premium-ssd`, but the PVC stays in Pending. What is the most likely cause?

**A)** The cluster doesn't have enough CPU to create the volume.

**B)** The StorageClass `premium-ssd` doesn't exist, or its provisioner isn't running.

**C)** PVCs always start in Pending and transition to Bound after 5 minutes.

**D)** The Pod that will use the PVC hasn't been created yet.

<details>
<summary>Answer</summary>

**B** — If the StorageClass doesn't exist, no provisioner knows how to create a PV for the PVC. The PVC stays Pending indefinitely. `kubectl describe pvc` will show an event like "storageclass 'premium-ssd' not found." D could be true with `WaitForFirstConsumer` binding mode, but the PVC would still show a waiting event, not an error.
</details>

---

## Question 4

You update a ConfigMap that is mounted as a volume in a running Pod. What happens?

**A)** The Pod immediately crashes and restarts with the new config.

**B)** Nothing — ConfigMap changes never propagate to running Pods.

**C)** The mounted files are automatically updated within ~60 seconds. Environment variables from the same ConfigMap are NOT updated.

**D)** Both the mounted files and environment variables update automatically.

<details>
<summary>Answer</summary>

**C** — kubelet periodically syncs mounted ConfigMap volumes. The files in the Pod's mount point are updated (within ~60 seconds) without requiring a Pod restart. However, environment variables sourced from ConfigMaps are set at container start and do NOT change. This distinction is important when choosing between volume mounts and env vars for configuration.
</details>

---

## Question 5

What does `accessMode: ReadWriteOnce` (RWO) mean for a PersistentVolume?

**A)** Only one Pod can read or write the volume at any time.

**B)** The volume can be mounted as read-write by a single node. Multiple Pods on that same node can access it.

**C)** The volume can only be written to once, then becomes read-only.

**D)** The volume supports only one read and one write operation total.

<details>
<summary>Answer</summary>

**B** — RWO means the volume can be mounted as read-write by a **single node** (not a single Pod). If multiple Pods on the same node reference the same PVC, they can all access the volume. If a Pod on a different node tries to mount it, the mount will fail. This is the most common access mode for block storage (AWS EBS, Azure Disk, GCE PD).
</details>

---

## Score

- **5/5** — Storage master. Ready for the Boss Fight.
- **4/5** — Solid. Review the one you missed.
- **3/5 or below** — Review PV/PVC model, StorageClasses, and ConfigMap propagation before the Boss Fight. Storage is a critical production skill.
