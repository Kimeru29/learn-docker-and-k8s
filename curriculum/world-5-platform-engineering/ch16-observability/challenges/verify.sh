#!/usr/bin/env bash
# =============================================================================
# Chapter 16 Verification Script: The Glass Roaster — Observability
# =============================================================================
# Checks all three challenges:
#   Challenge 1 — Diagnose with Metrics
#   Challenge 2 — Trace the Request
#   Challenge 3 — Build a Dashboard
# =============================================================================

set -uo pipefail

NAMESPACE="learn-ch16"
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
# Challenge 1: Diagnose with Metrics
# =============================================================================
section "Challenge 1: Diagnose with Metrics"

# Check 1a: Prometheus is deployed
PROM_PODS=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=prometheus" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PROM_PODS" -ge 1 ]; then
  pass "Prometheus is deployed ($PROM_PODS pod(s))"
else
  # Also check for kube-prometheus-stack naming
  PROM_PODS_ALT=$(kubectl get pods -n "$NAMESPACE" -l "app=prometheus" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  PROM_PODS_STACK=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "prometheus" || true)
  if [ "$PROM_PODS_ALT" -ge 1 ] || [ "$PROM_PODS_STACK" -ge 1 ]; then
    pass "Prometheus is deployed"
  else
    fail "Prometheus not found in namespace '$NAMESPACE' — install kube-prometheus-stack via Helm"
  fi
fi

# Check 1b: Grafana is deployed
GRAFANA_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "grafana" || true)
if [ "$GRAFANA_PODS" -ge 1 ]; then
  pass "Grafana is deployed ($GRAFANA_PODS pod(s))"
else
  fail "Grafana not found in namespace '$NAMESPACE'"
fi

