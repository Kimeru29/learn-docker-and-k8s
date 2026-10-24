#!/bin/bash
# Chapter 11 Verification Script — K8s Networking
# Checks all four challenges
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -u

PASSED=0
FAILED=0
NAMESPACE="learn-ch11"
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

echo "=== Chapter 11: The Service Mesh — Verification ==="
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "  ERROR: kubectl is not installed."
    exit 1
fi

if kubectl get namespace "${NAMESPACE}" --context "${CONTEXT}" > /dev/null 2>&1; then
    pass "Namespace '${NAMESPACE}' exists"
else
    fail "Namespace '${NAMESPACE}' not found (run: kubectl create namespace ${NAMESPACE})"
fi

echo ""

# ─── Challenge 1: Service Discovery ──────────────────────────────────────────

echo "[Challenge 1: Service Discovery — frontend/backend with ClusterIP]"

# Check backend Deployment
check "Deployment 'learn-backend' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-backend -n ${NAMESPACE} --context ${CONTEXT}"

# Check backend ready replicas
BACKEND_READY=$(kubectl get deployment learn-backend -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${BACKEND_READY}" -ge 1 ]; then
    pass "Deployment 'learn-backend' has ${BACKEND_READY} ready replica(s)"
else
    fail "Deployment 'learn-backend' has no ready replicas"
fi

# Check Service exists
check "Service 'learn-backend-svc' exists in ${NAMESPACE}" \
    "kubectl get service learn-backend-svc -n ${NAMESPACE} --context ${CONTEXT}"

# Check Service type
SVC_TYPE=$(kubectl get service learn-backend-svc -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.type}' 2>/dev/null || echo "unknown")
if [ "${SVC_TYPE}" = "ClusterIP" ]; then
    pass "Service 'learn-backend-svc' is ClusterIP"
else
    fail "Service 'learn-backend-svc' type is '${SVC_TYPE}' (expected ClusterIP)"
fi

# Check Endpoints
ENDPOINT_COUNT=$(kubectl get endpoints learn-backend-svc -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w | tr -d ' ')
if [ "${ENDPOINT_COUNT}" -ge 1 ]; then
    pass "Service 'learn-backend-svc' has ${ENDPOINT_COUNT} endpoint(s)"
else
    fail "Service 'learn-backend-svc' has no endpoints — selector may not match Pod labels"
fi

# In-cluster connectivity test
echo "  INFO: Testing in-cluster connectivity (may take 10-15s)..."
kubectl delete pod learn-ch11-verify-curl -n "${NAMESPACE}" --context "${CONTEXT}" --ignore-not-found=true 2>/dev/null || true
if kubectl run learn-ch11-verify-curl \
    --rm -i \
    --restart=Never \
    -n "${NAMESPACE}" \
    --context "${CONTEXT}" \
    --timeout=30s \
    --image=curlimages/curl:latest \
    -- curl -sf --max-time 10 "http://learn-backend-svc:80" > /dev/null 2>&1; then
    pass "In-cluster curl to 'http://learn-backend-svc' succeeded"
else
    fail "In-cluster curl to 'http://learn-backend-svc' failed"
fi

echo ""

# ─── Challenge 2: Expose Externally ──────────────────────────────────────────

echo "[Challenge 2: Expose Externally — NodePort Service]"

# Check web Deployment
check "Deployment 'learn-web' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-web -n ${NAMESPACE} --context ${CONTEXT}"

READY=$(kubectl get deployment learn-web -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${READY}" -ge 1 ]; then
    pass "Deployment 'learn-web' has ${READY} ready replica(s)"
else
    fail "Deployment 'learn-web' has no ready replicas"
fi

# Check NodePort Service
check "Service 'learn-web-nodeport' exists in ${NAMESPACE}" \
    "kubectl get service learn-web-nodeport -n ${NAMESPACE} --context ${CONTEXT}"

NP_TYPE=$(kubectl get service learn-web-nodeport -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.type}' 2>/dev/null || echo "unknown")
if [ "${NP_TYPE}" = "NodePort" ]; then
    pass "Service 'learn-web-nodeport' is NodePort"
else
    fail "Service 'learn-web-nodeport' type is '${NP_TYPE}' (expected NodePort)"
fi

# Check Endpoints
NP_ENDPOINTS=$(kubectl get endpoints learn-web-nodeport -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w | tr -d ' ')
if [ "${NP_ENDPOINTS}" -ge 1 ]; then
    pass "Service 'learn-web-nodeport' has ${NP_ENDPOINTS} endpoint(s)"
else
    fail "Service 'learn-web-nodeport' has no endpoints"
fi

echo ""

# ─── Challenge 3: Network Segmentation ───────────────────────────────────────

echo "[Challenge 3: Network Segmentation — NetworkPolicies]"

# Check NetworkPolicies exist
check "NetworkPolicy 'learn-deny-all' exists in ${NAMESPACE}" \
    "kubectl get networkpolicy learn-deny-all -n ${NAMESPACE} --context ${CONTEXT}"

check "NetworkPolicy 'learn-allow-dns' exists in ${NAMESPACE}" \
    "kubectl get networkpolicy learn-allow-dns -n ${NAMESPACE} --context ${CONTEXT}"

check "NetworkPolicy 'learn-allow-frontend-to-backend' exists in ${NAMESPACE}" \
    "kubectl get networkpolicy learn-allow-frontend-to-backend -n ${NAMESPACE} --context ${CONTEXT}"

check "NetworkPolicy 'learn-allow-backend-to-database' exists in ${NAMESPACE}" \
    "kubectl get networkpolicy learn-allow-backend-to-database -n ${NAMESPACE} --context ${CONTEXT}"

# Check database Deployment
check "Deployment 'learn-database' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-database -n ${NAMESPACE} --context ${CONTEXT}"

echo ""

# ─── Challenge 4: Debug DNS ──────────────────────────────────────────────────

echo "[Challenge 4: Debug DNS — learn-reco-svc]"

# Check recommendations Deployment
check "Deployment 'learn-recommendations' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-recommendations -n ${NAMESPACE} --context ${CONTEXT}"

RECO_READY=$(kubectl get deployment learn-recommendations -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${RECO_READY}" -ge 1 ]; then
    pass "Deployment 'learn-recommendations' has ${RECO_READY} ready replica(s)"
else
    fail "Deployment 'learn-recommendations' has no ready replicas"
fi

# Check Service exists
check "Service 'learn-reco-svc' exists in ${NAMESPACE}" \
    "kubectl get service learn-reco-svc -n ${NAMESPACE} --context ${CONTEXT}"

# Check Endpoints
RECO_ENDPOINTS=$(kubectl get endpoints learn-reco-svc -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w | tr -d ' ')
if [ "${RECO_ENDPOINTS}" -ge 1 ]; then
    pass "Service 'learn-reco-svc' has ${RECO_ENDPOINTS} endpoint(s) (selector fixed!)"
else
    fail "Service 'learn-reco-svc' has no endpoints — selector likely still mismatched"
fi

# In-cluster connectivity test for reco service
echo "  INFO: Testing in-cluster connectivity to learn-reco-svc..."
kubectl delete pod learn-ch11-verify-reco -n "${NAMESPACE}" --context "${CONTEXT}" --ignore-not-found=true 2>/dev/null || true
if kubectl run learn-ch11-verify-reco \
    --rm -i \
    --restart=Never \
    -n "${NAMESPACE}" \
    --context "${CONTEXT}" \
    --timeout=30s \
    --image=curlimages/curl:latest \
    -- curl -sf --max-time 10 "http://learn-reco-svc:80" > /dev/null 2>&1; then
    pass "In-cluster curl to 'http://learn-reco-svc' succeeded"
else
    fail "In-cluster curl to 'http://learn-reco-svc' failed"
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  Passed: ${PASSED}"
echo "  Failed: ${FAILED}"
echo ""

if [ "${FAILED}" -eq 0 ]; then
    echo "All checks passed! Chapter 11 complete."
    echo ""
    echo "Networking is solid:"
    echo "  • Services route correctly"
    echo "  • DNS resolves"
    echo "  • NetworkPolicies enforce segmentation"
    echo "  • NodePort provides external access"
    echo ""
    echo "But a customer just reported lost data."
    echo "The database Pod restarted and the data wasn't persisted."
    echo "Time for Chapter 12: The Persistent Roast."
    exit 0
else
    echo "${FAILED} check(s) failed. Review the output above and try again."
    echo ""
    echo "Quick diagnostic commands:"
    echo "  kubectl get pods -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get services -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get endpoints -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get networkpolicies -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl describe service <name> -n ${NAMESPACE} --context ${CONTEXT}"
    exit 1
fi
