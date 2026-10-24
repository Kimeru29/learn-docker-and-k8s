#!/usr/bin/env bash
# =============================================================================
# Chapter 18 Verification Script: The On-Call Shift — Incident Response
# =============================================================================
# Checks all three challenges:
#   Challenge 1 — The 2 AM Page
#   Challenge 2 — Cascading Failure
#   Challenge 3 — Write the Postmortem
# =============================================================================

set -uo pipefail

NAMESPACE="learn-ch18"
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
# Challenge 1: The 2 AM Page
# =============================================================================
section "Challenge 1: The 2 AM Page"

# Check 1a: No pods in ImagePullBackOff
PULL_BACK_OFF=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
  | grep -c "ImagePullBackOff" || true)
if [ "$PULL_BACK_OFF" -eq 0 ]; then
  pass "No pods in ImagePullBackOff state"
else
  fail "Found $PULL_BACK_OFF pod(s) in ImagePullBackOff — fix the image tags"
fi

# Check 1b: No pods in CrashLoopBackOff or OOMKilled
CRASH_LOOP=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
  | grep -cE "CrashLoopBackOff|OOMKilled" || true)
if [ "$CRASH_LOOP" -eq 0 ]; then
  pass "No pods in CrashLoopBackOff or OOMKilled state"
else
  fail "Found $CRASH_LOOP pod(s) in CrashLoopBackOff or OOMKilled"
fi

