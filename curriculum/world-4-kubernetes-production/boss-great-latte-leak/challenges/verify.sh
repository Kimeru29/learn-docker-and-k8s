#!/usr/bin/env bash
# =============================================================================
# Boss Fight Verification Script: The Great Latte Leak
# =============================================================================
# Checks all five simultaneous failures:
#   1. API Deployment (ImagePullBackOff fix)
#   2. Worker Deployment (OOMKilled fix)
#   3. Credential Leak (Secret migration)
#   4. Order Service (Readiness probe)
#   5. RBAC Violation (ServiceAccount lockdown)
# =============================================================================

set -uo pipefail

NAMESPACE="learn-boss-w4"
PASS=0
FAIL=0
WARNINGS=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass() {
  echo -e "  ${GREEN}[PASS]${RESET} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "  ${RED}[FAIL]${RESET} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "  ${YELLOW}[WARN]${RESET} $1"
  WARNINGS=$((WARNINGS + 1))
}

section() {
  echo ""
  echo -e "${BOLD}--- $1 ---${RESET}"
}

# =============================================================================
# Preflight
# =============================================================================
section "Preflight"

if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}ERROR: kubectl cannot connect to a cluster.${RESET}"
  echo "Make sure your kind cluster is running: kind get clusters"
  exit 1
fi
pass "kubectl can connect to cluster"

if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  fail "Namespace '$NAMESPACE' does not exist — run the boss fight setup first"
  exit 1
fi
pass "Namespace '$NAMESPACE' exists"

# =============================================================================
# Issue 1: API Deployment (ImagePullBackOff)
# =============================================================================
section "Issue 1: API Deployment"

# No pods in ImagePullBackOff
PULL_BACK_OFF=$(kubectl get pods -n "$NAMESPACE" -l app=learn-api --no-headers 2>/dev/null \
  | grep -c "ImagePullBackOff\|ErrImagePull" || true)
if [ "$PULL_BACK_OFF" -eq 0 ]; then
  pass "No API pods in ImagePullBackOff state"
else
  fail "Found $PULL_BACK_OFF API pod(s) in ImagePullBackOff — check the image tag"
fi

# API pods are Running
API_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app=learn-api \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$API_RUNNING" -ge 1 ]; then
  pass "learn-api has $API_RUNNING Running pod(s)"
else
  fail "learn-api has no Running pods"
fi

# Image tag is valid
API_IMAGE=$(kubectl get deployment learn-api -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
if echo "$API_IMAGE" | grep -qvE "latestt|alpin$"; then
  pass "API image tag appears valid: $API_IMAGE"
else
  fail "API image tag still has a typo: $API_IMAGE"
fi

# =============================================================================
# Issue 2: Worker OOMKilled
# =============================================================================
section "Issue 2: Worker Deployment (OOMKilled)"

# No OOMKilled or CrashLoopBackOff
OOM_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app=learn-worker --no-headers 2>/dev/null \
  | grep -cE "OOMKilled|CrashLoopBackOff" || true)
if [ "$OOM_COUNT" -eq 0 ]; then
  pass "No worker pods in OOMKilled or CrashLoopBackOff"
else
  fail "Found $OOM_COUNT worker pod(s) in OOMKilled/CrashLoopBackOff"
fi

# Worker is Running
WORKER_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app=learn-worker \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$WORKER_RUNNING" -ge 1 ]; then
  pass "learn-worker has $WORKER_RUNNING Running pod(s)"
else
  fail "learn-worker has no Running pods"
fi

