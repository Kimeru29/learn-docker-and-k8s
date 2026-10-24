#!/bin/bash
# Chapter 9 Verification Script — K8s Architecture
# Checks all three challenges: self-healing, explore architecture, debug ImagePullBackOff
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -u

PASSED=0
FAILED=0
NAMESPACE="learn-ch09"
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

echo "=== Chapter 9: The Giant Roaster — Verification ==="
echo ""

# Check kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "  ERROR: kubectl is not installed. Cannot verify chapter 9."
    exit 1
fi

# Check kind is available
if ! command -v kind &> /dev/null; then
    echo "  ERROR: kind is not installed. Cannot verify chapter 9."
    exit 1
fi

# ─── Cluster Check ────────────────────────────────────────────────────────────

echo "[Cluster]"

# Check kind cluster exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    pass "kind cluster '${CLUSTER_NAME}' exists"
else
    fail "kind cluster '${CLUSTER_NAME}' not found (run: kind create cluster --name ${CLUSTER_NAME})"
fi

# Check kubectl can reach the cluster
if kubectl cluster-info --context "${CONTEXT}" > /dev/null 2>&1; then
    pass "kubectl can connect to context '${CONTEXT}'"
else
    fail "kubectl cannot connect to context '${CONTEXT}' (run: kubectl cluster-info --context ${CONTEXT})"
fi

# Check namespace exists
if kubectl get namespace "${NAMESPACE}" --context "${CONTEXT}" > /dev/null 2>&1; then
    pass "Namespace '${NAMESPACE}' exists"
else
    fail "Namespace '${NAMESPACE}' not found (run: kubectl create namespace ${NAMESPACE})"
fi

echo ""

# ─── Challenge 1: Self-Healing ────────────────────────────────────────────────

echo "[Challenge 1: Self-Healing — nginx Deployment with 3 replicas]"

# Check Deployment exists
check "Deployment 'learn-nginx' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-nginx -n ${NAMESPACE} --context ${CONTEXT}"

# Check desired replicas
DESIRED=$(kubectl get deployment learn-nginx -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
if [ "${DESIRED}" -eq 3 ]; then
    pass "Deployment 'learn-nginx' has 3 desired replicas"
else
    fail "Deployment 'learn-nginx' has ${DESIRED} desired replicas (expected 3)"
fi

# Check 3 Pods are Running
RUNNING_COUNT=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=nginx \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${RUNNING_COUNT}" -ge 3 ]; then
    pass "3 nginx Pods are Running in ${NAMESPACE} (found ${RUNNING_COUNT})"
else
    fail "Expected 3 Running nginx Pods, found ${RUNNING_COUNT} (check: kubectl get pods -n ${NAMESPACE} -l app=nginx)"
fi

# Check labels
LABELED_COUNT=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=nginx,chapter=ch09 \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${LABELED_COUNT}" -ge 3 ]; then
    pass "Pods have correct labels (app=nginx, chapter=ch09)"
else
    fail "Expected 3 Pods with labels app=nginx,chapter=ch09, found ${LABELED_COUNT}"
fi

echo ""

# ─── Challenge 2: Explore Architecture ────────────────────────────────────────

echo "[Challenge 2: Explore Architecture — ConfigMap with answers]"

# Check ConfigMap exists
check "ConfigMap 'learn-architecture-answers' exists in ${NAMESPACE}" \
    "kubectl get configmap learn-architecture-answers -n ${NAMESPACE} --context ${CONTEXT}"

# Check ConfigMap has the expected key
CM_KEY=$(kubectl get configmap learn-architecture-answers -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.data}' 2>/dev/null || echo "")
if [ -n "${CM_KEY}" ] && [ "${CM_KEY}" != "{}" ]; then
    pass "ConfigMap 'learn-architecture-answers' has data"
else
    fail "ConfigMap 'learn-architecture-answers' is empty — add your answers file"
fi

# Check ConfigMap has the right key name
HAS_KEY=$(kubectl get configmap learn-architecture-answers -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.data.learn-architecture-answers\.txt}' 2>/dev/null || echo "")
if [ -n "${HAS_KEY}" ]; then
    pass "ConfigMap contains key 'learn-architecture-answers.txt'"
else
    fail "ConfigMap missing key 'learn-architecture-answers.txt' — use --from-file=learn-architecture-answers.txt"
fi

echo ""

# ─── Challenge 3: Debug ImagePullBackOff ──────────────────────────────────────

echo "[Challenge 3: Debug ImagePullBackOff — learn-cloudbrew Deployment]"

# Check Deployment exists
check "Deployment 'learn-cloudbrew' exists in ${NAMESPACE}" \
    "kubectl get deployment learn-cloudbrew -n ${NAMESPACE} --context ${CONTEXT}"

# Check no Pods in CrashLoopBackOff or ImagePullBackOff
BAD_PODS=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=cloudbrew \
    --no-headers 2>/dev/null \
    | awk '{print $3}' \
    | grep -E "CrashLoopBackOff|ImagePullBackOff|ErrImagePull|Error" \
    | wc -l | tr -d ' ')
if [ "${BAD_PODS}" -eq 0 ]; then
    pass "No cloudbrew Pods in CrashLoopBackOff/ImagePullBackOff/ErrImagePull"
else
    fail "${BAD_PODS} Pod(s) still in a failed state — run 'kubectl describe pod <name> -n ${NAMESPACE}' to diagnose"
fi

# Check 2 cloudbrew Pods are Running
CLOUDBREW_RUNNING=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=cloudbrew \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${CLOUDBREW_RUNNING}" -ge 2 ]; then
    pass "2+ cloudbrew Pods are Running (found ${CLOUDBREW_RUNNING})"
else
    fail "Expected 2+ Running cloudbrew Pods, found ${CLOUDBREW_RUNNING}"
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  Passed: ${PASSED}"
echo "  Failed: ${FAILED}"
echo ""

if [ "${FAILED}" -eq 0 ]; then
    echo "All checks passed! Chapter 9 complete."
    echo ""
    echo "You kept NoCappuccino alive through the traffic spike."
    echo "The cluster is healthy. Self-healing is proven."
    echo "Dave sent a voice memo: 'Sarah... you're a wizard.'"
    echo ""
    echo "But not everything is a Deployment."
    echo "Time for Chapter 10: The Fleet."
    exit 0
else
    echo "${FAILED} check(s) failed. Review the output above and try again."
    echo ""
    echo "Quick diagnostic commands:"
    echo "  kubectl get pods -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get deployments -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get configmap -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl describe pod <pod-name> -n ${NAMESPACE} --context ${CONTEXT}"
    exit 1
fi
