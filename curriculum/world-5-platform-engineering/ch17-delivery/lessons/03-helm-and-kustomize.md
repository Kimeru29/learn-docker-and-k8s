# Lesson 3: Helm & Kustomize

> **Sarah:** "Raw YAML works until you need the same app in three environments with slightly different configs. Then you're copy-pasting 200 lines of YAML and hoping you changed the right values. Helm and Kustomize solve this — differently."

---

## The Problem with Raw YAML

You have a Deployment, Service, ConfigMap, and Secret for the NoCappuccino API. That's ~100 lines of YAML. Now you need it in three environments:

| | Dev | Staging | Production |
|-|-----|---------|------------|
| Replicas | 1 | 2 | 5 |
| Image tag | `abc123f` | `v1.4.2-rc.1` | `v1.4.2` |
| CPU limit | 250m | 500m | 1000m |
| Log level | debug | info | warn |
| DB host | dev-db | staging-db | prod-db |

Option 1: Three copies of 100-line YAML files. Drift guaranteed.

Option 2: Sed/envsubst scripts. Fragile, hard to debug.

Option 3: **Helm** (templating) or **Kustomize** (patching). Both solve this problem, with different philosophies.

---

## Helm

Helm is the **package manager for Kubernetes**. It uses **charts** — packages of templated YAML manifests with configurable values.

### Core Concepts

| Concept | What it is |
|---------|-----------|
| **Chart** | A package containing templated K8s manifests and metadata |
| **Values** | A YAML file of parameters that customize the chart |
| **Template** | A K8s manifest with Go template syntax (`{{ .Values.replicas }}`) |
| **Release** | A deployed instance of a chart with specific values |
| **Repository** | A place where charts are published and shared |

### Chart Structure

```
nocappuccino-chart/
├── Chart.yaml          # Chart metadata (name, version, description)
├── values.yaml         # Default values
├── templates/
│   ├── deployment.yaml # Templated Deployment
│   ├── service.yaml    # Templated Service
│   ├── configmap.yaml  # Templated ConfigMap
│   └── _helpers.tpl    # Reusable template snippets
└── charts/             # Subcharts (dependencies)
```

### Chart.yaml

```yaml
apiVersion: v2
name: nocappuccino-api
description: The NoCappuccino coffee recommendation API
version: 0.1.0        # Chart version
appVersion: "1.4.2"    # Application version
```

### values.yaml

```yaml
replicaCount: 2

image:
  repository: localhost:5001/nocappuccino-api
  tag: "1.4.2"
  pullPolicy: IfNotPresent

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"

config:
  logLevel: "info"
  dbHost: "postgres.internal"

service:
  type: ClusterIP
  port: 80
```

### Templated Deployment

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nocappuccino-api.fullname" . }}
  labels:
    app: learn-docker-k8s
    world: w05
    chapter: ch17
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "nocappuccino-api.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "nocappuccino-api.name" . }}
    spec:
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            - name: LOG_LEVEL
              value: {{ .Values.config.logLevel | quote }}
            - name: DB_HOST
              value: {{ .Values.config.dbHost | quote }}
```

### Deploying with Helm

```bash
# Install a release
helm install learn-api ./nocappuccino-chart \
  --namespace learn-ch17 \
  --create-namespace

# Install with custom values
helm install learn-api ./nocappuccino-chart \
  --namespace learn-ch17 \
  --set replicaCount=5 \
  --set image.tag=v1.4.3

# Install with a values file
helm install learn-api ./nocappuccino-chart \
  --namespace learn-ch17 \
  -f production-values.yaml

# Upgrade (change values or chart version)
helm upgrade learn-api ./nocappuccino-chart \
  --namespace learn-ch17 \
  --set image.tag=v1.5.0

# Rollback to previous release
helm rollback learn-api 1 --namespace learn-ch17

# See release history
helm history learn-api --namespace learn-ch17

# Uninstall
helm uninstall learn-api --namespace learn-ch17
```

### Environment-Specific Values Files

```yaml
# values-dev.yaml
replicaCount: 1
config:
  logLevel: "debug"
  dbHost: "dev-postgres"