# Memory limit is sufficient
WORKER_MEM_LIMIT=$(kubectl get deployment learn-worker -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
if [ -n "$WORKER_MEM_LIMIT" ]; then
  MEM_VALUE=$(echo "$WORKER_MEM_LIMIT" | sed 's/[^0-9]//g')
  MEM_UNIT=$(echo "$WORKER_MEM_LIMIT" | sed 's/[0-9]//g')
  if [[ "$MEM_UNIT" == "Gi" ]]; then
    MEM_MI=$((MEM_VALUE * 1024))
  else
    MEM_MI=$MEM_VALUE
  fi
  if [ "$MEM_MI" -ge 32 ]; then
    pass "Worker memory limit is $WORKER_MEM_LIMIT (sufficient)"
  else
    fail "Worker memory limit is $WORKER_MEM_LIMIT — still too low"
  fi
else
  fail "Worker memory limit is not set"
fi

# =============================================================================
# Issue 3: Credential Leak
# =============================================================================
section "Issue 3: Credential Leak"

# ConfigMap does not contain credentials
if kubectl get configmap app-config -n "$NAMESPACE" &>/dev/null; then
  CONFIG_HAS_CREDS=$(kubectl get configmap app-config -n "$NAMESPACE" -o yaml 2>/dev/null \
    | grep -cE "DB_PASSWORD|DB_USER" || true)
  if [ "$CONFIG_HAS_CREDS" -eq 0 ]; then
    pass "app-config ConfigMap does not contain DB_PASSWORD or DB_USER"
  else
    fail "app-config ConfigMap still contains sensitive credentials"
  fi
else
  warn "app-config ConfigMap not found — was it deleted entirely?"
fi

# Secret exists with credentials
if kubectl get secret db-credentials -n "$NAMESPACE" &>/dev/null; then
  pass "Secret 'db-credentials' exists"

  SECRET_HAS_PASSWORD=$(kubectl get secret db-credentials -n "$NAMESPACE" \
    -o jsonpath='{.data}' 2>/dev/null | grep -c "DB_PASSWORD" || true)
  if [ "$SECRET_HAS_PASSWORD" -ge 1 ]; then
    pass "Secret contains DB_PASSWORD"
  else
    fail "Secret exists but does not contain DB_PASSWORD"
  fi

  SECRET_HAS_USER=$(kubectl get secret db-credentials -n "$NAMESPACE" \
    -o jsonpath='{.data}' 2>/dev/null | grep -c "DB_USER" || true)
  if [ "$SECRET_HAS_USER" -ge 1 ]; then
    pass "Secret contains DB_USER"
  else
    fail "Secret exists but does not contain DB_USER"
  fi
else
  fail "Secret 'db-credentials' not found"
fi

# learn-app mounts the secret (check for volume mount)
APP_VOLUMES=$(kubectl get deployment learn-app -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.volumes}' 2>/dev/null || echo "")
if echo "$APP_VOLUMES" | grep -q "db-credentials"; then
  pass "learn-app mounts db-credentials as a volume"
else
  # Also accept if credentials are injected via secretKeyRef (less ideal but valid)
  APP_ENV=$(kubectl get deployment learn-app -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].env}' 2>/dev/null || echo "")
  if echo "$APP_ENV" | grep -q "secretKeyRef"; then
    warn "learn-app reads credentials from Secret via env vars (volume mount preferred)"
  else
    fail "learn-app does not reference db-credentials Secret"
  fi
fi

# =============================================================================
# Issue 4: Order Service Readiness
# =============================================================================
section "Issue 4: Order Service Health"

