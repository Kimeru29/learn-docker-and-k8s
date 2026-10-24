#!/bin/bash
# Chapter 12 Verification Script — K8s Storage
# Checks all three challenges: persist database, shared storage, storage troubleshooting
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -u

PASSED=0
FAILED=0
NAMESPACE="learn-ch12"
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

echo "=== Chapter 12: The Persistent Roast — Verification ==="
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

# ─── Challenge 1: Persist Database ────────────────────────────────────────────

echo "[Challenge 1: Persist Database — PVC + PostgreSQL]"

# Check PVC exists
check "PVC 'learn-db-data' exists in ${NAMESPACE}" \
    "kubectl get pvc learn-db-data -n ${NAMESPACE} --context ${CONTEXT}"

# Check PVC is Bound
PVC_STATUS=$(kubectl get pvc learn-db-data -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "${PVC_STATUS}" = "Bound" ]; then
    pass "PVC 'learn-db-data' is Bound"
else
    fail "PVC 'learn-db-data' status: ${PVC_STATUS} (expected Bound)"
fi

# Check Deployment exists
check "Deployment 'learn-postgres' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-postgres -n ${NAMESPACE} --context ${CONTEXT}"

# Check Deployment has ready replicas
PG_READY=$(kubectl get deployment learn-postgres -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${PG_READY}" -ge 1 ]; then
    pass "Deployment 'learn-postgres' has ${PG_READY} ready replica(s)"
else
    fail "Deployment 'learn-postgres' has no ready replicas"
fi

# Check Pod mounts a PVC
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=postgres --no-headers -o custom-columns=':metadata.name' 2>/dev/null | head -1)
if [ -n "${POD_NAME}" ]; then
    HAS_PVC=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" --context "${CONTEXT}" \
        -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim)].name}' 2>/dev/null || echo "")
    if [ -n "${HAS_PVC}" ]; then
        pass "Pod '${POD_NAME}' mounts a PVC"
    else
        fail "Pod '${POD_NAME}' does not mount any PVC"
    fi
else
    fail "No postgres Pod found"
fi

# Check Pod labels
PG_LABELED=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=postgres,chapter=ch12 \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${PG_LABELED}" -ge 1 ]; then
    pass "Postgres Pod has correct labels"
else
    fail "Postgres Pod missing label chapter=ch12"
fi

echo ""

# ─── Challenge 2: Shared Storage ─────────────────────────────────────────────

echo "[Challenge 2: Shared Storage — ConfigMap Volume]"

# Check ConfigMap exists
check "ConfigMap 'learn-app-config' exists in ${NAMESPACE}" \
    "kubectl get configmap learn-app-config -n ${NAMESPACE} --context ${CONTEXT}"

# Check ConfigMap has expected keys
for KEY in APP_TITLE APP_THEME APP_VERSION; do
    VALUE=$(kubectl get configmap learn-app-config -n "${NAMESPACE}" --context "${CONTEXT}" \
        -o jsonpath="{.data.${KEY}}" 2>/dev/null || echo "")
    if [ -n "${VALUE}" ]; then
        pass "ConfigMap has key '${KEY}' = '${VALUE}'"
    else
        fail "ConfigMap missing key '${KEY}'"
    fi
done

# Check Deployment exists
check "Deployment 'learn-config-reader' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-config-reader -n ${NAMESPACE} --context ${CONTEXT}"

# Check ready replicas
CR_READY=$(kubectl get deployment learn-config-reader -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${CR_READY}" -ge 1 ]; then
    pass "Deployment 'learn-config-reader' has ${CR_READY} ready replica(s)"
else
    fail "Deployment 'learn-config-reader' has no ready replicas"
fi

# Check Pod mounts a configMap volume
CR_POD=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=config-reader --no-headers -o custom-columns=':metadata.name' 2>/dev/null | head -1)
if [ -n "${CR_POD}" ]; then
    HAS_CM=$(kubectl get pod "${CR_POD}" -n "${NAMESPACE}" --context "${CONTEXT}" \
        -o jsonpath='{.spec.volumes[?(@.configMap)].name}' 2>/dev/null || echo "")
    if [ -n "${HAS_CM}" ]; then
        pass "Pod '${CR_POD}' mounts a configMap volume"
    else
        fail "Pod '${CR_POD}' does not mount any configMap volume"
    fi
else
    fail "No config-reader Pod found"
fi

echo ""

# ─── Challenge 3: Storage Troubleshooting ─────────────────────────────────────

echo "[Challenge 3: Storage Troubleshooting — PVC Binding Fix]"

# Check PVC exists
check "PVC 'learn-reco-data' exists in ${NAMESPACE}" \
    "kubectl get pvc learn-reco-data -n ${NAMESPACE} --context ${CONTEXT}"

# Check PVC is Bound
RECO_PVC_STATUS=$(kubectl get pvc learn-reco-data -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "${RECO_PVC_STATUS}" = "Bound" ]; then
    pass "PVC 'learn-reco-data' is Bound (fixed!)"
else
    fail "PVC 'learn-reco-data' status: ${RECO_PVC_STATUS} (expected Bound — check StorageClass)"
fi

# Check Deployment exists
check "Deployment 'learn-reco-engine' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-reco-engine -n ${NAMESPACE} --context ${CONTEXT}"

# Check ready replicas
RECO_READY=$(kubectl get deployment learn-reco-engine -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${RECO_READY}" -ge 1 ]; then
    pass "Deployment 'learn-reco-engine' has ${RECO_READY} ready replica(s)"
else
    fail "Deployment 'learn-reco-engine' has no ready replicas (Pod likely Pending due to PVC)"
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  Passed: ${PASSED}"
echo "  Failed: ${FAILED}"
echo ""

if [ "${FAILED}" -eq 0 ]; then
    echo "All checks passed! Chapter 12 complete."
    echo ""
    echo "The data is safe:"
    echo "  • Databases survive Pod restarts (PVCs)"
    echo "  • ConfigMaps propagate to running Pods"
    echo "  • Storage troubleshooting mastered"
    echo ""
    echo "But five alerts just fired simultaneously..."
    echo "Time for the Boss Fight: The Cluster Crisis."
    exit 0
else
    echo "${FAILED} check(s) failed. Review the output above and try again."
    echo ""
    echo "Quick diagnostic commands:"
    echo "  kubectl get pvc -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get pods -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get configmap -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl describe pvc <name> -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl describe pod <name> -n ${NAMESPACE} --context ${CONTEXT}"
    exit 1
fi
