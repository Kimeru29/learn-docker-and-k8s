#!/usr/bin/env bash
# =============================================================================
# Boss Fight Verification Script: The Full Platform
# =============================================================================
# Checks all six phases of the World 5 boss fight:
#   Phase 1 — Build (image with proper tags)
#   Phase 2 — Deploy (Helm + health probes)
#   Phase 3 — Monitor (Prometheus scraping)
#   Phase 4 — Release (rolling update)
#   Phase 5 — Incident (handled, rolled back)
#   Phase 6 — Document (postmortem)
# =============================================================================

set -uo pipefail

NAMESPACE="learn-boss-w5"
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
  echo -e "${BOLD}=== $1 ===${RESET}"
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
  fail "Namespace '$NAMESPACE' does not exist — run: kubectl create namespace $NAMESPACE"
  exit 1
fi
pass "Namespace '$NAMESPACE' exists"

# =============================================================================
# Phase 1: Build
# =============================================================================
section "Phase 1: Build — Properly Tagged Image"

# Check if Helm release exists (which implies an image was built and deployed)
if helm status learn-boss -n "$NAMESPACE" &>/dev/null; then
  # Check image tag is not 'latest'
  IMAGE=$(kubectl get deployment -n "$NAMESPACE" -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
  if [ -n "$IMAGE" ]; then
    if echo "$IMAGE" | grep -q ":latest$"; then
      fail "Image tag is 'latest' — use git SHA or semver"
    else
      pass "Image has specific tag: $IMAGE"
    fi
  else
    warn "Could not determine image — check Deployment"
  fi
else
  warn "Helm release 'learn-boss' not found — Phases 1-2 may not be complete yet"
fi

# =============================================================================
# Phase 2: Deploy — Helm + Health Probes
# =============================================================================
section "Phase 2: Deploy — Helm Chart with Health Probes"

if helm status learn-boss -n "$NAMESPACE" &>/dev/null; then
  pass "Helm release 'learn-boss' exists"

  # Check deployment exists
  DEPLOY_NAME=$(kubectl get deployment -n "$NAMESPACE" --no-headers -o custom-columns=':metadata.name' 2>/dev/null | head -1)
  if [ -n "$DEPLOY_NAME" ]; then
    pass "Deployment '$DEPLOY_NAME' exists"

    # Check replicas
    AVAILABLE=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    if [ "${AVAILABLE:-0}" -ge 1 ]; then
      pass "Deployment has $AVAILABLE/$DESIRED available replicas"
    else
      fail "Deployment has no available replicas"
    fi

    # Check readiness probe
    READINESS=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' 2>/dev/null || echo "")
    if [ -n "$READINESS" ] && [ "$READINESS" != "null" ]; then
      pass "Readiness probe is configured"
    else
      fail "Readiness probe is NOT configured"
    fi

    # Check liveness probe
    LIVENESS=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' 2>/dev/null || echo "")
    if [ -n "$LIVENESS" ] && [ "$LIVENESS" != "null" ]; then
      pass "Liveness probe is configured"
    else
      fail "Liveness probe is NOT configured"
    fi

    # Check rolling update strategy
    STRATEGY=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.spec.strategy.type}' 2>/dev/null || echo "")
    if [ "$STRATEGY" = "RollingUpdate" ]; then
      pass "RollingUpdate strategy configured"

      MAX_UNAVAIL=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null || echo "")
      if [ "$MAX_UNAVAIL" = "0" ]; then
        pass "maxUnavailable is 0 (zero-downtime)"
      else
        warn "maxUnavailable is '$MAX_UNAVAIL' — expected 0 for zero-downtime"
      fi
    else
      fail "Strategy is '$STRATEGY' — expected RollingUpdate"
    fi

    # Check resource limits
    MEM_LIMIT=$(kubectl get deployment "$DEPLOY_NAME" -n "$NAMESPACE" \
      -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
    if [ -n "$MEM_LIMIT" ]; then
      MEM_VALUE=$(echo "$MEM_LIMIT" | sed 's/[^0-9]//g')
      if [ "$MEM_VALUE" -ge 32 ] 2>/dev/null; then
        pass "Memory limit is $MEM_LIMIT (healthy)"
      else
        fail "Memory limit is $MEM_LIMIT — too low, will OOMKill"
      fi
    else
      fail "No memory limit set"
    fi
  else
    fail "No Deployment found in namespace"
  fi
else
  fail "Helm release 'learn-boss' not found"
fi

# =============================================================================
# Phase 3: Monitor
# =============================================================================
section "Phase 3: Monitor — Observability"

# Check if Prometheus is available somewhere in the cluster
PROM_RUNNING=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null \
  | grep -c "prometheus" || true)
