#!/bin/bash
# Known-good solution for World 5 Boss Fight: The Full Platform
# Used by functional tests only. NOT visible to learners during gameplay.
# Tests: build image → helm install → upgrade → rollback → postmortem → verify
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VERIFY="$PROJECT_DIR/curriculum/world-5-platform-engineering/boss-platform-capstone/challenges/verify.sh"

CLUSTER_NAME="learn-k8s"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="learn-boss-w5"
WORK_DIR="/tmp/learn-boss-w5"

echo "=== W5 Boss Fight: Known-Good Solution Test ==="
echo ""

# ─── Skip if kind cluster not available ───────────────────────────────────────

if ! kind get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
  echo "SKIP: kind cluster '$CLUSTER_NAME' not found"
  exit 0
fi

if ! kubectl cluster-info --context "$CONTEXT" &>/dev/null; then
  echo "SKIP: kubectl cannot connect to context '$CONTEXT'"
  exit 0
fi

if ! command -v helm &>/dev/null; then
  echo "SKIP: helm is not installed"
  exit 0
fi

# ─── Clean state ─────────────────────────────────────────────────────────────

echo "Cleaning previous state..."
helm uninstall learn-boss -n "$NAMESPACE" --wait 2>/dev/null || true
kubectl delete namespace "$NAMESPACE" --context "$CONTEXT" --ignore-not-found=true --wait=true 2>/dev/null || true
kubectl create namespace "$NAMESPACE" --context "$CONTEXT"
kubectl label namespace "$NAMESPACE" app=learn-docker-k8s world=w05 chapter=boss --context "$CONTEXT" --overwrite
rm -rf "$WORK_DIR"

# ─── Phase 1: Build — Properly Tagged Image ──────────────────────────────────

echo ""
echo "=== Phase 1: Build ==="

mkdir -p "$WORK_DIR/boss-app"

cat > "$WORK_DIR/boss-app/Dockerfile" << 'EOF'
FROM nginx:1.25-alpine
COPY index.html /usr/share/nginx/html/index.html
HEALTHCHECK --interval=10s --timeout=3s CMD wget -q --spider http://localhost/ || exit 1
EXPOSE 80
EOF

cat > "$WORK_DIR/boss-app/index.html" << 'EOF'
<!DOCTYPE html>
<html><body>
<h1>NoCappuccino Bean Subscriptions</h1>
<p>Version: 1.0.0</p>
<p>Status: Healthy</p>
</body></html>
EOF

# Build the image with a semver tag (not latest)
docker build -t localhost:5001/learn-boss-app:1.0.0 "$WORK_DIR/boss-app/"

# Load into kind cluster
kind load docker-image localhost:5001/learn-boss-app:1.0.0 --name "$CLUSTER_NAME"

echo "Phase 1 DONE: Image built and loaded"

# ─── Phase 2: Deploy — Helm Chart with Health Probes ─────────────────────────

echo ""
echo "=== Phase 2: Deploy ==="

# Create a minimal Helm chart
CHART_DIR="$WORK_DIR/learn-boss-chart"
mkdir -p "$CHART_DIR/templates"

cat > "$CHART_DIR/Chart.yaml" << 'EOF'
apiVersion: v2
name: learn-boss-chart
description: NoCappuccino Boss Fight W5 Helm Chart
version: 0.1.0
appVersion: "1.0.0"
EOF

cat > "$CHART_DIR/values.yaml" << 'EOF'
replicaCount: 3

image:
  repository: localhost:5001/learn-boss-app
  tag: "1.0.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  requests:
    memory: "32Mi"
    cpu: "50m"
  limits:
    memory: "64Mi"
    cpu: "100m"

labels:
  app: learn-docker-k8s
  world: w05
  chapter: boss
EOF

