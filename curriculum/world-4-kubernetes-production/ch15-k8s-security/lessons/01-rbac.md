# Lesson 1: RBAC

> **Sarah:** "Right now, every pod in the cluster uses the default ServiceAccount. That ServiceAccount can list secrets, exec into other pods, and in some configurations, has cluster-admin access. That means if anyone gets a shell inside any container, they own the entire cluster. That ends today."

---

## The Principal-Verb-Resource Model

RBAC (Role-Based Access Control) answers one question: **Who can do what on which resources?**

- **Who** → A ServiceAccount, user, or group (the *principal*)
- **What** → get, list, create, update, delete, watch (the *verb*)
- **Which resources** → pods, secrets, deployments, services (the *resource*)

```
ServiceAccount "api-reader" CAN "get, list" ON "pods" IN NAMESPACE "learn-ch15"
```

That's it. Everything in RBAC is a combination of these three.

---

## ServiceAccounts

Every pod in Kubernetes runs with a ServiceAccount. If you don't specify one, it uses the `default` ServiceAccount in its namespace.

### The problem with the default ServiceAccount

In many cluster configurations, the `default` ServiceAccount has no explicit permissions — but it also has no restrictions. Depending on the cluster setup, it might be able to:

- List all Secrets in the namespace
- Exec into other pods
- Create or delete resources

Even when the default SA is restricted, using it for everything means you can't apply different permissions to different workloads.

### Creating a ServiceAccount

```bash
kubectl create serviceaccount api-reader -n learn-ch15
```

Or declaratively:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-reader
  namespace: learn-ch15
```

### Assigning a ServiceAccount to a pod

```yaml
spec:
  serviceAccountName: api-reader
  containers:
    - name: api
      image: learn-api:v1.0
```

The pod now runs as `api-reader` instead of `default`. But the ServiceAccount has no permissions until you create a Role and bind it.

---

## Roles and ClusterRoles

A **Role** defines a set of permissions in a specific namespace.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: learn-ch15
rules:
  - apiGroups: [""]       # "" = core API group (pods, services, secrets, etc.)
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

This Role allows reading pods in `learn-ch15`. Nothing else. Can't create. Can't delete. Can't read secrets. Can't touch other namespaces.

A **ClusterRole** is the same but applies cluster-wide (across all namespaces):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader-global
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

### Common verbs

| Verb | What it allows |
|------|---------------|
| `get` | Read a specific resource by name |
| `list` | List all resources of a type |
| `watch` | Stream changes to resources |
| `create` | Create new resources |
| `update` | Modify existing resources |
| `patch` | Partially modify resources |
| `delete` | Delete resources |
| `deletecollection` | Delete multiple resources at once |

### Common API groups

| API Group | Resources |
|-----------|-----------|
| `""` (core) | pods, services, secrets, configmaps, namespaces, nodes, persistentvolumeclaims |
| `apps` | deployments, statefulsets, daemonsets, replicasets |
| `batch` | jobs, cronjobs |
| `rbac.authorization.k8s.io` | roles, rolebindings, clusterroles, clusterrolebindings |
| `networking.k8s.io` | networkpolicies, ingresses |

---

## RoleBindings and ClusterRoleBindings

A Role by itself does nothing. You need to **bind** it to a principal.

**RoleBinding** — binds a Role (or ClusterRole) to a principal in a specific namespace:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: learn-ch15
subjects:
  - kind: ServiceAccount
    name: api-reader
    namespace: learn-ch15
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Now the `api-reader` ServiceAccount can get, list, and watch pods in `learn-ch15`.

**ClusterRoleBinding** — binds a ClusterRole to a principal cluster-wide:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: global-pod-reader
subjects:
  - kind: ServiceAccount
    name: monitoring-sa
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: pod-reader-global
  apiGroup: rbac.authorization.k8s.io
```

### A useful trick: ClusterRole + RoleBinding

You can bind a ClusterRole with a RoleBinding. The ClusterRole defines the permissions, but the RoleBinding scopes them to a single namespace. This is useful when you want the same set of permissions in multiple namespaces without duplicating Roles.