# Readiness probe is configured
READINESS_PROBE=$(kubectl get deployment learn-order-service -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
if [ -n "$READINESS_PROBE" ] && [ "$READINESS_PROBE" != "null" ]; then
  pass "learn-order-service has a readiness probe configured"
else
  fail "learn-order-service has no readiness probe — traffic goes to broken pods"
fi

# At least some pods are Running
ORDER_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app=learn-order-service \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$ORDER_RUNNING" -ge 1 ]; then
  pass "learn-order-service has $ORDER_RUNNING Running pod(s)"
else
  fail "learn-order-service has no Running pods"
fi

# Endpoints are filtered (not all pods in endpoints if some are unhealthy)
ENDPOINT_IPS=$(kubectl get endpoints learn-order-service -n "$NAMESPACE" \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -c "ip" || true)
if [ "$ENDPOINT_IPS" -ge 1 ]; then
  pass "learn-order-service has $ENDPOINT_IPS endpoint(s) (healthy pods only)"
else
  warn "learn-order-service has no endpoints — all pods may be unhealthy"
fi

# =============================================================================
# Issue 5: RBAC Violation
# =============================================================================
section "Issue 5: RBAC Violation"

# ClusterRoleBinding to cluster-admin should not exist
ADMIN_BINDING=$(kubectl get clusterrolebinding deploy-bot-admin 2>/dev/null && echo "exists" || echo "gone")
if [ "$ADMIN_BINDING" = "gone" ]; then
  pass "ClusterRoleBinding 'deploy-bot-admin' has been removed"
else
  fail "ClusterRoleBinding 'deploy-bot-admin' still exists — deploy-bot has cluster-admin access"
fi

# deploy-bot should NOT have cluster-admin level access
if kubectl auth can-i delete namespaces \
  --as=system:serviceaccount:"$NAMESPACE":deploy-bot 2>/dev/null | grep -q "^yes"; then
  fail "deploy-bot CAN delete namespaces — still has excessive permissions"
else
  pass "deploy-bot CANNOT delete namespaces (no longer cluster-admin)"
fi

if kubectl auth can-i get secrets \
  --as=system:serviceaccount:"$NAMESPACE":deploy-bot \
  -n "$NAMESPACE" 2>/dev/null | grep -q "^yes"; then
  warn "deploy-bot CAN get secrets — consider restricting further"
else
  pass "deploy-bot CANNOT get secrets (least privilege)"
fi

# deploy-bot should have some deployment permissions in the namespace
if kubectl auth can-i get deployments \
  --as=system:serviceaccount:"$NAMESPACE":deploy-bot \
  -n "$NAMESPACE" 2>/dev/null | grep -q "^yes"; then
  pass "deploy-bot CAN get deployments in $NAMESPACE (appropriate permission)"
else
  warn "deploy-bot CANNOT get deployments — may need a Role/RoleBinding"
fi

# deploy-bot should NOT have access to other namespaces
if kubectl auth can-i get deployments \
  --as=system:serviceaccount:"$NAMESPACE":deploy-bot \
  -n default 2>/dev/null | grep -q "^yes"; then
  warn "deploy-bot has access to 'default' namespace — consider namespace-scoping"
else
  pass "deploy-bot CANNOT access resources in 'default' namespace"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}======================================================${RESET}"
echo -e "${BOLD}  Boss Fight: The Great Latte Leak — Results${RESET}"
echo -e "${BOLD}======================================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  ============================================${RESET}"
  echo -e "${GREEN}${BOLD}    ALL CHECKS PASSED. BOSS FIGHT COMPLETE.${RESET}"
  echo -e "${GREEN}${BOLD}  ============================================${RESET}"
  echo ""
  echo "  It's 8:34 AM. The dashboard is green."
  echo ""
  echo "  Sarah says: \"Five fires. One engineer. Zero hand-holding."
  echo "  You triaged, diagnosed, and fixed every single one."
  echo "  Dave just landed and everything is green."
  echo "  Marcus's demo went perfectly."
  echo ""
  echo "  Welcome to the team — for real this time.\""
  echo ""
  echo "  @dave: 'incredible work. going to get a coffee.'"
  echo ""
  echo "  ================================================"
  echo "  WORLD 4: KUBERNETES PRODUCTION — COMPLETE"
  echo "  ================================================"
  echo ""
  echo "  Next: World 5 — Platform Engineering"
  echo "  (Observability, Delivery, Incident Response)"
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Sarah says: \"Not done yet. Check the failing items above."
  echo "  Use 'kubectl describe' and 'kubectl logs' to investigate."
  echo "  Run this script again after each fix.\""
  echo ""
  echo "  Re-read: curriculum/world-4-kubernetes-production/boss-great-latte-leak/challenges/01-great-latte-leak.md"
  exit 1
fi
