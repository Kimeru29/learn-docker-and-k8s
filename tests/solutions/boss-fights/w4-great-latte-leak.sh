#!/bin/bash
# Known-good solution for World 4 Boss Fight: The Great Latte Leak
# Used by functional tests only. NOT visible to learners during gameplay.
# Tests: apply fixed K8s manifests → wait for pods → verify passes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VERIFY="$PROJECT_DIR/curriculum/world-4-kubernetes-production/boss-great-latte-leak/challenges/verify.sh"

CLUSTER_NAME="learn-k8s"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="learn-boss-w4"

echo "=== W4 Boss Fight: Known-Good Solution Test ==="
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

# ─── Clean state ─────────────────────────────────────────────────────────────

echo "Cleaning previous state..."
kubectl delete clusterrolebinding deploy-bot-admin --context "$CONTEXT" --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace "$NAMESPACE" --context "$CONTEXT" --ignore-not-found=true --wait=true 2>/dev/null || true
kubectl create namespace "$NAMESPACE" --context "$CONTEXT"

# ─── Issue 1: API Deployment (FIXED — correct image tag nginx:1.25-alpine) ───

echo "Applying fixed manifests..."

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-api
  template:
    metadata:
      labels:
        app: learn-api
        world: w04
    spec:
      containers:
        - name: api
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-api
  namespace: ${NAMESPACE}
spec:
  selector:
    app: learn-api
  ports:
    - port: 80
      targetPort: 80
EOF

# ─── Issue 2: Worker (FIXED — memory limits increased to 64Mi/128Mi) ─────────

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-worker
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: learn-worker
  template:
    metadata:
      labels:
        app: learn-worker
        world: w04
    spec:
      containers:
        - name: worker
          image: nginx:1.25
          resources:
            requests:
              memory: "64Mi"
              cpu: "25m"
            limits:
              memory: "128Mi"
              cpu: "50m"
EOF

# ─── Issue 3: Credential Leak (FIXED — credentials in Secret, not ConfigMap) ─

# ConfigMap without credentials
cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ${NAMESPACE}
data:
  LOG_LEVEL: "info"
  API_BASE_URL: "https://api.nocappuccino.internal"
  DB_HOST: "learn-db"
  DB_PORT: "5432"
EOF

# Secret with credentials
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=nocap_admin \
  --from-literal=DB_PASSWORD='Pr0duct10nP@ss!' \
  -n "$NAMESPACE" \
  --context "$CONTEXT" \
  --dry-run=client -o yaml | kubectl apply --context "$CONTEXT" -f -

# App deployment mounting secret as volume
cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-app
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: learn-app
  template:
    metadata:
      labels:
        app: learn-app
        world: w04
    spec:
      containers:
        - name: app
          image: nginx:1.25
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: app-config
          volumeMounts:
            - name: db-creds
              mountPath: /etc/secrets
              readOnly: true
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
      volumes:
        - name: db-creds
          secret:
            secretName: db-credentials
EOF

# ─── Issue 4: Order Service (FIXED — readiness probe added) ──────────────────

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-order-service
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w04
    chapter: boss
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-order-service
  template:
    metadata:
      labels:
        app: learn-order-service
        world: w04
    spec:
      containers:
        - name: order
          image: nginx:1.25
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            periodSeconds: 5
            failureThreshold: 3
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-order-service
  namespace: ${NAMESPACE}
spec:
  selector:
    app: learn-order-service
  ports:
    - port: 80
      targetPort: 80
EOF

# ─── Issue 5: RBAC (FIXED — namespace-scoped Role, not cluster-admin) ────────

# ServiceAccount
cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deploy-bot
  namespace: ${NAMESPACE}
EOF

# Namespace-scoped Role (deployments only)
cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deploy-bot-role
  namespace: ${NAMESPACE}
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deploy-bot-binding
  namespace: ${NAMESPACE}
subjects:
  - kind: ServiceAccount
    name: deploy-bot
    namespace: ${NAMESPACE}
roleRef:
  kind: Role
  name: deploy-bot-role
  apiGroup: rbac.authorization.k8s.io
EOF

# ─── Wait for all pods ───────────────────────────────────────────────────────

echo ""
echo "Waiting for deployments to roll out..."

for DEPLOY in learn-api learn-worker learn-app learn-order-service; do
  echo "  Waiting for $DEPLOY..."
  kubectl rollout status deployment/"$DEPLOY" -n "$NAMESPACE" --context "$CONTEXT" --timeout=120s 2>/dev/null || {
    echo "  WARNING: $DEPLOY did not roll out in time"
  }
done

# Extra wait for readiness probes to settle
echo "Waiting for pods to stabilize..."
sleep 10

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