```

```yaml
# values-production.yaml
replicaCount: 5
config:
  logLevel: "warn"
  dbHost: "prod-postgres.internal"
resources:
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

```bash
helm install learn-api ./chart -f values-dev.yaml -n learn-ch17-dev
helm install learn-api ./chart -f values-production.yaml -n learn-ch17-prod
```

Same chart, different values, different environments.

---

## Kustomize

Kustomize takes a different approach: instead of templating, it **patches** plain YAML.

### Philosophy

- Start with plain, valid YAML (the "base")
- Apply modifications ("overlays") for each environment
- No template syntax — your base YAML is always valid K8s YAML

### Structure

```
base/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── configmap.yaml

overlays/
├── dev/
│   ├── kustomization.yaml
│   └── replica-patch.yaml
├── staging/
│   ├── kustomization.yaml
│   └── replica-patch.yaml
└── production/
    ├── kustomization.yaml
    ├── replica-patch.yaml
    └── resource-patch.yaml
```

### Base kustomization.yaml

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
commonLabels:
  app: learn-docker-k8s
  world: w05
  chapter: ch17
```

### Overlay kustomization.yaml

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: learn-ch17-prod
patches:
  - path: replica-patch.yaml
  - path: resource-patch.yaml
```

### Patch File

```yaml
# overlays/production/replica-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nocappuccino-api
spec:
  replicas: 5
```

### Applying with Kustomize

```bash
# Preview what will be applied
kubectl kustomize overlays/production/

# Apply
kubectl apply -k overlays/production/

# Diff against what's running
kubectl diff -k overlays/production/
```

Kustomize is built into kubectl (no additional installation needed).

---

## Helm vs Kustomize

| | Helm | Kustomize |
|-|------|-----------|
| **Approach** | Templating | Patching |
| **Base YAML** | Contains `{{ }}` — not valid K8s YAML on its own | Plain, valid YAML |
| **Customization** | Values files override template variables | Patches modify specific fields |
| **Packaging** | Charts can be packaged, versioned, shared via repos | Directories — no packaging format |
| **Rollback** | `helm rollback` — built-in release history | No built-in rollback (use Git) |
| **Dependencies** | Subcharts with dependency management | Kustomize components (simpler) |
| **Complexity** | More powerful, more complex | Simpler, less flexible |
| **Adoption** | Most Helm charts exist for popular tools (Prometheus, Grafana, nginx) | Used heavily in GitOps workflows |

### When to Use Helm

- Deploying third-party software (Prometheus, cert-manager, ArgoCD — they all ship as Helm charts)
- Complex applications with many configurable options
- When you need rollback and release history
- When you want to share your application as a package

### When to Use Kustomize

- Simple overlay use cases (same manifests, different namespaces/replicas)
- GitOps workflows (ArgoCD and Flux both support Kustomize natively)
- Teams that want their base YAML to remain valid K8s manifests
- When you don't need packaging or release management

### You Can Use Both

A common pattern: use Helm to install third-party tools, and Kustomize to manage your own application manifests with environment overlays.

---

## Quick Reference

```bash
# Helm
helm install <release> <chart> -n <namespace>
helm upgrade <release> <chart> -n <namespace> --set key=value
helm rollback <release> <revision> -n <namespace>
helm history <release> -n <namespace>
helm uninstall <release> -n <namespace>
helm template <chart> -f values.yaml    # Render locally without deploying

# Kustomize
kubectl kustomize <overlay-dir>         # Preview rendered YAML
kubectl apply -k <overlay-dir>          # Apply
kubectl diff -k <overlay-dir>           # Diff against current state
```

---

> **Sarah:** "I use Helm for installing Prometheus, Grafana, and cert-manager — the charts are well-maintained and handle the complexity. For our own apps, I use Kustomize because our base YAML is clean and the overlays are simple. There's no religion here — use what fits."

**Next:** [Lesson 04 — GitOps Concepts](04-gitops-concepts.md)