if [ "$PROM_RUNNING" -ge 1 ]; then
  pass "Prometheus is running in the cluster ($PROM_RUNNING pod(s))"
else
  warn "Prometheus not detected — monitoring may not be available"
fi

# =============================================================================
# Phase 4: Release
# =============================================================================
section "Phase 4: Release — Rolling Update"

if helm status learn-boss -n "$NAMESPACE" &>/dev/null; then
  REVISION_COUNT=$(helm history learn-boss -n "$NAMESPACE" --max 20 2>/dev/null \
    | tail -n +2 | wc -l | tr -d ' ')
  if [ "$REVISION_COUNT" -ge 2 ]; then
    pass "Helm release has $REVISION_COUNT revisions (upgrades performed)"
  else
    warn "Helm release has only $REVISION_COUNT revision — complete Phases 4-5"
  fi
fi

# =============================================================================
# Phase 5: Incident — Handled
# =============================================================================
section "Phase 5: Incident — Triage, Mitigate, Recover"

# Check no pods are currently broken
BAD_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
  | grep -cE "CrashLoopBackOff|OOMKilled|ImagePullBackOff|Error" || true)
if [ "$BAD_PODS" -eq 0 ]; then
  pass "No pods in failed state (incident resolved)"
else
  fail "$BAD_PODS pod(s) still in failed state — complete the rollback"
fi

# Check helm history shows a rollback
if helm status learn-boss -n "$NAMESPACE" &>/dev/null; then
  ROLLBACK_COUNT=$(helm history learn-boss -n "$NAMESPACE" --max 20 2>/dev/null \
    | grep -ci "rollback" || true)
  if [ "$ROLLBACK_COUNT" -ge 1 ]; then
    pass "Helm history shows rollback(s) performed"
  else
    # Check for 3+ revisions which implies upgrade then rollback
    if [ "$REVISION_COUNT" -ge 3 ] 2>/dev/null; then
      pass "Helm has $REVISION_COUNT revisions (upgrade + rollback cycle)"
    else
      warn "No rollback detected in helm history — was the incident simulated and resolved?"
    fi
  fi
fi

# =============================================================================
# Phase 6: Document — Postmortem
# =============================================================================
section "Phase 6: Document — Postmortem"

if kubectl get configmap learn-boss-postmortem -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-boss-postmortem' exists"

  POSTMORTEM_SECTIONS=0
  for key in summary severity timeline root_cause action_items lessons_learned; do
    VALUE=$(kubectl get configmap learn-boss-postmortem -n "$NAMESPACE" \
      -o jsonpath="{.data.$key}" 2>/dev/null || echo "")
    if [ -n "$VALUE" ]; then
      POSTMORTEM_SECTIONS=$((POSTMORTEM_SECTIONS + 1))
      pass "Postmortem includes '$key'"
    else
      fail "Postmortem missing '$key'"
    fi
  done
else
  fail "ConfigMap 'learn-boss-postmortem' not found — write the postmortem"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}======================================================${RESET}"
echo -e "${BOLD}  Boss Fight: The Full Platform — Verification Results${RESET}"
echo -e "${BOLD}======================================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║                                                          ║"
  echo "  ║   🏆  WORLD 5 COMPLETE: Platform Engineering             ║"
  echo "  ║                                                          ║"
  echo "  ║   You have completed the entire Learn Docker &           ║"
  echo "  ║   Kubernetes curriculum.                                 ║"
  echo "  ║                                                          ║"
  echo "  ║   From 'docker run hello-world' to a full platform.      ║"
  echo "  ║                                                          ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo ""
  echo "  Sarah says:"
  echo "  \"Look at what you just did. Source code to production. Build"
  echo "  pipeline with proper tags. Helm deployment with health probes."
  echo "  Prometheus monitoring. Rolling update. Incident mid-rollout."
  echo "  Rollback in minutes. Postmortem documented."
  echo ""
  echo "  That's not a tutorial anymore. That's the job."
  echo ""
  echo "  Welcome to platform engineering — for real this time.\""
  echo ""
  echo "  Dave: 'Wait, we have a platform now?'"
  echo "  Marcus: 'Since they built it. While you were getting coffee.'"
  echo "  Sarah: (★‿★)"
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Re-read the challenge phases for the failing section."
  echo "  The boss fight tests everything — take your time."
  echo "  Run this script again after making your fixes."
  exit 1
fi
