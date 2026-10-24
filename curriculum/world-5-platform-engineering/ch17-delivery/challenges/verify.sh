#!/usr/bin/env bash
# =============================================================================
# Chapter 17 Verification Script: The Pipeline — Delivery
# =============================================================================
# Checks all three challenges:
#   Challenge 1 — Tag Strategy
#   Challenge 2 — Helm Deploy
#   Challenge 3 — GitOps Simulation
# =============================================================================

set -uo pipefail

NAMESPACE="learn-ch17"
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
  fail "Namespace '$NAMESPACE' does not exist — run 'kubectl create namespace $NAMESPACE'"
  exit 1
fi
pass "Namespace '$NAMESPACE' exists"

# =============================================================================
# Challenge 1: Tag Strategy
# =============================================================================
section "Challenge 1: Tag Strategy"

# Check 1a: Local registry is running
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "learn-registry"; then
  pass "Local registry container 'learn-registry' is running"
else
  warn "Local registry 'learn-registry' not found — may have used kind load instead"
fi

# Check 1b: Deployment exists
if kubectl get deployment learn-nocappuccino-api -n "$NAMESPACE" &>/dev/null; then
  pass "learn-nocappuccino-api Deployment exists"

  # Check 1c: Image tag is not 'latest'
  IMAGE_TAG=$(kubectl get deployment learn-nocappuccino-api -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
  if [ -n "$IMAGE_TAG" ]; then
    if echo "$IMAGE_TAG" | grep -q ":latest$"; then
      fail "Image tag is 'latest' — use a git SHA or semver tag instead"
    elif echo "$IMAGE_TAG" | grep -qE ":[a-f0-9]+$|:[0-9]+\.[0-9]+\.[0-9]"; then
      pass "Image uses specific tag: $IMAGE_TAG"
    else
      warn "Image tag is '$IMAGE_TAG' — verify it's a git SHA or semver"
    fi
  else
    fail "Could not read image from Deployment"
  fi

  # Check 1d: Replicas are running
  AVAILABLE=$(kubectl get deployment learn-nocappuccino-api -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  if [ "${AVAILABLE:-0}" -ge 1 ]; then
    pass "learn-nocappuccino-api has $AVAILABLE available replica(s)"
  else
    fail "learn-nocappuccino-api has no available replicas"
  fi
else
  fail "learn-nocappuccino-api Deployment not found in $NAMESPACE"
fi

# Check 1e: Service exists
if kubectl get service learn-nocappuccino-api -n "$NAMESPACE" &>/dev/null; then
  pass "learn-nocappuccino-api Service exists"
else
  fail "learn-nocappuccino-api Service not found"
fi

# =============================================================================
# Challenge 2: Helm Deploy
# =============================================================================
section "Challenge 2: Helm Deploy"

# Check 2a: Helm release learn-api-dev exists
if helm status learn-api-dev -n "$NAMESPACE" &>/dev/null; then
  pass "Helm release 'learn-api-dev' exists"

  # Check replicas for dev
  DEV_REPLICAS=$(kubectl get deployment -n "$NAMESPACE" \
    -l "app.kubernetes.io/instance=learn-api-dev" \
    -o jsonpath='{.items[0].spec.replicas}' 2>/dev/null || echo "")
  if [ -z "$DEV_REPLICAS" ]; then
    # Try with fullnameOverride
    DEV_REPLICAS=$(kubectl get deployment learn-api-dev -n "$NAMESPACE" \
      -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
  fi
  if [ "$DEV_REPLICAS" = "1" ]; then
    pass "Dev release has 1 replica"
  else
    warn "Dev release has '$DEV_REPLICAS' replicas — expected 1"
  fi
else
  fail "Helm release 'learn-api-dev' not found — run: helm install learn-api-dev ..."
fi

# Check 2b: Helm release learn-api-staging exists
if helm status learn-api-staging -n "$NAMESPACE" &>/dev/null; then
  pass "Helm release 'learn-api-staging' exists"

  # Check replicas for staging
  STAGING_REPLICAS=$(kubectl get deployment -n "$NAMESPACE" \
    -l "app.kubernetes.io/instance=learn-api-staging" \
    -o jsonpath='{.items[0].spec.replicas}' 2>/dev/null || echo "")
  if [ -z "$STAGING_REPLICAS" ]; then
    STAGING_REPLICAS=$(kubectl get deployment learn-api-staging -n "$NAMESPACE" \
      -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
  fi
  if [ "$STAGING_REPLICAS" = "2" ]; then
    pass "Staging release has 2 replicas"
  else
    warn "Staging release has '$STAGING_REPLICAS' replicas — expected 2"
  fi

  # Check 2c: Release history has multiple revisions
  REVISION_COUNT=$(helm history learn-api-staging -n "$NAMESPACE" --max 10 2>/dev/null \
    | tail -n +2 | wc -l | tr -d ' ')
  if [ "$REVISION_COUNT" -ge 2 ]; then
    pass "Staging release has $REVISION_COUNT revisions (upgrade/rollback performed)"
  else
    warn "Staging release has only $REVISION_COUNT revision — expected at least 2 (upgrade + rollback)"
  fi
else
  fail "Helm release 'learn-api-staging' not found — run: helm install learn-api-staging ..."
fi

# =============================================================================
# Challenge 3: GitOps Simulation
# =============================================================================
section "Challenge 3: GitOps Simulation"

# Check 3a: GitOps deployment exists
if kubectl get deployment learn-gitops-api -n "$NAMESPACE" &>/dev/null; then
  pass "learn-gitops-api Deployment exists"

  # Check 3b: Has gitops label
  MANAGED_BY=$(kubectl get deployment learn-gitops-api -n "$NAMESPACE" \
    -o jsonpath='{.metadata.labels.managed-by}' 2>/dev/null || echo "")
  if [ "$MANAGED_BY" = "gitops" ]; then
    pass "Deployment has 'managed-by: gitops' label"
  else
    warn "Deployment missing 'managed-by: gitops' label (found: '$MANAGED_BY')"
  fi

  # Check 3c: Replicas are 3 (post-scale state)
  GITOPS_REPLICAS=$(kubectl get deployment learn-gitops-api -n "$NAMESPACE" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
  if [ "$GITOPS_REPLICAS" = "3" ]; then
    pass "GitOps deployment has 3 replicas (scaled state)"
  else
    warn "GitOps deployment has $GITOPS_REPLICAS replicas — expected 3 (post-scale)"
  fi

  # Check 3d: Image is valid (not the broken one)
  GITOPS_IMAGE=$(kubectl get deployment learn-gitops-api -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
  if echo "$GITOPS_IMAGE" | grep -q "does-not-exist"; then
    fail "GitOps deployment still has broken image: $GITOPS_IMAGE — git revert and re-apply"
  elif [ -n "$GITOPS_IMAGE" ]; then
    pass "GitOps deployment image is valid: $GITOPS_IMAGE"
  else
    fail "Could not read image from GitOps deployment"
  fi

  # Check 3e: Pods are healthy (not in ImagePullBackOff)
  BAD_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=learn-gitops-api --no-headers 2>/dev/null \
    | grep -cE "ImagePullBackOff|ErrImagePull" || true)
  if [ "$BAD_PODS" -eq 0 ]; then
    pass "No GitOps pods in ImagePullBackOff or ErrImagePull"
  else
    fail "$BAD_PODS GitOps pod(s) in bad image state — complete the git revert step"
  fi
else
  fail "learn-gitops-api Deployment not found — complete Challenge 3"
fi

# Check 3f: Audit ConfigMap exists
if kubectl get configmap learn-gitops-audit -n "$NAMESPACE" &>/dev/null; then
  pass "ConfigMap 'learn-gitops-audit' exists"

  STRATEGY=$(kubectl get configmap learn-gitops-audit -n "$NAMESPACE" \
    -o jsonpath='{.data.strategy}' 2>/dev/null || echo "")
  if echo "$STRATEGY" | grep -qi "gitops"; then
    pass "Audit ConfigMap records GitOps strategy"
  else
    warn "Audit ConfigMap strategy is '$STRATEGY' — expected 'gitops'"
  fi
else
  fail "ConfigMap 'learn-gitops-audit' not found"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}=============================================${RESET}"
echo -e "${BOLD}  Chapter 17 Verification Results${RESET}"
echo -e "${BOLD}=============================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed. Chapter 17 complete.${RESET}"
  echo ""
  echo "  Sarah says: \"Proper tags, Helm releases with rollback, and"
  echo "  GitOps-style deployments with a full audit trail. Dave's laptop"
  echo "  deployment days are over. Every change goes through Git, gets"
  echo "  reviewed, and can be rolled back in seconds.\""
  echo ""
  echo "  Take the quiz: curriculum/world-5-platform-engineering/ch17-delivery/quiz.md"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Re-read the challenge files for the failing section."
  echo "  Run this script again after making your fixes."
  exit 1
fi
