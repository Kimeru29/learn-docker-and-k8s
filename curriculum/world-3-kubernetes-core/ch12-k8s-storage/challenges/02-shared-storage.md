# Challenge 2: Shared Storage

## Briefing

NoCappuccino's frontend service reads its configuration from a file at startup. Currently, the config is baked into the container image — which means every config change requires a new image build and a full redeployment.

"Can't we just update the config without redeploying?" Marcus asks.

Yes. ConfigMap volumes are mounted into Pods as files. When you update the ConfigMap, the files update automatically (within about 60 seconds). No rebuild, no redeploy.

---

## Objective

Create a ConfigMap with application configuration. Mount it as a volume in two Pods. Update the ConfigMap and verify the Pods see the new data.

---

## Requirements

1. Create a ConfigMap named `learn-app-config` in `learn-ch12` with these keys:
   ```
   APP_TITLE=NoCappuccino
   APP_THEME=dark
   APP_VERSION=2.1.0
   ```
   Labels: `app: learn-docker-k8s`, `world: w03`, `chapter: ch12`

2. Create a Deployment named `learn-config-reader` in `learn-ch12`:
   - Image: `busybox:1.36`
   - Replicas: 2
   - Command: `["sh", "-c", "while true; do echo '--- Config ---'; cat /config/APP_TITLE; cat /config/APP_THEME; cat /config/APP_VERSION; echo ''; sleep 30; done"]`
   - Mount the ConfigMap as a volume at `/config` (readOnly: true)
   - Pod labels: `app: config-reader`, `world: w03`, `chapter: ch12`

3. Verify both Pods can read the config:
   ```bash
   kubectl logs -l app=config-reader -n learn-ch12
   ```

4. Update the ConfigMap — change `APP_THEME` to `light`:
   ```bash
   kubectl edit configmap learn-app-config -n learn-ch12
   # Or re-apply an updated YAML
   ```

5. Wait ~60 seconds, then verify the Pods see the new value:
   ```bash
   kubectl exec <pod-name> -n learn-ch12 -- cat /config/APP_THEME
   # Should output: light
   ```

---

## Success Criteria

The `challenges/verify.sh` script will check:

- [ ] ConfigMap `learn-app-config` exists in `learn-ch12`
- [ ] ConfigMap contains keys `APP_TITLE`, `APP_THEME`, `APP_VERSION`
- [ ] Deployment `learn-config-reader` exists with at least 1 ready replica
- [ ] Pod mounts a configMap volume

---

## Hints

<details>
<summary>Hint 1 — Creating the ConfigMap</summary>

You can create a ConfigMap from literals: `kubectl create configmap learn-app-config --from-literal=APP_TITLE=NoCappuccino --from-literal=APP_THEME=dark --from-literal=APP_VERSION=2.1.0 -n learn-ch12`. Or write a YAML manifest with a `data` section.
</details>

<details>
<summary>Hint 2 — Mounting in the Deployment</summary>

In the Deployment spec, add a `volumes` section with a `configMap` volume type, and a `volumeMounts` section on the container. Each key in the ConfigMap becomes a file in the mount directory. Don't forget `readOnly: true` for config volumes.
</details>

<details>
<summary>Hint 3 — Updating the ConfigMap</summary>

Use `kubectl edit configmap learn-app-config -n learn-ch12` to edit in-place. Or create an updated YAML file and `kubectl apply -f` it. Mounted ConfigMap volumes are automatically updated by kubelet (within ~60 seconds). Environment variables from ConfigMaps are NOT updated.
</details>

---

## Post-Mission Debrief

*(Read this after you've solved the challenge.)*

**What you did:** Created a ConfigMap and mounted it as a read-only volume in multiple Pods. Updated the ConfigMap and observed the change propagate to the running Pods without any restart.

**Why it works:** kubelet periodically syncs mounted ConfigMap volumes with their current values in etcd. When you update a ConfigMap, the API Server stores the new data in etcd. On the next sync cycle (~60 seconds), kubelet updates the files in the Pod's mounted volume. The container sees the new files.

**Real-world connection:** ConfigMap volumes are used for app configuration, feature flags, connection strings, and templated config files. The auto-update feature makes them ideal for runtime configuration changes. For applications that watch config files (like nginx `reload` on config change), you can achieve zero-downtime config updates.

**Interview angle:** "How do you manage application configuration in Kubernetes?" — ConfigMaps for non-sensitive data, Secrets for sensitive data. Volume mounts for file-based config (auto-updates). Environment variables for simple values (no auto-update). Know the propagation delay (~60s for volume mounts).

**Pro tip:** If your app reads config files at startup and caches them, the ConfigMap volume update won't help — the app won't re-read. You'd need a sidecar that watches for file changes and sends a signal (SIGHUP) to the main process, or use a config library that watches for changes.
