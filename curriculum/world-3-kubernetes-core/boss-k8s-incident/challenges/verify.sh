#!/bin/bash
# Boss Fight Verification Script — The Cluster Crisis
# Checks all five fixes independently. Partial credit is possible.
# Exit 0 = all checks passed (Boss defeated!)
# Exit 1 = one or more checks failed

set -u

PASSED=0
FAILED=0
NAMESPACE="learn-boss"
CLUSTER_NAME="learn-k8s"
CONTEXT="kind-${CLUSTER_NAME}"

# ─── Helpers ──────────────────────────────────────────────────────────────────

pass() {
    echo "  PASS: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "  FAIL: $1"
    FAILED=$((FAILED + 1))
}

check() {
    local description="$1"
    local command="$2"
    if eval "$command" > /dev/null 2>&1; then
        pass "$description"
    else
        fail "$description"
    fi
}

# ─── Pre-flight ───────────────────────────────────────────────────────────────

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║        BOSS FIGHT: The Cluster Crisis                ║"
echo "║        World 3 — Kubernetes Core                     ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "  ERROR: kubectl is not installed."
    exit 1
fi

if kubectl get namespace "${NAMESPACE}" --context "${CONTEXT}" > /dev/null 2>&1; then
    pass "Namespace '${NAMESPACE}' exists"
else
    fail "Namespace '${NAMESPACE}' not found (run: kubectl create namespace ${NAMESPACE})"
    echo ""
    echo "Cannot continue without the namespace. Deploy the broken state first."
    exit 1
fi

echo ""

# ─── Issue 1: CrashLoopBackOff — Order Service ──────────────────────────────

echo "[Issue 1: CrashLoopBackOff — Order Service]"

check "Deployment 'learn-order-service' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-order-service -n ${NAMESPACE} --context ${CONTEXT}"

# Check no Pods in CrashLoopBackOff
BAD_ORDER_PODS=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=order-service \
    --no-headers 2>/dev/null \
    | awk '{print $3}' \
    | grep -E "CrashLoopBackOff|Error|CreateContainerError" \
    | wc -l | tr -d ' ')
if [ "${BAD_ORDER_PODS}" -eq 0 ]; then
    pass "No order-service Pods in CrashLoopBackOff"
else
    fail "${BAD_ORDER_PODS} order-service Pod(s) still in error state"
fi

# Check Pods are Running
ORDER_RUNNING=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=order-service \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${ORDER_RUNNING}" -ge 2 ]; then
    pass "Order service: ${ORDER_RUNNING} Pods Running"
else
    fail "Order service: only ${ORDER_RUNNING} Pods Running (expected 2)"
fi

echo ""

# ─── Issue 2: Zero Endpoints — Payment Service ──────────────────────────────

echo "[Issue 2: Zero Endpoints — Payment Service]"

check "Service 'learn-payment-svc' exists in ${NAMESPACE}" \
    "kubectl get service learn-payment-svc -n ${NAMESPACE} --context ${CONTEXT}"

PAYMENT_ENDPOINTS=$(kubectl get endpoints learn-payment-svc -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w | tr -d ' ')
if [ "${PAYMENT_ENDPOINTS}" -ge 1 ]; then
    pass "Payment Service has ${PAYMENT_ENDPOINTS} endpoint(s) — selector fixed!"
else
    fail "Payment Service has no endpoints — selector still mismatched"
fi

# Verify Pods are Running
PAYMENT_RUNNING=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=payment \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${PAYMENT_RUNNING}" -ge 1 ]; then
    pass "Payment Pods: ${PAYMENT_RUNNING} Running"
else
    fail "No payment Pods Running"
fi

echo ""

# ─── Issue 3: PVC Pending — Analytics ────────────────────────────────────────

echo "[Issue 3: PVC Pending — Analytics Storage]"

check "PVC 'learn-analytics-data' exists in ${NAMESPACE}" \
    "kubectl get pvc learn-analytics-data -n ${NAMESPACE} --context ${CONTEXT}"

ANALYTICS_PVC=$(kubectl get pvc learn-analytics-data -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "${ANALYTICS_PVC}" = "Bound" ]; then
    pass "PVC 'learn-analytics-data' is Bound — StorageClass fixed!"
else
    fail "PVC 'learn-analytics-data' status: ${ANALYTICS_PVC} (expected Bound)"
fi

# Check analytics Pod is Running
ANALYTICS_RUNNING=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=analytics \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${ANALYTICS_RUNNING}" -ge 1 ]; then
    pass "Analytics Pod is Running"
else
    fail "Analytics Pod is not Running (likely waiting for PVC)"
fi

echo ""

# ─── Issue 4: Wrong ConfigMap — Database Connection ──────────────────────────

echo "[Issue 4: Wrong ConfigMap — Database Connection]"

check "ConfigMap 'learn-db-config' exists in ${NAMESPACE}" \
    "kubectl get configmap learn-db-config -n ${NAMESPACE} --context ${CONTEXT}"

