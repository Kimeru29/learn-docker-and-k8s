#!/usr/bin/env bash
# =============================================================================
# Chapter 14 Verification Script: The Resource Budget
# =============================================================================
# Checks all three challenges:
#   Challenge 1 — Fix OOMKilled
#   Challenge 2 — Spread Pods
#   Challenge 3 — Autoscaling
# =============================================================================

set -uo pipefail

NAMESPACE="learn-ch14"
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
# Challenge 1: Fix OOMKilled
# =============================================================================
section "Challenge 1: Fix OOMKilled"

# Check 1a: learn-worker deployment exists
if kubectl get deployment learn-worker -n "$NAMESPACE" &>/dev/null; then
  pass "learn-worker Deployment exists"
else
  fail "learn-worker Deployment not found"
fi

# Check 1b: No OOMKilled or CrashLoopBackOff pods
OOM_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app=learn-worker --no-headers 2>/dev/null \
  | grep -cE "OOMKilled|CrashLoopBackOff" || true)
if [ "$OOM_COUNT" -eq 0 ]; then
  pass "No learn-worker pods in OOMKilled or CrashLoopBackOff state"
else
  fail "Found $OOM_COUNT learn-worker pod(s) in OOMKilled or CrashLoopBackOff"
fi

# Check 1c: Worker pod is Running
WORKER_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app=learn-worker \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$WORKER_RUNNING" -ge 1 ]; then
  pass "learn-worker has $WORKER_RUNNING Running pod(s)"
else
  fail "learn-worker has no Running pods"
fi

# Check 1d: Memory limit is sufficient (>= 32Mi)
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
    fail "Worker memory limit is $WORKER_MEM_LIMIT — too low, OOMKilled will recur"
  fi
else
  fail "Worker memory limit is not set"
fi

# Check 1e: Memory request is set
WORKER_MEM_REQ=$(kubectl get deployment learn-worker -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
if [ -n "$WORKER_MEM_REQ" ] && [ "$WORKER_MEM_REQ" != "null" ]; then
  pass "Worker memory request is set to $WORKER_MEM_REQ"
else
  warn "Worker memory request is not set — pod will be BestEffort for memory"
fi

# =============================================================================
# Challenge 2: Spread Pods
# =============================================================================
section "Challenge 2: Spread Pods"

# Check 2a: learn-api deployment exists
if kubectl get deployment learn-api -n "$NAMESPACE" &>/dev/null; then
  pass "learn-api Deployment exists"
else
  fail "learn-api Deployment not found"
fi

# Check 2b: Topology spread or pod anti-affinity is configured
API_SPEC=$(kubectl get deployment learn-api -n "$NAMESPACE" -o yaml 2>/dev/null)
HAS_TOPO_SPREAD=$(echo "$API_SPEC" | grep -c "topologySpreadConstraints" || true)
HAS_ANTI_AFFINITY=$(echo "$API_SPEC" | grep -c "podAntiAffinity" || true)

if [ "$HAS_TOPO_SPREAD" -ge 1 ] || [ "$HAS_ANTI_AFFINITY" -ge 1 ]; then
  if [ "$HAS_TOPO_SPREAD" -ge 1 ]; then
    pass "learn-api has topologySpreadConstraints configured"
  fi
  if [ "$HAS_ANTI_AFFINITY" -ge 1 ]; then
    pass "learn-api has podAntiAffinity configured"
  fi
else
  fail "learn-api has no topology spread or pod anti-affinity — pods may stack on one node"
fi

# Check 2c: API pods are Running
API_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app=learn-api \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$API_RUNNING" -ge 3 ]; then
  pass "learn-api has $API_RUNNING Running pods"
elif [ "$API_RUNNING" -ge 1 ]; then
  warn "learn-api has $API_RUNNING Running pod(s) — expected 3"
else
  fail "learn-api has no Running pods"
fi

# Check 2d: Pod distribution across nodes
NODE_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app=learn-api -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | sort -u | wc -l | tr -d ' ')
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NODE_COUNT" -gt 1 ]; then
  pass "API pods are distributed across $NODE_COUNT nodes"
elif [ "$TOTAL_NODES" -eq 1 ]; then
  warn "Cluster has only 1 node — distribution check skipped (constraint is configured)"
else
  warn "All API pods are on the same node — constraint may need a rollout restart"
fi

# =============================================================================
# Challenge 3: Autoscaling
# =============================================================================
section "Challenge 3: Autoscaling"

# Check 3a: HPA exists for learn-frontend
HPA_NAME=$(kubectl get hpa -n "$NAMESPACE" --no-headers 2>/dev/null \
  | grep -E "learn-frontend" | awk '{print $1}' | head -1 || true)

if [ -n "$HPA_NAME" ]; then
  pass "HPA for learn-frontend exists (name: $HPA_NAME)"

  # Check 3b: min replicas
  HPA_MIN=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo "")
  if [ "$HPA_MIN" = "2" ]; then
    pass "HPA minReplicas is 2"
  else
    fail "HPA minReplicas is '$HPA_MIN' — expected 2"
  fi

  # Check 3c: max replicas
  HPA_MAX=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || echo "")
  if [ "$HPA_MAX" = "10" ]; then
    pass "HPA maxReplicas is 10"
  else
    fail "HPA maxReplicas is '$HPA_MAX' — expected 10"
  fi

  # Check 3d: CPU target
  HPA_CPU=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}' 2>/dev/null || echo "")
  if [ -n "$HPA_CPU" ]; then
    pass "HPA CPU target is set to $HPA_CPU%"
  else
    HPA_CPU_V1=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.spec.targetCPUUtilizationPercentage}' 2>/dev/null || echo "")
    if [ -n "$HPA_CPU_V1" ]; then
      pass "HPA CPU target is set to $HPA_CPU_V1%"
    else
      fail "HPA has no CPU target metric configured"
    fi
  fi

  # Check 3e: Current replicas
  HPA_CURRENT=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "0")
  if [ "$HPA_CURRENT" -ge 2 ]; then
    pass "HPA current replicas is $HPA_CURRENT (at or above minimum)"
  else
    warn "HPA current replicas is $HPA_CURRENT — may still be initializing"
  fi

  # Check 3f: HPA conditions
  HPA_CONDITIONS=$(kubectl get hpa "$HPA_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.conditions}' 2>/dev/null || echo "")
  if [ -n "$HPA_CONDITIONS" ] && [ "$HPA_CONDITIONS" != "null" ]; then
    pass "HPA has active status conditions"
  else
    warn "HPA conditions not populated — Metrics Server may still be initializing"
  fi

else
  fail "No HPA found targeting learn-frontend in namespace '$NAMESPACE'"
  echo "         Create one with: kubectl autoscale deployment learn-frontend --min=2 --max=10 --cpu-percent=50 -n $NAMESPACE"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}=============================================${RESET}"
echo -e "${BOLD}  Chapter 14 Verification Results${RESET}"
echo -e "${BOLD}=============================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed. Chapter 14 complete.${RESET}"
  echo ""
  echo "  Sarah says: \"Resources managed, pods spread, autoscaling active."
  echo "  Your cluster doesn't just run — it adapts. OOMKilled is a thing"
  echo "  of the past, pods survive node failures, and traffic spikes"
  echo "  handle themselves.\""
  echo ""
  echo "  Take the quiz: curriculum/world-4-kubernetes-production/ch14-scheduling/quiz.md"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Re-read the challenge file for the failing section."
  echo "  Use 'kubectl describe' and 'kubectl top' to investigate."
  echo "  Run this script again after making your fix."
  exit 1
fi