# Check 1c: Recommendation API deployment exists and is running
if kubectl get deployment learn-recommendation-api -n "$NAMESPACE" &>/dev/null; then
  pass "learn-recommendation-api Deployment exists"

  API_AVAILABLE=$(kubectl get deployment learn-recommendation-api -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  API_DESIRED=$(kubectl get deployment learn-recommendation-api -n "$NAMESPACE" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
  if [ "${API_AVAILABLE:-0}" -ge 1 ]; then
    pass "learn-recommendation-api has $API_AVAILABLE/$API_DESIRED available replicas"
  else
    fail "learn-recommendation-api has no available replicas"
  fi
else
  fail "learn-recommendation-api Deployment not found"
fi

# Check 1d: Diagnosis ConfigMap exists
if kubectl get configmap learn-diagnosis -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-diagnosis' exists"

  # Check it has the expected keys
  DIAG_FINDING=$(kubectl get configmap learn-diagnosis -n "$NAMESPACE" \
    -o jsonpath='{.data.finding}' 2>/dev/null || echo "")
  if [ -n "$DIAG_FINDING" ]; then
    pass "learn-diagnosis contains 'finding' key"
  else
    fail "learn-diagnosis missing 'finding' key"
  fi

  DIAG_METHOD=$(kubectl get configmap learn-diagnosis -n "$NAMESPACE" \
    -o jsonpath='{.data.method}' 2>/dev/null || echo "")
  if [ -n "$DIAG_METHOD" ]; then
    pass "learn-diagnosis contains 'method' key (value: $DIAG_METHOD)"
  else
    fail "learn-diagnosis missing 'method' key"
  fi

  DIAG_MISSING=$(kubectl get configmap learn-diagnosis -n "$NAMESPACE" \
    -o jsonpath='{.data.missing_metric}' 2>/dev/null || echo "")
  if [ -n "$DIAG_MISSING" ]; then
    pass "learn-diagnosis contains 'missing_metric' key"
  else
    fail "learn-diagnosis missing 'missing_metric' key"
  fi
else
  fail "ConfigMap 'learn-diagnosis' not found — create it with your findings"
fi

# =============================================================================
# Challenge 2: Trace the Request
# =============================================================================
section "Challenge 2: Trace the Request"

if kubectl get configmap learn-trace-analysis -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-trace-analysis' exists"

  # Check bottleneck service
  BOTTLENECK_SVC=$(kubectl get configmap learn-trace-analysis -n "$NAMESPACE" \
    -o jsonpath='{.data.bottleneck_service}' 2>/dev/null || echo "")
  if echo "$BOTTLENECK_SVC" | grep -qi "user-preferences"; then
    pass "Correctly identified bottleneck service: $BOTTLENECK_SVC"
  else
    fail "Bottleneck service is '$BOTTLENECK_SVC' — expected 'user-preferences'"
  fi

  # Check bottleneck span
  BOTTLENECK_SPAN=$(kubectl get configmap learn-trace-analysis -n "$NAMESPACE" \
    -o jsonpath='{.data.bottleneck_span}' 2>/dev/null || echo "")
  if echo "$BOTTLENECK_SPAN" | grep -qiE "ml.model|score|inference"; then
    pass "Correctly identified bottleneck span: $BOTTLENECK_SPAN"
  else
    fail "Bottleneck span is '$BOTTLENECK_SPAN' — expected reference to ml-model/score-preferences/inference"
  fi

  # Check bottleneck duration
  BOTTLENECK_MS=$(kubectl get configmap learn-trace-analysis -n "$NAMESPACE" \
    -o jsonpath='{.data.bottleneck_duration_ms}' 2>/dev/null || echo "0")
  if [ -n "$BOTTLENECK_MS" ] && [ "$BOTTLENECK_MS" -ge 1680 ] 2>/dev/null && [ "$BOTTLENECK_MS" -le 1880 ] 2>/dev/null; then
    pass "Bottleneck duration is ${BOTTLENECK_MS}ms (within expected range 1680-1880ms)"
  else
    fail "Bottleneck duration is '${BOTTLENECK_MS}ms' — expected ~1780ms (range: 1680-1880)"
  fi

  # Check recommendation
  RECOMMENDATION=$(kubectl get configmap learn-trace-analysis -n "$NAMESPACE" \
    -o jsonpath='{.data.recommendation}' 2>/dev/null || echo "")
  if [ -n "$RECOMMENDATION" ]; then
    pass "Recommendation provided: '${RECOMMENDATION:0:80}...'"
  else
    fail "No recommendation provided"
  fi
else
  fail "ConfigMap 'learn-trace-analysis' not found — create it with your trace analysis"
fi

# =============================================================================
# Challenge 3: Build a Dashboard
# =============================================================================
section "Challenge 3: Build a Dashboard"

if kubectl get configmap learn-dashboard -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-dashboard' exists"

  # Check dashboard name
  DASH_NAME=$(kubectl get configmap learn-dashboard -n "$NAMESPACE" \
    -o jsonpath='{.data.dashboard_name}' 2>/dev/null || echo "")
  if [ -n "$DASH_NAME" ]; then
    pass "Dashboard name: '$DASH_NAME'"
  else
    # Might be a JSON export instead
    DASH_JSON=$(kubectl get configmap learn-dashboard -n "$NAMESPACE" \
      -o jsonpath='{.data.dashboard\.json}' 2>/dev/null || echo "")
    if [ -n "$DASH_JSON" ]; then
      pass "Dashboard JSON export found"
    else
      warn "Dashboard name not found — expected 'dashboard_name' key or 'dashboard.json' file"
    fi
  fi

  # Check required panels
  PANEL_COUNT=0
  for key in panel_1 panel_2 panel_3 panel_4 panel_5 panel_6; do
    VALUE=$(kubectl get configmap learn-dashboard -n "$NAMESPACE" \
      -o jsonpath="{.data.$key}" 2>/dev/null || echo "")
    if [ -n "$VALUE" ]; then
      PANEL_COUNT=$((PANEL_COUNT + 1))
    fi
  done

  if [ "$PANEL_COUNT" -ge 6 ]; then
    pass "All 6 dashboard panels defined"
  elif [ "$PANEL_COUNT" -ge 4 ]; then
    warn "$PANEL_COUNT/6 panels defined — add the remaining panels"
  elif [ "$PANEL_COUNT" -ge 1 ]; then
    fail "Only $PANEL_COUNT/6 panels defined"
  else
    # Check if it's a JSON dashboard instead
    DASH_JSON=$(kubectl get configmap learn-dashboard -n "$NAMESPACE" \
      -o jsonpath='{.data}' 2>/dev/null || echo "")
    if echo "$DASH_JSON" | grep -q "dashboard.json"; then
      pass "Dashboard provided as JSON export"
    else
      fail "No dashboard panels found in learn-dashboard ConfigMap"
    fi
  fi
else
  fail "ConfigMap 'learn-dashboard' not found — create it with your dashboard definition"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}=============================================${RESET}"
echo -e "${BOLD}  Chapter 16 Verification Results${RESET}"
echo -e "${BOLD}=============================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed. Chapter 16 complete.${RESET}"
  echo ""
  echo "  Sarah says: \"You can see inside the system now. Logs, metrics,"
  echo "  traces, dashboards — these aren't just tools. They're your eyes."
  echo "  Next time the dashboard says 'green' and customers say 'slow,'"
  echo "  you'll know exactly where to look.\""
  echo ""
  echo "  Take the quiz: curriculum/world-5-platform-engineering/ch16-observability/quiz.md"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Re-read the challenge files for the failing section."
  echo "  Run this script again after making your fixes."
  exit 1
fi