cat > "$CHART_DIR/templates/deployment.yaml" << 'HELMEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ .Release.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Release.Name }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Release.Name }}
        app.kubernetes.io/instance: {{ .Release.Name }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              memory: {{ .Values.resources.requests.memory | quote }}
              cpu: {{ .Values.resources.requests.cpu | quote }}
            limits:
              memory: {{ .Values.resources.limits.memory | quote }}
              cpu: {{ .Values.resources.limits.cpu | quote }}
HELMEOF

cat > "$CHART_DIR/templates/service.yaml" << 'HELMEOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-app
  namespace: {{ .Release.Namespace }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app.kubernetes.io/name: {{ .Release.Name }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
HELMEOF

# Install v1
helm install learn-boss "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --set fullnameOverride=learn-boss-app \
  --kube-context "$CONTEXT" \
  --wait --timeout 120s

echo "Phase 2 DONE: Helm release installed"

# ─── Phase 3: Monitor — (Prometheus check is a warn, not fail) ───────────────

echo ""
echo "=== Phase 3: Monitor ==="
echo "Phase 3: Prometheus detection is advisory (verifier uses warn, not fail)"

# ─── Phase 4: Release — Rolling Update to v2 ─────────────────────────────────

echo ""
echo "=== Phase 4: Release ==="

# Build v2 image
cat > "$WORK_DIR/boss-app/index.html" << 'EOF'
<!DOCTYPE html>
<html><body>
<h1>NoCappuccino Bean Subscriptions</h1>
<p>Version: 2.0.0</p>
<p>Status: Healthy</p>
<p>NEW: Personalized bean recommendations!</p>
</body></html>
EOF

docker build -t localhost:5001/learn-boss-app:2.0.0 "$WORK_DIR/boss-app/"
kind load docker-image localhost:5001/learn-boss-app:2.0.0 --name "$CLUSTER_NAME"

# Upgrade to v2
helm upgrade learn-boss "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --set fullnameOverride=learn-boss-app \
  --set image.tag=2.0.0 \
  --kube-context "$CONTEXT" \
  --wait --timeout 120s

echo "Phase 4 DONE: Upgraded to v2.0.0"

# ─── Phase 5: Incident — Simulate and Rollback ───────────────────────────────

echo ""
echo "=== Phase 5: Incident ==="

# Simulate the incident: upgrade with broken memory limits
helm upgrade learn-boss "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --set fullnameOverride=learn-boss-app \
  --set image.tag=2.0.0 \
  --set resources.limits.memory="8Mi" \
  --set resources.requests.memory="4Mi" \
  --kube-context "$CONTEXT" \
  --timeout 30s 2>/dev/null || true

# Wait for pods to start failing
echo "Waiting for incident to manifest..."
sleep 15

# Rollback to last good revision (revision 2 = v2 with good resources)
echo "Rolling back..."
helm rollback learn-boss 2 -n "$NAMESPACE" --kube-context "$CONTEXT" --wait --timeout 120s

echo "Waiting for pods to stabilize after rollback..."
sleep 10

# Verify pods are healthy
kubectl rollout status deployment/learn-boss-app -n "$NAMESPACE" --context "$CONTEXT" --timeout=120s 2>/dev/null || true

echo "Phase 5 DONE: Incident handled, rolled back"

# ─── Phase 6: Document — Postmortem ──────────────────────────────────────────

echo ""
echo "=== Phase 6: Document ==="

kubectl delete configmap learn-boss-postmortem -n "$NAMESPACE" --context "$CONTEXT" --ignore-not-found=true 2>/dev/null || true

kubectl create configmap learn-boss-postmortem \
  --from-literal=summary="During the v2.0.0 rollout of the bean subscription service, a configuration error reduced memory limits to 8Mi, causing OOMKilled pods. The rolling update replaced healthy v2 pods with broken ones. Mitigated by Helm rollback to the previous revision." \
  --from-literal=severity="SEV2" \
  --from-literal=timeline="Phase 1-4: Built, tagged, deployed, monitored, and upgraded successfully. Phase 5: Memory limit misconfiguration caused OOMKilled. Detected within 2 minutes via pod restarts. Rolled back via helm rollback within 5 minutes. All pods healthy." \
  --from-literal=root_cause="Memory resource limits were set to 8Mi during the upgrade, which is below the nginx minimum. The Helm values override reduced limits without validation." \
  --from-literal=action_items="1. [P1] Add resource limit validation to Helm chart (minimum thresholds). 2. [P1] Add pre-upgrade dry-run check that verifies resource values. 3. [P2] Set up Prometheus alert for OOMKilled events. 4. [P2] Add memory usage to rolling update canary criteria." \
  --from-literal=lessons_learned="Build pipeline and tagging worked well. Helm rollback was fast and effective. The gap: no validation on resource values during upgrade. Need automated guardrails." \
  -n "$NAMESPACE" \
  --context "$CONTEXT"

echo "Phase 6 DONE: Postmortem created"

echo ""

# ─── Verify ──────────────────────────────────────────────────────────────────

echo "=== Running verify.sh ==="
if bash "$VERIFY"; then
    echo ""
    echo "SOLUTION TEST PASSED"
    exit 0
else
    echo ""
    echo "SOLUTION TEST FAILED — verifier rejected known-good solution"
    exit 1
fi
