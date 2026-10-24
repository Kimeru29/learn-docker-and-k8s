#!/usr/bin/env bash
# =============================================================================
# Chapter 13 Verification Script: The Resilient Brew
# =============================================================================
# Checks all three challenges:
#   Challenge 1 — Probe Diagnosis
#   Challenge 2 — Zero-Downtime Update
#   Challenge 3 — Graceful Shutdown
# =============================================================================

set -uo pipefail

NAMESPACE="learn-ch13"
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
  fail "Namespace '$NAMESPACE' does not exist — run the challenge setup first"
  exit 1
fi
pass "Namespace '$NAMESPACE' exists"

# =============================================================================
# Challenge 1: Probe Diagnosis
# =============================================================================
section "Challenge 1: Probe Diagnosis"

# Check 1a: learn-api deployment exists
if kubectl get deployment learn-api -n "$NAMESPACE" &>/dev/null; then
  pass "learn-api Deployment exists"
else
  fail "learn-api Deployment not found"
fi

# Check 1b: learn-api has a readiness probe
READINESS_PROBE=$(kubectl get deployment learn-api -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
if [ -n "$READINESS_PROBE" ] && [ "$READINESS_PROBE" != "null" ]; then
  pass "learn-api has a readiness probe configured"
else
  fail "learn-api has no readiness probe — traffic goes to broken pods"
fi

# Check 1c: learn-api has running pods
API_RUNNING=$(kubectl get pods -n "$NAMESPACE" \
  -l app=learn-api \
  --field-selector=status.phase=Running \
  --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$API_RUNNING" -ge 1 ]; then
  pass "learn-api has $API_RUNNING Running pod(s)"
else
  fail "learn-api has no Running pods"
fi

# Check 1d: Endpoints only list ready pods (not all pods)
ENDPOINT_COUNT=$(kubectl get endpoints learn-api -n "$NAMESPACE" \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -c "ip" || true)
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=learn-api --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$ENDPOINT_COUNT" -ge 1 ]; then
  pass "learn-api Service has $ENDPOINT_COUNT endpoint(s)"
  if [ "$ENDPOINT_COUNT" -lt "$TOTAL_PODS" ] 2>/dev/null; then
    pass "Endpoints filtered — not all pods are in endpoints (probes working)"
  fi
else
  warn "learn-api Service has no endpoints — check if any pods are healthy"
fi

# Check 1e: Bonus — liveness probe
LIVENESS_PROBE=$(kubectl get deployment learn-api -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' 2>/dev/null || echo "")
if [ -n "$LIVENESS_PROBE" ] && [ "$LIVENESS_PROBE" != "null" ]; then
  pass "learn-api has a liveness probe (bonus)"
else
  warn "learn-api has no liveness probe — broken pods won't auto-restart (optional)"
fi

# =============================================================================
# Challenge 2: Zero-Downtime Update
# =============================================================================
section "Challenge 2: Zero-Downtime Update"

# Check 2a: learn-frontend deployment exists
if kubectl get deployment learn-frontend -n "$NAMESPACE" &>/dev/null; then
  pass "learn-frontend Deployment exists"
else
  fail "learn-frontend Deployment not found — run the Challenge 2 setup"
fi

# Check 2b: learn-frontend is running nginx:1.26
FRONTEND_IMAGE=$(kubectl get deployment learn-frontend -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
if [ "$FRONTEND_IMAGE" = "nginx:1.26" ]; then
  pass "learn-frontend is running nginx:1.26"
else
  fail "learn-frontend is running '$FRONTEND_IMAGE' — expected nginx:1.26"
fi

# Check 2c: Rolling update strategy
UPDATE_STRATEGY=$(kubectl get deployment learn-frontend -n "$NAMESPACE" \
  -o jsonpath='{.spec.strategy.type}' 2>/dev/null || echo "")
if [ "$UPDATE_STRATEGY" = "RollingUpdate" ]; then
  pass "learn-frontend uses RollingUpdate strategy"
else
  fail "learn-frontend strategy is '$UPDATE_STRATEGY' — expected RollingUpdate"
fi

MAX_UNAVAILABLE=$(kubectl get deployment learn-frontend -n "$NAMESPACE" \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null || echo "")
if [ "$MAX_UNAVAILABLE" = "0" ]; then
  pass "maxUnavailable is 0 (zero-downtime configured)"
else
  warn "maxUnavailable is '$MAX_UNAVAILABLE' — should be 0 for guaranteed zero downtime"
fi

MAX_SURGE=$(kubectl get deployment learn-frontend -n "$NAMESPACE" \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null || echo "")
if [ -n "$MAX_SURGE" ] && [ "$MAX_SURGE" != "0" ]; then
  pass "maxSurge is set to $MAX_SURGE"
else
  warn "maxSurge is '$MAX_SURGE' — should be >= 1 when maxUnavailable is 0"
fi

# Check 2d: Readiness probe on frontend
FRONTEND_READINESS=$(kubectl get deployment learn-frontend -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
if [ -n "$FRONTEND_READINESS" ] && [ "$FRONTEND_READINESS" != "null" ]; then
  pass "learn-frontend has a readiness probe"
else
  fail "learn-frontend has no readiness probe — zero-downtime updates require one"
fi

# Check 2e: Frontend pods are Running
FRONTEND_RUNNING=$(kubectl get pods -n "$NAMESPACE" \
  -l app=learn-frontend \
  --field-selector=status.phase=Running \
  --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$FRONTEND_RUNNING" -ge 1 ]; then
  pass "learn-frontend has $FRONTEND_RUNNING Running pod(s)"
else
  fail "learn-frontend has no Running pods"
fi

# Check 2f: Rollout history
REVISION_COUNT=$(kubectl rollout history deployment/learn-frontend -n "$NAMESPACE" \
  2>/dev/null | grep -c "^[0-9]" || true)
if [ "$REVISION_COUNT" -ge 2 ]; then
  pass "learn-frontend rollout history has $REVISION_COUNT revisions (update performed)"
else
  warn "learn-frontend rollout history has $REVISION_COUNT revision(s) — expected >= 2"
fi

# =============================================================================
# Challenge 3: Graceful Shutdown
# =============================================================================
section "Challenge 3: Graceful Shutdown"

# Check 3a: learn-worker deployment exists
if kubectl get deployment learn-worker -n "$NAMESPACE" &>/dev/null; then
  pass "learn-worker Deployment exists"
else
  fail "learn-worker Deployment not found — run the Challenge 3 setup"
fi

# Check 3b: terminationGracePeriodSeconds is set and sufficient
GRACE_PERIOD=$(kubectl get deployment learn-worker -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}' 2>/dev/null || echo "")
if [ -n "$GRACE_PERIOD" ] && [ "$GRACE_PERIOD" != "null" ]; then
  if [ "$GRACE_PERIOD" -ge 55 ] 2>/dev/null; then
    pass "terminationGracePeriodSeconds is $GRACE_PERIOD (sufficient for 5s preStop + 45s drain)"
  else
    fail "terminationGracePeriodSeconds is $GRACE_PERIOD — too low for a 5s preStop + 45s drain"
  fi
else
  fail "terminationGracePeriodSeconds is not set (defaults to 30s — too low)"
fi

# Check 3c: preStop hook is configured
PRESTOP_HOOK=$(kubectl get deployment learn-worker -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop}' 2>/dev/null || echo "")
if [ -n "$PRESTOP_HOOK" ] && [ "$PRESTOP_HOOK" != "null" ]; then
  pass "learn-worker has a preStop hook configured"
else
  fail "learn-worker has no preStop hook — endpoint propagation delay not handled"
fi

# Check 3d: Worker pods are Running
WORKER_RUNNING=$(kubectl get pods -n "$NAMESPACE" \
  -l app=learn-worker \
  --field-selector=status.phase=Running \
  --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$WORKER_RUNNING" -ge 1 ]; then
  pass "learn-worker has $WORKER_RUNNING Running pod(s)"
else
  fail "learn-worker has no Running pods"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}=============================================${RESET}"
echo -e "${BOLD}  Chapter 13 Verification Results${RESET}"
echo -e "${BOLD}=============================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed. Chapter 13 complete.${RESET}"
  echo ""
  echo "  Sarah says: \"Health probes, zero-downtime updates, and graceful"
  echo "  shutdown. Your pods don't just run — they run well. They tell"
  echo "  Kubernetes when they're ready, they update without dropping"
  echo "  requests, and they shut down without losing work.\""
  echo ""
  echo "  Take the quiz: curriculum/world-4-kubernetes-production/ch13-health-reliability/quiz.md"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Re-read the challenge file for the failing section."
  echo "  Use 'kubectl describe' and 'kubectl logs' to investigate."
  echo "  Run this script again after making your fix."
  exit 1
fi
