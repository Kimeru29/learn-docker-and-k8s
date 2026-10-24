# Lesson 3: Secrets Management

> **Sarah:** "The security audit found database credentials in pod environment variables. You can see them with `kubectl describe pod`. You can see them in `/proc/1/environ` inside the container. They were in the pod logs because someone printed the environment on startup for debugging. Let me show you the right way to handle secrets."

---

## The Problem with How We Store Secrets

You learned about Kubernetes Secrets in World 3. Here's what most teams get wrong:

### Problem 1: base64 is not encryption

```bash
echo -n "Sup3rS3cr3tP@ssw0rd!" | base64
# U3VwM3JTM2NyM3RQQHNzdzByZCE=

echo -n "U3VwM3JTM2NyM3RQQHNzdzByZCE=" | base64 --decode
# Sup3rS3cr3tP@ssw0rd!
```

Anyone with `kubectl get secret -o yaml` access can decode every secret instantly. base64 exists so binary data (TLS certs, keys) can be stored in YAML. It provides **zero security**.

### Problem 2: Environment variables leak

When secrets are injected as environment variables:

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_PASSWORD
```

They're visible in:
- `kubectl describe pod` — shows the secret reference (not the value, but the key name is exposed)
- `kubectl exec <pod> -- env` — prints the actual value
- `/proc/1/environ` inside the container — the value in plain text
- `docker inspect` on the container (if you have Docker access)
- Application logs if the app prints its environment (common in debug mode)
- Process listings if the app passes credentials as command-line arguments
- Core dumps if the process crashes

### Problem 3: Secrets in etcd are not encrypted by default

Kubernetes stores Secrets in etcd. By default, they're stored as base64-encoded plaintext. Anyone with access to etcd has every secret in your cluster.

---

## Volume Mounts: The Better Approach

Instead of env vars, mount secrets as files:

```yaml
spec:
  containers:
    - name: api
      image: learn-api:v1.0
      volumeMounts:
        - name: db-creds
          mountPath: /etc/secrets
          readOnly: true
  volumes:
    - name: db-creds
      secret:
        secretName: db-credentials
        defaultMode: 0400  # Owner read-only
```

Each key in the Secret becomes a file at `/etc/secrets/<key>`:

```bash
# Inside the container
ls /etc/secrets/
# DB_PASSWORD  DB_USER

cat /etc/secrets/DB_PASSWORD
# Sup3rS3cr3tP@ssw0rd!
```

### Why volume mounts are better

| Risk | Env var | Volume mount |
|------|---------|-------------|
| Visible in `kubectl describe` | Value reference shown | Mount path shown (not value) |
| Visible in `env` output | Yes | No |
| Visible in `/proc/1/environ` | Yes | No |
| Visible in application logs | If app prints env | Only if app reads and prints the file |
| Updated without pod restart | No (env set at start) | Yes (kubelet updates the file) |
| File permissions controllable | No | Yes (`defaultMode`, `mode`) |

Volume-mounted secrets are not perfect — the file is still readable inside the container. But they're significantly harder to leak accidentally.

### Reading secrets from files in your app

Most applications can read credentials from files:

```python
# Python
with open('/etc/secrets/DB_PASSWORD') as f:
    db_password = f.read().strip()
```

```javascript
// Node.js
const dbPassword = fs.readFileSync('/etc/secrets/DB_PASSWORD', 'utf8').trim();
```

```go
// Go
password, _ := os.ReadFile("/etc/secrets/DB_PASSWORD")
```

### Mounting specific keys

You don't have to mount all keys. Use `items` to select and rename:

```yaml
volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
      items:
        - key: DB_PASSWORD
          path: password        # Mounted as /etc/secrets/password
        - key: DB_USER
          path: username        # Mounted as /etc/secrets/username
```

---

## Secret Rotation

When a secret is compromised — or even suspected of being compromised — rotate it immediately.

### Rotation with volume-mounted secrets

1. Update the Secret in Kubernetes:
   ```bash
   kubectl create secret generic db-credentials \
     --from-literal=DB_PASSWORD=new-password \
     --from-literal=DB_USER=cloudbrew_admin \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

2. The kubelet automatically updates the mounted files (within the `kubeletSyncPeriod`, typically ~1 minute)

3. If your app watches the file, it picks up the new value without a restart. If not, perform a rolling restart:
   ```bash
   kubectl rollout restart deployment/learn-api -n learn-ch15
   ```

### Rotation with env vars

Env vars are set at pod creation and never change. To rotate:

1. Update the Secret
2. Perform a rolling restart of the Deployment
3. New pods get the new value

This is another reason volume mounts are superior — they support zero-downtime rotation.

---

## External Secrets (Concepts)

For production, Kubernetes Secrets are a **transit format**, not a **storage format**. The source of truth lives elsewhere.

### HashiCorp Vault

The most common open-source option:
- Secrets are stored encrypted with audit logging
- Access is controlled by policies
- Secrets can be automatically rotated
- Dynamic secrets: Vault generates a unique database credential for each pod

### Cloud Secret Managers

- **AWS Secrets Manager / Parameter Store** — IAM policies control access
- **GCP Secret Manager** — Workload Identity integration with GKE
- **Azure Key Vault** — Managed identity integration with AKS

### External Secrets Operator

The bridge between external secret managers and Kubernetes:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: learn-ch15
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: db-credentials         # K8s Secret to create
  data:
    - secretKey: DB_PASSWORD     # Key in the K8s Secret
      remoteRef:
        key: production/database # Path in Vault
        property: password       # Field in the Vault secret
```

The operator watches Vault (or AWS/GCP/Azure), syncs values into Kubernetes Secrets, and refreshes them on schedule. No one touches YAML.

### Sealed Secrets

For GitOps workflows where you want to store encrypted secrets in git:

1. You write a regular Secret YAML
2. `kubeseal` encrypts it with the cluster's public key
3. The encrypted `SealedSecret` is committed to git
4. The Sealed Secrets controller in the cluster decrypts it into a regular Secret

Only the cluster can decrypt it. Safe to store in version control.

---

## etcd Encryption at Rest

Enable encryption for Secrets stored in etcd:

```yaml
# /etc/kubernetes/encryption-config.yaml (on the control plane)
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}
```

This encrypts Secrets before writing to etcd. Without this, etcd backup = all secrets in plaintext.

In managed clusters (EKS, GKE, AKS), etcd encryption is typically enabled by default or available as a configuration option.

---

## Quick Reference

```bash
# Create a Secret
kubectl create secret generic <name> --from-literal=KEY=VALUE -n <namespace>

# Mount as volume in a Deployment (edit YAML)
# See examples above

# Check if secrets are in env vars
kubectl exec <pod> -n <namespace> -- env | grep -i password

# Check mounted secret files
kubectl exec <pod> -n <namespace> -- ls -la /etc/secrets/
kubectl exec <pod> -n <namespace> -- cat /etc/secrets/DB_PASSWORD

# Update a Secret
kubectl create secret generic <name> --from-literal=KEY=NEW_VALUE \
  --dry-run=client -o yaml | kubectl apply -f -

# Decode a secret value
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.KEY}' | base64 --decode
```

---

> **Sarah:** "The hierarchy of secret management: mounted files are better than env vars. External secret managers are better than K8s Secrets. Encrypted etcd is better than plaintext etcd. Start with mounted files — that alone eliminates most accidental leaks."

**Next:** [Network Security](04-network-security.md)
