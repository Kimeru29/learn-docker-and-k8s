# Challenge 3: Storage Troubleshooting

## Briefing

Dave tried to set up storage for the recommendation engine. He created a PVC, but it's stuck in `Pending`. The Pod that needs it can't start.

"I followed the docs!" Dave insists. "It should just work!"

Something is misconfigured. Your job: diagnose why the PVC won't bind and fix it.

---

## Objective

A PVC is stuck in Pending state. Diagnose the root cause using `kubectl describe`, find the misconfiguration, and fix it so the PVC binds and the Pod can start.

---

## The Broken Setup

Apply these resources:

**Broken PVC:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: learn-reco-data
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
  storageClassName: premium-fast     # Dave's "premium" StorageClass
```

**Deployment that depends on it:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-reco-engine
  namespace: learn-ch12
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: ch12
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reco-engine
  template:
    metadata:
      labels:
        app: reco-engine
        world: w03
        chapter: ch12
    spec:
      containers:
        - name: reco
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Reco engine starting' && sleep 3600"]
          volumeMounts:
            - name: reco-storage
              mountPath: /data
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
      volumes:
        - name: reco-storage
          persistentVolumeClaim:
            claimName: learn-reco-data
```

After applying, the PVC will be Pending and the Pod won't start.

---

## Your Tasks

1. Apply both manifests
2. Check the PVC status — it should be `Pending`
3. Check the Pod status — it should be `Pending` (waiting for the PVC)
4. Use `kubectl describe pvc` to read the Events and find the reason
5. Check what StorageClasses are available: `kubectl get storageclasses`
6. Fix the PVC to use an available StorageClass
7. Verify the PVC binds and the Pod starts

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] PVC `learn-reco-data` exists in `learn-ch12`
- [ ] PVC `learn-reco-data` is in `Bound` status
- [ ] Deployment `learn-reco-engine` exists with at least 1 ready replica
- [ ] Pod is Running (not stuck in Pending)

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

When a PVC is Pending, the most common causes are: wrong StorageClass, no available PV, wrong access mode, or no dynamic provisioner. Check the Events in `kubectl describe pvc learn-reco-data -n learn-ch12` — the reason is usually stated clearly.
</details>

<details>
<summary>Hint 2 — Checking StorageClasses</summary>

Run `kubectl get storageclasses` to see what's available. The PVC requests `premium-fast` — does that StorageClass exist? If not, you need to change the PVC to use one that does. In kind, the default is usually `standard`.
</details>

<details>
<summary>Hint 3 — Fixing the PVC</summary>

You can't change `storageClassName` on an existing PVC. You need to delete the PVC, fix the YAML, and re-apply. Delete the PVC first: `kubectl delete pvc learn-reco-data -n learn-ch12`. Then update the `storageClassName` to match an available StorageClass and re-apply.
</details>

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Found a PVC referencing a non-existent StorageClass (`premium-fast`). No provisioner could create a PV for it, so the PVC stayed Pending. Changed the StorageClass to the available `standard` class, and the dynamic provisioner created a PV and bound the PVC.

**Why it works:** The PVC-to-PV binding requires a matching StorageClass. If the StorageClass doesn't exist, no provisioner knows how to create a PV for the PVC. The Events section in `kubectl describe pvc` shows the exact error: "storageclass 'premium-fast' not found."

**Real-world connection:** This happens frequently in production, especially when:
- Deploying manifests written for one cluster (with certain StorageClasses) to another cluster (with different StorageClasses)
- Typos in StorageClass names
- Migrating between cloud providers (different StorageClass names and provisioners)
- StorageClass was removed or renamed

**Interview angle:** "A PVC is stuck in Pending. How do you debug it?" — 1. `kubectl describe pvc` to read Events. 2. Check if the StorageClass exists (`kubectl get sc`). 3. Check if the provisioner is running. 4. Check access mode compatibility. 5. Check capacity — is the request too large for available PVs?

**Pro tip:** Always use `kubectl describe pvc` as your first step for storage issues. The Events section is explicit about why binding failed. Also, consider using a default StorageClass and omitting `storageClassName` in PVCs to avoid this class of errors entirely.