```yaml
# ClusterRole defines "can read pods" (reusable)
# RoleBinding in learn-ch15 grants it only in learn-ch15
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-in-ch15
  namespace: learn-ch15
subjects:
  - kind: ServiceAccount
    name: api-reader
    namespace: learn-ch15
roleRef:
  kind: ClusterRole      # Note: ClusterRole, not Role
  name: pod-reader-global
  apiGroup: rbac.authorization.k8s.io
```

---

## Testing Permissions

The `kubectl auth can-i` command checks what a principal is allowed to do:

```bash
# Can the api-reader SA get pods in learn-ch15?
kubectl auth can-i get pods \
  --as=system:serviceaccount:learn-ch15:api-reader \
  -n learn-ch15
# yes

# Can it delete pods?
kubectl auth can-i delete pods \
  --as=system:serviceaccount:learn-ch15:api-reader \
  -n learn-ch15
# no

# Can it get secrets?
kubectl auth can-i get secrets \
  --as=system:serviceaccount:learn-ch15:api-reader \
  -n learn-ch15
# no

# Can it get pods in a different namespace?
kubectl auth can-i get pods \
  --as=system:serviceaccount:learn-ch15:api-reader \
  -n default
# no
```

List all permissions for a ServiceAccount:

```bash
kubectl auth can-i --list \
  --as=system:serviceaccount:learn-ch15:api-reader \
  -n learn-ch15
```

---

## Least Privilege

The principle of least privilege: every pod gets the **minimum** permissions it needs to do its job, and nothing more.

| Workload | What it needs | Role |
|----------|---------------|------|
| API server | Read ConfigMaps and Secrets in its namespace | `get`, `list` on `configmaps`, `secrets` |
| Monitoring agent | Read pods and metrics across all namespaces | ClusterRole with `get`, `list`, `watch` on `pods` |
| CI/CD deployer | Create and update Deployments | `get`, `list`, `create`, `update`, `patch` on `deployments` |
| Log reader | Read pod logs | `get` on `pods/log` |
| Nothing special | No K8s API access | No Role, no binding |

Most application pods don't need Kubernetes API access at all. They just need to serve HTTP requests and read files. Don't bind a Role if the pod doesn't need one.

### Disabling automounting of the SA token

By default, Kubernetes mounts the ServiceAccount token into every pod at `/var/run/secrets/kubernetes.io/serviceaccount/`. If the pod doesn't need API access, disable it:

```yaml
spec:
  automountServiceAccountToken: false
  containers:
    - name: api
      image: learn-api:v1.0
```

This prevents a compromised pod from using the SA token to access the API.

---

## Built-in ClusterRoles

Kubernetes ships with several built-in ClusterRoles:

| ClusterRole | Permissions |
|-------------|-------------|
| `cluster-admin` | Everything. God mode. Never bind to application ServiceAccounts. |
| `admin` | Full access within a namespace (except quota/RBAC changes) |
| `edit` | Read/write to most resources in a namespace |
| `view` | Read-only access to most resources in a namespace |

```bash
# See what 'view' allows
kubectl describe clusterrole view
```

These are useful for human users. For application ServiceAccounts, create custom Roles with only the specific permissions needed.

---

## Quick Reference

```bash
# Create ServiceAccount
kubectl create serviceaccount <name> -n <namespace>

# Create Role
kubectl create role <name> --verb=get,list --resource=pods -n <namespace>

# Create RoleBinding
kubectl create rolebinding <name> --role=<role> --serviceaccount=<namespace>:<sa> -n <namespace>

# Test permissions
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <namespace>

# List all permissions
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <namespace>
```

---

> **Sarah:** "RBAC is the single most important security feature in Kubernetes. Without it, every pod is an admin. With it, every pod only gets what it needs. The default ServiceAccount having unrestricted access is the first thing an attacker exploits."

**Next:** [Security Contexts](02-security-contexts.md)