# Check 1c: learn-api deployment has running pods
if kubectl get deployment learn-api -n "$NAMESPACE" &>/dev/null; then
  API_IMAGE=$(kubectl get deployment learn-api -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
  if echo "$API_IMAGE" | grep -q "nonexistent"; then
    fail "learn-api still has broken image: $API_IMAGE"
  elif [ -n "$API_IMAGE" ]; then
    pass "learn-api has valid image: $API_IMAGE"
  fi

  API_AVAILABLE=$(kubectl get deployment learn-api -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  if [ "${API_AVAILABLE:-0}" -ge 1 ]; then
    pass "learn-api has $API_AVAILABLE available replica(s)"
  else
    fail "learn-api has no available replicas"
  fi
else
  warn "learn-api Deployment not found — may not have applied incident-state.yaml yet"
fi

# Check 1d: learn-worker has reasonable memory limits
if kubectl get deployment learn-worker -n "$NAMESPACE" &>/dev/null; then
  WORKER_MEM=$(kubectl get deployment learn-worker -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' \
    2>/dev/null || echo "")
  if [ -n "$WORKER_MEM" ]; then
    MEM_VALUE=$(echo "$WORKER_MEM" | sed 's/[^0-9]//g')
    MEM_UNIT=$(echo "$WORKER_MEM" | sed 's/[0-9]//g')
    if [[ "$MEM_UNIT" == "Gi" ]]; then
      MEM_MI=$((MEM_VALUE * 1024))
    else
      MEM_MI=$MEM_VALUE
    fi

    if [ "$MEM_MI" -ge 32 ]; then
      pass "learn-worker memory limit is $WORKER_MEM (sufficient)"
    else
      fail "learn-worker memory limit is $WORKER_MEM — too low (minimum 32Mi)"
    fi
  else
    fail "learn-worker has no memory limit set"
  fi

  WORKER_AVAILABLE=$(kubectl get deployment learn-worker -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  if [ "${WORKER_AVAILABLE:-0}" -ge 1 ]; then
    pass "learn-worker has $WORKER_AVAILABLE available replica(s)"
  else
    fail "learn-worker has no available replicas — still OOMKilled?"
  fi
else
  warn "learn-worker Deployment not found"
fi

# Check 1e: Incident report ConfigMap
if kubectl get configmap learn-incident-report -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-incident-report' exists"

  # Check required keys
  for key in severity impact root_cause mitigation; do
    VALUE=$(kubectl get configmap learn-incident-report -n "$NAMESPACE" \
      -o jsonpath="{.data.$key}" 2>/dev/null || echo "")
    if [ -n "$VALUE" ]; then
      pass "Incident report has '$key' field"
    else
      fail "Incident report missing '$key' field"
    fi
  done
else
  fail "ConfigMap 'learn-incident-report' not found — document your incident"
fi

# =============================================================================
# Challenge 2: Cascading Failure
# =============================================================================
section "Challenge 2: Cascading Failure"

# Check 2a: learn-db is running with valid image
if kubectl get deployment learn-db -n "$NAMESPACE" &>/dev/null; then
  DB_IMAGE=$(kubectl get deployment learn-db -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
  if echo "$DB_IMAGE" | grep -q "nonexistent"; then
    fail "learn-db still has broken image: $DB_IMAGE — fix the database first"
  elif [ -n "$DB_IMAGE" ]; then
    pass "learn-db has valid image: $DB_IMAGE"
  fi

  DB_AVAILABLE=$(kubectl get deployment learn-db -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  if [ "${DB_AVAILABLE:-0}" -ge 1 ]; then
    pass "learn-db has $DB_AVAILABLE available replica(s)"
  else
    fail "learn-db has no available replicas"
  fi
else
  warn "learn-db Deployment not found — apply cascade-state.yaml first"
fi

# Check 2b: learn-backend is running
if kubectl get deployment learn-backend -n "$NAMESPACE" &>/dev/null; then
  BACKEND_AVAILABLE=$(kubectl get deployment learn-backend -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  if [ "${BACKEND_AVAILABLE:-0}" -ge 1 ]; then
    pass "learn-backend has $BACKEND_AVAILABLE available replica(s)"
  else
    fail "learn-backend has no available replicas"
  fi
else
  warn "learn-backend Deployment not found"
fi

# Check 2c: learn-frontend is running
if kubectl get deployment learn-frontend -n "$NAMESPACE" &>/dev/null; then
  FRONTEND_AVAILABLE=$(kubectl get deployment learn-frontend -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  if [ "${FRONTEND_AVAILABLE:-0}" -ge 1 ]; then
    pass "learn-frontend has $FRONTEND_AVAILABLE available replica(s)"
  else
    fail "learn-frontend has no available replicas"
  fi
else
  warn "learn-frontend Deployment not found"
fi

# Check 2d: Cascade analysis ConfigMap
if kubectl get configmap learn-cascade-analysis -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-cascade-analysis' exists"

  CASCADE_PATH=$(kubectl get configmap learn-cascade-analysis -n "$NAMESPACE" \
    -o jsonpath='{.data.cascade_path}' 2>/dev/null || echo "")
  if [ -n "$CASCADE_PATH" ]; then
    pass "Cascade analysis includes cascade path: '$CASCADE_PATH'"
  else
    fail "Cascade analysis missing 'cascade_path'"
  fi

  BACKPRESSURE=$(kubectl get configmap learn-cascade-analysis -n "$NAMESPACE" \
    -o jsonpath='{.data.backpressure_recommendation}' 2>/dev/null || echo "")
  if [ -n "$BACKPRESSURE" ]; then
    pass "Cascade analysis includes backpressure recommendation"
  else
    fail "Cascade analysis missing 'backpressure_recommendation'"
  fi
else
  fail "ConfigMap 'learn-cascade-analysis' not found — document the cascade"
fi

# =============================================================================
# Challenge 3: Write the Postmortem
# =============================================================================
section "Challenge 3: Write the Postmortem"

if kubectl get configmap learn-postmortem -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-postmortem' exists"

  POSTMORTEM_CHECKS=0
  POSTMORTEM_TOTAL=0

  # Check required postmortem sections
  for key in summary severity impact timeline root_cause action_items lessons_learned; do
    POSTMORTEM_TOTAL=$((POSTMORTEM_TOTAL + 1))
    VALUE=$(kubectl get configmap learn-postmortem -n "$NAMESPACE" \
      -o jsonpath="{.data.$key}" 2>/dev/null || echo "")
    if [ -n "$VALUE" ]; then
      POSTMORTEM_CHECKS=$((POSTMORTEM_CHECKS + 1))
      pass "Postmortem includes '$key'"
    else
      fail "Postmortem missing '$key' section"
    fi
  done

  # Check for blameless language
  BLAMELESS=$(kubectl get configmap learn-postmortem -n "$NAMESPACE" \
    -o jsonpath='{.data.blameless}' 2>/dev/null || echo "")
  if [ "$BLAMELESS" = "true" ]; then
    pass "Postmortem is marked as blameless"
  else
    warn "Postmortem not marked as blameless — verify language focuses on systems, not individuals"
  fi

  # Check action items contain multiple items
  ACTION_ITEMS=$(kubectl get configmap learn-postmortem -n "$NAMESPACE" \
    -o jsonpath='{.data.action_items}' 2>/dev/null || echo "")
  ACTION_COUNT=$(echo "$ACTION_ITEMS" | grep -oE '\[P[0-9]\]' | wc -l | tr -d ' ')
  if [ "$ACTION_COUNT" -ge 3 ]; then
    pass "Postmortem has $ACTION_COUNT prioritized action items"
  elif [ "$ACTION_COUNT" -ge 1 ]; then
    warn "Postmortem has $ACTION_COUNT action item(s) — aim for at least 3"
  else
    # Count items by numbering
    ACTION_COUNT_ALT=$(echo "$ACTION_ITEMS" | grep -oE '[0-9]+\.' | wc -l | tr -d ' ')
    if [ "$ACTION_COUNT_ALT" -ge 3 ]; then
      pass "Postmortem has $ACTION_COUNT_ALT action items"
    else
      warn "Could not verify action item count — ensure at least 3 specific items"
    fi
  fi

  # Check contributing factors exist
  FACTORS=$(kubectl get configmap learn-postmortem -n "$NAMESPACE" \
    -o jsonpath='{.data.contributing_factors}' 2>/dev/null || echo "")
  if [ -n "$FACTORS" ]; then
    pass "Postmortem includes contributing factors"
  else
    warn "Postmortem missing 'contributing_factors' — consider adding"
  fi

else
  fail "ConfigMap 'learn-postmortem' not found — write the postmortem"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}=============================================${RESET}"
echo -e "${BOLD}  Chapter 18 Verification Results${RESET}"
echo -e "${BOLD}=============================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed. Chapter 18 complete.${RESET}"
  echo ""
  echo "  Sarah says: \"You just handled incidents, stopped cascading failures,"
  echo "  and wrote a postmortem that will save the next on-call engineer hours"
  echo "  of confusion. The pager will go off again — but now you have a process."
  echo "  And the postmortem? That's how you make sure the same incident only"
  echo "  happens once.\""
  echo ""
  echo "  Take the quiz: curriculum/world-5-platform-engineering/ch18-incident-response/quiz.md"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Re-read the challenge files for the failing section."
  echo "  Run this script again after making your fixes."
  exit 1
fi
