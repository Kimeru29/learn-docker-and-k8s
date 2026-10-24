# Challenge 1: Persist Database

## Briefing

The customer support ticket is still open. "My order history is gone." The database Pod restarted and the data vanished.

This happened because the database was running without a PersistentVolumeClaim. Its data lived in the container's ephemeral filesystem — when the container restarted, the filesystem was reset.

Your mission: deploy a database with a PVC so data survives Pod deletions.

---

## Objective

Deploy a database with persistent storage. Insert data, delete the Pod, and verify the data survives when a new Pod takes its place.

---

## Requirements

1. Create a PersistentVolumeClaim named `learn-db-data` in `learn-ch12`:
   - Access mode: `ReadWriteOnce`
   - Storage request: `256Mi`
   - StorageClass: `standard` (kind's default)
   - Labels: `world: w03`, `chapter: ch12`

2. Create a Deployment named `learn-postgres` in `learn-ch12`:
   - Image: `postgres:16-alpine`
   - Replicas: 1
   - Environment variables:
     - `POSTGRES_PASSWORD=nocappuccino123`
     - `POSTGRES_DB=nocappuccino`
     - `PGDATA=/var/lib/postgresql/data/pgdata`
   - Mount the PVC at `/var/lib/postgresql/data`
   - Pod labels: `app: postgres`, `world: w03`, `chapter: ch12`

3. Wait for the Pod to be Running
4. Exec into the Pod and insert test data:
   ```bash
   kubectl exec -it <pod-name> -n learn-ch12 -- psql -U postgres -d nocappuccino -c "CREATE TABLE orders (id serial, item text); INSERT INTO orders (item) VALUES ('Ethiopian Yirgacheffe');"
   ```
5. Delete the Pod (not the Deployment or PVC)
6. Wait for the replacement Pod to be Running
7. Verify the data is still there:
   ```bash
   kubectl exec -it <new-pod-name> -n learn-ch12 -- psql -U postgres -d nocappuccino -c "SELECT * FROM orders;"
   ```

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] PVC `learn-db-data` exists in `learn-ch12` and is Bound
- [ ] Deployment `learn-postgres` exists with at least 1 ready replica
- [ ] The Pod mounts a PVC (has a persistentVolumeClaim volume)
- [ ] Pod has correct labels (`chapter=ch12`)

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

You need two YAML manifests: one for the PVC and one for the Deployment. The PVC defines the storage request. The Deployment references the PVC in its `volumes` section and mounts it in `volumeMounts`. The PVC name in the Deployment must match the PVC you created.
</details>

<details>
<summary>Hint 2 — PostgreSQL PGDATA path</summary>

PostgreSQL requires the `PGDATA` environment variable to point to a subdirectory of the mount path. If you mount the PVC at `/var/lib/postgresql/data`, set `PGDATA=/var/lib/postgresql/data/pgdata`. This is because the mount point itself has a `lost+found` directory that PostgreSQL doesn't like.
</details>

<details>
<summary>Hint 3 — Verifying persistence</summary>

After deleting the Pod, the Deployment creates a new one. The new Pod mounts the same PVC, which is still bound to the same PV with the same data. Use `kubectl get pods -n learn-ch12 --watch` to see the replacement Pod start, then exec in and query the database.
</details>

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Created a PVC and mounted it into a PostgreSQL Deployment. Data written to the database directory was stored on the PV. When the Pod was deleted, the PVC remained bound, and the replacement Pod mounted the same storage with the same data.

**Why it works:** The PVC is a separate resource from the Pod. Deleting a Pod doesn't delete its PVC. The PVC remains bound to the PV, and the data on the PV is untouched. When the new Pod starts, it mounts the same PVC and sees the same files.

**Real-world connection:** Every production database in Kubernetes uses PVCs. Without them, any Pod restart (including rolling updates) would wipe the database. PVCs with `Retain` reclaim policy provide additional safety — even if the PVC is deleted, the PV and data are preserved.

**Interview angle:** "How do you handle persistent storage in Kubernetes?" — PVCs backed by PVs (usually dynamically provisioned via StorageClasses). Know the access modes (RWO, ROX, RWX), reclaim policies (Retain, Delete), and that StatefulSets use `volumeClaimTemplates` for per-Pod storage.

**Pro tip:** For production databases, use `persistentVolumeReclaimPolicy: Retain` on the StorageClass. And always run database backups — PVCs protect against Pod restarts, but not against accidental `DROP TABLE` or disk failures.
