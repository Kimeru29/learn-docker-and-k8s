#!/bin/bash
# Known-good solution for World 3 Boss Fight: The Cluster Crisis
# Used by functional tests only. NOT visible to learners during gameplay.
# Tests: apply fixed K8s manifests → wait for pods → verify passes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VERIFY="$PROJECT_DIR/curriculum/world-3-kubernetes-core/boss-k8s-incident/challenges/verify.sh"

CLUSTER_NAME="learn-k8s"
CONTEXT="kind-${CLUSTER_NAME}"
NAMESPACE="learn-boss"

echo "=== W3 Boss Fight: Known-Good Solution Test ==="
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
kubectl delete namespace "$NAMESPACE" --context "$CONTEXT" --ignore-not-found=true --wait=true 2>/dev/null || true
kubectl create namespace "$NAMESPACE" --context "$CONTEXT"

# ─── Resource 1: Order Service (FIXED — echo instead of ech) ─────────────────

echo "Applying fixed manifests..."

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-order-service
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        world: w03
        chapter: boss
    spec:
      containers:
        - name: order
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Starting order service' && sleep 3600"]
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
EOF

# ─── Resource 2: Payment Service (FIXED — selector payment, not payments) ────

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-payment-service
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment
  template:
    metadata:
      labels:
        app: payment
        world: w03
        chapter: boss
    spec:
      containers:
        - name: payment
          image: hashicorp/http-echo:latest
          args:
            - "-text=Payment processed!"
            - "-listen=:5678"
          ports:
            - containerPort: 5678
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-payment-svc
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  type: ClusterIP
  selector:
    app: payment
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5678
EOF

# ─── Resource 3: Analytics PVC (FIXED — storageClassName: standard) ──────────

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: learn-analytics-data
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-analytics
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: analytics
  template:
    metadata:
      labels:
        app: analytics
        world: w03
        chapter: boss
    spec:
      containers:
        - name: analytics
          image: busybox:1.36
          command: ["sh", "-c", "echo 'Analytics running' && sleep 3600"]
          volumeMounts:
            - name: data
              mountPath: /data
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: learn-analytics-data
EOF

# ─── Resource 4: Database + ConfigMap (FIXED — correct DATABASE_HOST) ────────

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: learn-db-config
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
data:
  DATABASE_HOST: "learn-database-svc"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "nocappuccino"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-api-server
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
        world: w03
        chapter: boss
    spec:
      containers:
        - name: api
          image: busybox:1.36
          command: ["sh", "-c", "echo \"Connecting to \$(cat /config/DATABASE_HOST):\$(cat /config/DATABASE_PORT)/\$(cat /config/DATABASE_NAME)\" && sleep 3600"]
          volumeMounts:
            - name: config
              mountPath: /config
              readOnly: true
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
      volumes:
        - name: config
          configMap:
            name: learn-db-config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-database
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
        world: w03
        chapter: boss
    spec:
      containers:
        - name: db
          image: hashicorp/http-echo:latest
          args:
            - "-text=Database OK"
            - "-listen=:5432"
          ports:
            - containerPort: 5432
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-database-svc
  namespace: ${NAMESPACE}
spec:
  selector:
    app: database
  ports:
    - port: 5432
      targetPort: 5432
EOF

# ─── Resource 5: Reco Service (FIXED — targetPort 5678) ──────────────────────

cat <<EOF | kubectl apply --context "$CONTEXT" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-reco-service
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  replicas: 2
  selector:
    matchLabels:
      app: reco-service
  template:
    metadata:
      labels:
        app: reco-service
        world: w03
        chapter: boss
    spec:
      containers:
        - name: reco
          image: hashicorp/http-echo:latest
          args:
            - "-text=Try Ethiopian Yirgacheffe!"
            - "-listen=:5678"
          ports:
            - containerPort: 5678
          resources:
            requests:
              memory: "16Mi"
              cpu: "25m"
            limits:
              memory: "32Mi"
              cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-reco-svc
  namespace: ${NAMESPACE}
  labels:
    app: learn-docker-k8s
    world: w03
    chapter: boss
spec:
  type: ClusterIP
  selector:
    app: reco-service
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5678
EOF

# ─── Wait for all pods ───────────────────────────────────────────────────────

echo ""
echo "Waiting for deployments to roll out..."

for DEPLOY in learn-order-service learn-payment-service learn-analytics learn-api-server learn-database learn-reco-service; do
  echo "  Waiting for $DEPLOY..."
  kubectl rollout status deployment/"$DEPLOY" -n "$NAMESPACE" --context "$CONTEXT" --timeout=120s 2>/dev/null || {
    echo "  WARNING: $DEPLOY did not roll out in time"
  }
done

# Extra wait for pods to stabilize
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
