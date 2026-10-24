#!/bin/bash
# Chapter 10 Verification Script — Workloads
# Checks all three challenges: batch migration, scheduled cleanup, stateful service
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -u

PASSED=0
FAILED=0
NAMESPACE="learn-ch10"
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

echo "=== Chapter 10: The Fleet — Verification ==="
echo ""

if ! command -v kubectl &> /dev/null; then
    echo "  ERROR: kubectl is not installed."
    exit 1
fi

# Check namespace exists
if kubectl get namespace "${NAMESPACE}" --context "${CONTEXT}" > /dev/null 2>&1; then
    pass "Namespace '${NAMESPACE}' exists"
else
    fail "Namespace '${NAMESPACE}' not found (run: kubectl create namespace ${NAMESPACE})"
fi

echo ""

# ─── Challenge 1: Batch Migration ─────────────────────────────────────────────

echo "[Challenge 1: Batch Migration — Job]"

# Check Job exists
check "Job 'learn-db-migrate' exists in ${NAMESPACE}" \
    "kubectl get job learn-db-migrate -n ${NAMESPACE} --context ${CONTEXT}"

# Check Job has Complete condition
JOB_STATUS=$(kubectl get job learn-db-migrate -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
if [ "${JOB_STATUS}" = "True" ]; then
    pass "Job 'learn-db-migrate' has Complete condition"
else
    fail "Job 'learn-db-migrate' is not Complete (status: ${JOB_STATUS:-unknown})"
fi

# Check backoffLimit
BACKOFF=$(kubectl get job learn-db-migrate -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.backoffLimit}' 2>/dev/null || echo "")
if [ "${BACKOFF}" = "3" ]; then
    pass "Job has backoffLimit: 3"
else
    fail "Job backoffLimit is '${BACKOFF}' (expected 3)"
fi

# Check Pod is Completed
COMPLETED_PODS=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l job-name=learn-db-migrate \
    --field-selector=status.phase=Succeeded \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${COMPLETED_PODS}" -ge 1 ]; then
    pass "Job Pod is in Succeeded/Completed status (found ${COMPLETED_PODS})"
else
    fail "No Completed Pod found for Job 'learn-db-migrate'"
fi

# Check Pod labels
LABELED=$(kubectl get pods -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l job-name=learn-db-migrate,chapter=ch10 \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${LABELED}" -ge 1 ]; then
    pass "Job Pod has label chapter=ch10"
else
    fail "Job Pod missing label chapter=ch10"
fi

echo ""

# ─── Challenge 2: Scheduled Cleanup ───────────────────────────────────────────

echo "[Challenge 2: Scheduled Cleanup — CronJob]"

# Check CronJob exists
check "CronJob 'learn-cleanup' exists in ${NAMESPACE}" \
    "kubectl get cronjob learn-cleanup -n ${NAMESPACE} --context ${CONTEXT}"

# Check schedule is set
SCHEDULE=$(kubectl get cronjob learn-cleanup -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.schedule}' 2>/dev/null || echo "")
if [ -n "${SCHEDULE}" ]; then
    pass "CronJob has schedule: '${SCHEDULE}'"
else
    fail "CronJob has no schedule set"
fi

# Check successfulJobsHistoryLimit
HISTORY=$(kubectl get cronjob learn-cleanup -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.successfulJobsHistoryLimit}' 2>/dev/null || echo "")
if [ "${HISTORY}" = "3" ]; then
    pass "CronJob successfulJobsHistoryLimit: 3"
else
    fail "CronJob successfulJobsHistoryLimit is '${HISTORY}' (expected 3)"
fi

# Check concurrencyPolicy
CONCURRENCY=$(kubectl get cronjob learn-cleanup -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.concurrencyPolicy}' 2>/dev/null || echo "")
if [ "${CONCURRENCY}" = "Forbid" ]; then
    pass "CronJob concurrencyPolicy: Forbid"
else
    fail "CronJob concurrencyPolicy is '${CONCURRENCY}' (expected Forbid)"
fi

# Check at least one Job has been created
CRON_JOBS=$(kubectl get jobs -n "${NAMESPACE}" --context "${CONTEXT}" \
    -l app=cleanup \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "${CRON_JOBS}" -ge 1 ]; then
    pass "At least 1 Job created by CronJob (found ${CRON_JOBS})"
else
    # Also check by owner reference pattern
    CRON_JOBS_ALT=$(kubectl get jobs -n "${NAMESPACE}" --context "${CONTEXT}" \
        --no-headers 2>/dev/null | grep "learn-cleanup" | wc -l | tr -d ' ')
    if [ "${CRON_JOBS_ALT}" -ge 1 ]; then
        pass "At least 1 Job created by CronJob (found ${CRON_JOBS_ALT})"
    else
        fail "No Jobs found from CronJob — wait for schedule to trigger or use: kubectl create job test --from=cronjob/learn-cleanup -n ${NAMESPACE}"
    fi
fi

echo ""

# ─── Challenge 3: Stateful Service ────────────────────────────────────────────

echo "[Challenge 3: Stateful Service — StatefulSet]"

# Check headless Service exists
check "Service 'learn-cache-headless' exists in ${NAMESPACE}" \
    "kubectl get service learn-cache-headless -n ${NAMESPACE} --context ${CONTEXT}"

# Check Service is headless (clusterIP: None)
CLUSTER_IP=$(kubectl get service learn-cache-headless -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ "${CLUSTER_IP}" = "None" ]; then
    pass "Service 'learn-cache-headless' is headless (clusterIP: None)"
else
    fail "Service 'learn-cache-headless' clusterIP is '${CLUSTER_IP}' (expected None)"
fi

# Check StatefulSet exists
check "StatefulSet 'learn-cache' exists in ${NAMESPACE}" \
    "kubectl get statefulset learn-cache -n ${NAMESPACE} --context ${CONTEXT}"

# Check StatefulSet has 3 ready replicas
READY_REPLICAS=$(kubectl get statefulset learn-cache -n "${NAMESPACE}" --context "${CONTEXT}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "${READY_REPLICAS}" -ge 3 ]; then
    pass "StatefulSet has 3 ready replicas (found ${READY_REPLICAS})"
else
    fail "StatefulSet has ${READY_REPLICAS} ready replicas (expected 3)"
fi

# Check individual Pod names
for i in 0 1 2; do
    POD_STATUS=$(kubectl get pod "learn-cache-${i}" -n "${NAMESPACE}" --context "${CONTEXT}" \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "${POD_STATUS}" = "Running" ]; then
        pass "Pod 'learn-cache-${i}' exists and is Running"
    else
        fail "Pod 'learn-cache-${i}' status: ${POD_STATUS} (expected Running)"
    fi
done

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo "=== Summary ==="
echo "  Passed: ${PASSED}"
echo "  Failed: ${FAILED}"
echo ""

if [ "${FAILED}" -eq 0 ]; then
    echo "All checks passed! Chapter 10 complete."
    echo ""
    echo "The fleet is assembled. NoCappuccino has:"
    echo "  • Jobs for one-shot migrations"
    echo "  • CronJobs for scheduled cleanup"
    echo "  • StatefulSets for identity-aware services"
    echo ""
    echo "But the monitoring dashboard just went red."
    echo "The frontend can't reach the backend."
    echo "Time for Chapter 11: The Service Mesh."
    exit 0
else
    echo "${FAILED} check(s) failed. Review the output above and try again."
    echo ""
    echo "Quick diagnostic commands:"
    echo "  kubectl get jobs -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get cronjobs -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get statefulsets -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl get pods -n ${NAMESPACE} --context ${CONTEXT}"
    echo "  kubectl describe <resource> <name> -n ${NAMESPACE} --context ${CONTEXT}"
    exit 1
fi