DB_HOST=$(kubectl get configmap learn-db-config -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.data.DATABASE_HOST}' 2>/dev/null || echo "")

# Check that DATABASE_HOST points to the actual database Service
if echo "${DB_HOST}" | grep -q "learn-database-svc"; then
    pass "ConfigMap DATABASE_HOST points to 'learn-database-svc' (correct!)"
else
    fail "ConfigMap DATABASE_HOST is '${DB_HOST}' — should reference 'learn-database-svc'"
fi

# Check api-server Deployment is running
API_RUNNING=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=api-server \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${API_RUNNING}" -ge 1 ]; then
    pass "API server Pod is Running"
else
    fail "API server Pod is not Running"
fi

echo ""

# ─── Issue 5: DNS/Service Failure — Recommendation Service ──────────────────

echo "[Issue 5: Port Mismatch — Recommendation Service]"

check "Service 'learn-reco-svc' exists in ${NAMESPACE}" \
    "kubectl get service learn-reco-svc -n ${NAMESPACE} --context ${CONTEXT}"

# The fix here is targetPort, not selector. Endpoints should exist (selector is correct).
RECO_ENDPOINTS=$(kubectl get endpoints learn-reco-svc -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w | tr -d ' ')
if [ "${RECO_ENDPOINTS}" -ge 1 ]; then
    pass "Reco Service has ${RECO_ENDPOINTS} endpoint(s)"
else
    fail "Reco Service has no endpoints — check selector"
fi

# Verify the targetPort is correct (should be 5678, not 8080)
RECO_TARGET_PORT=$(kubectl get service learn-reco-svc -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || echo "unknown")
if [ "${RECO_TARGET_PORT}" = "5678" ]; then
    pass "Reco Service targetPort is 5678 (matches container)"
else
    fail "Reco Service targetPort is ${RECO_TARGET_PORT} — should be 5678 to match the container's listening port"
fi

# In-cluster connectivity test (the real proof)
echo "  INFO: Testing in-cluster connectivity to learn-reco-svc..."
kubectl delete pod learn-boss-verify-reco -n "${NAMESPACE}" --context "${CONTEXT}" --ignore-not-found=true 2>/dev/null || true
if kubectl run learn-boss-verify-reco \
    --rm -i \
    --restart=Never \
    -n "${NAMESPACE}" \
    --context "${CONTEXT}" \
    --timeout=30s \
    --image=curlimages/curl:latest \
    -- curl -sf --max-time 10 "http://learn-reco-svc:80" > /dev/null 2>&1; then
    pass "In-cluster curl to 'http://learn-reco-svc' returns a response"
else
    fail "In-cluster curl to 'http://learn-reco-svc' failed — check targetPort"
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                    RESULTS                           ║"
echo "╠═══════════════════════════════════════════════════════╣"
echo "║  Passed: ${PASSED}"
echo "║  Failed: ${FAILED}"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

TOTAL=$((PASSED + FAILED))

if [ "${FAILED}" -eq 0 ]; then
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║                                                       ║"
    echo "║   🏆  BOSS DEFEATED: The Cluster Crisis  🏆          ║"
    echo "║                                                       ║"
    echo "║   All 5 issues resolved.                              ║"
    echo "║                                                       ║"
    echo "║   World 3: Kubernetes Core — COMPLETE                 ║"
    echo "║                                                       ║"
    echo "║   Skills demonstrated:                                ║"
    echo "║     [x] K8s Architecture & debugging                  ║"
    echo "║     [x] Workload troubleshooting                      ║"
    echo "║     [x] Service & DNS diagnosis                       ║"
    echo "║     [x] Storage troubleshooting                       ║"
    echo "║     [x] ConfigMap management                          ║"
    echo "║                                                       ║"
    echo "║   Unlocked:                                           ║"
    echo "║     → World 4: Kubernetes Production                  ║"
    echo "║     → Architecture Interview Mode                     ║"
    echo "║     → Deep Dive: Advanced Networking                  ║"
    echo "║                                                       ║"
    echo "║   Dave's Monday message:                              ║"
    echo "║   'See? I told you Kubernetes would be reliable.'     ║"
    echo "║                                                       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 0
else
    FIXED=$((TOTAL - FAILED))
    echo "  ${FIXED} out of 5 issues resolved. ${FAILED} remaining."
    echo ""
    echo "  Keep going! Each fix is independent."
    echo ""
    echo "  Diagnostic commands:"
    echo "    kubectl get all -n ${NAMESPACE} --context ${CONTEXT}"
    echo "    kubectl get pvc -n ${NAMESPACE} --context ${CONTEXT}"
    echo "    kubectl get endpoints -n ${NAMESPACE} --context ${CONTEXT}"
    echo "    kubectl describe <resource> <name> -n ${NAMESPACE} --context ${CONTEXT}"
    echo "    kubectl logs <pod-name> -n ${NAMESPACE} --context ${CONTEXT}"
    exit 1
fi
