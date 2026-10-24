#!/usr/bin/env bash
# =============================================================================
# Chapter 15 Verification Script: The Lockdown
# =============================================================================
# Checks all three challenges:
#   Challenge 1 — RBAC Lockdown
#   Challenge 2 — Harden Pods
#   Challenge 3 — Secret Hygiene
# =============================================================================

set -uo pipefail

NAMESPACE="learn-ch15"
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
# Challenge 1: RBAC Lockdown
# =============================================================================
section "Challenge 1: RBAC Lockdown"

# Check 1a: ServiceAccount exists
if kubectl get serviceaccount pod-reader -n "$NAMESPACE" &>/dev/null; then
  pass "ServiceAccount 'pod-reader' exists"
else
  fail "ServiceAccount 'pod-reader' not found in namespace '$NAMESPACE'"
fi

# Check 1b: Role exists
if kubectl get role pod-reader-role -n "$NAMESPACE" &>/dev/null; then
  pass "Role 'pod-reader-role' exists"
else
  fail "Role 'pod-reader-role' not found"
fi

# Check 1c: RoleBinding exists
if kubectl get rolebinding pod-reader-binding -n "$NAMESPACE" &>/dev/null; then
  pass "RoleBinding 'pod-reader-binding' exists"
else
  fail "RoleBinding 'pod-reader-binding' not found"
fi

# Check 1d: pod-reader CAN get pods
CAN_GET=$(kubectl auth can-i get pods \
  --as=system:serviceaccount:"$NAMESPACE":pod-reader \
  -n "$NAMESPACE" 2>/dev/null || echo "no")
if [ "$CAN_GET" = "yes" ]; then
  pass "pod-reader CAN get pods in $NAMESPACE"
else
  fail "pod-reader CANNOT get pods in $NAMESPACE — check Role and RoleBinding"
fi

# Check 1e: pod-reader CAN list pods
CAN_LIST=$(kubectl auth can-i list pods \
  --as=system:serviceaccount:"$NAMESPACE":pod-reader \
  -n "$NAMESPACE" 2>/dev/null || echo "no")
if [ "$CAN_LIST" = "yes" ]; then
  pass "pod-reader CAN list pods in $NAMESPACE"
else
  fail "pod-reader CANNOT list pods in $NAMESPACE"
fi

# Check 1f: pod-reader CANNOT create pods
CAN_CREATE=$(kubectl auth can-i create pods \
  --as=system:serviceaccount:"$NAMESPACE":pod-reader \
  -n "$NAMESPACE" 2>/dev/null || echo "no")
if [ "$CAN_CREATE" = "no" ]; then
  pass "pod-reader CANNOT create pods (least privilege)"
else
  fail "pod-reader CAN create pods — too permissive"
fi

# Check 1g: pod-reader CANNOT get secrets
CAN_SECRETS=$(kubectl auth can-i get secrets \
  --as=system:serviceaccount:"$NAMESPACE":pod-reader \
  -n "$NAMESPACE" 2>/dev/null || echo "no")
if [ "$CAN_SECRETS" = "no" ]; then
  pass "pod-reader CANNOT get secrets (least privilege)"
else
  fail "pod-reader CAN get secrets — too permissive"
fi

# Check 1h: pod-reader CANNOT get pods in default namespace
CAN_DEFAULT=$(kubectl auth can-i get pods \
  --as=system:serviceaccount:"$NAMESPACE":pod-reader \
  -n default 2>/dev/null || echo "no")
if [ "$CAN_DEFAULT" = "no" ]; then
  pass "pod-reader CANNOT access pods in 'default' namespace (namespace-scoped)"
else
  fail "pod-reader CAN access pods in 'default' namespace — binding is too broad"
fi

# =============================================================================
# Challenge 2: Harden Pods
# =============================================================================
section "Challenge 2: Harden Pods"

# Check 2a: learn-web deployment exists
if kubectl get deployment learn-web -n "$NAMESPACE" &>/dev/null; then
  pass "learn-web Deployment exists"
else
  fail "learn-web Deployment not found"
fi

# Check 2b: runAsNonRoot is set
RUN_AS_NON_ROOT=$(kubectl get deployment learn-web -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null || echo "")
if [ "$RUN_AS_NON_ROOT" = "true" ]; then
  pass "runAsNonRoot is true"
else
  fail "runAsNonRoot is not set to true"
fi

# Check 2c: readOnlyRootFilesystem is set
READ_ONLY=$(kubectl get deployment learn-web -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null || echo "")
if [ "$READ_ONLY" = "true" ]; then
  pass "readOnlyRootFilesystem is true"
else
  fail "readOnlyRootFilesystem is not set to true"
fi

# Check 2d: allowPrivilegeEscalation is false
PRIV_ESC=$(kubectl get deployment learn-web -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null || echo "")
if [ "$PRIV_ESC" = "false" ]; then
  pass "allowPrivilegeEscalation is false"
else
  fail "allowPrivilegeEscalation is not set to false"
fi

# Check 2e: Capabilities drop ALL
CAP_DROP=$(kubectl get deployment learn-web -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop}' 2>/dev/null || echo "")
if echo "$CAP_DROP" | grep -qi "ALL"; then
  pass "Capabilities drop includes ALL"
else
  fail "Capabilities do not drop ALL — current: '$CAP_DROP'"
fi

# Check 2f: Pod is running
WEB_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app=learn-web \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$WEB_RUNNING" -ge 1 ]; then
  pass "learn-web has $WEB_RUNNING Running pod(s) (app works with hardened security)"
else
  fail "learn-web has no Running pods — security context may have broken the app"
fi

# =============================================================================
# Challenge 3: Secret Hygiene
# =============================================================================
section "Challenge 3: Secret Hygiene"

# Check 3a: ConfigMap does not contain credentials
if kubectl get configmap app-config -n "$NAMESPACE" &>/dev/null; then
  CONFIG_HAS_CREDS=$(kubectl get configmap app-config -n "$NAMESPACE" -o yaml 2>/dev/null \
    | grep -cE "DB_PASSWORD|DB_USER" || true)
  if [ "$CONFIG_HAS_CREDS" -eq 0 ]; then
    pass "app-config ConfigMap does not contain DB_PASSWORD or DB_USER"
  else
    fail "app-config ConfigMap still contains sensitive credentials"
  fi
else
  warn "app-config ConfigMap not found"
fi

# Check 3b: Secret db-credentials exists
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

# Check 3c: learn-app mounts the secret as a volume (not env)
APP_VOLUMES=$(kubectl get deployment learn-app -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.volumes}' 2>/dev/null || echo "")
APP_MOUNTS=$(kubectl get deployment learn-app -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts}' 2>/dev/null || echo "")
if echo "$APP_VOLUMES" | grep -q "db-credentials" && echo "$APP_MOUNTS" | grep -q "secrets"; then
  pass "learn-app mounts db-credentials Secret as a volume"
else
  fail "learn-app does not mount the Secret as a volume at /etc/secrets/"
fi

# Check 3d: NetworkPolicy exists
NP_COUNT=$(kubectl get networkpolicy -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NP_COUNT" -ge 1 ]; then
  pass "At least one NetworkPolicy exists in $NAMESPACE"

  # Check if a policy targets the database
  DB_POLICY=$(kubectl get networkpolicy -n "$NAMESPACE" -o yaml 2>/dev/null \
    | grep -c "learn-db" || true)
  if [ "$DB_POLICY" -ge 1 ]; then
    pass "A NetworkPolicy targets or references learn-db"
  else
    warn "No NetworkPolicy seems to target learn-db specifically"
  fi
else
  fail "No NetworkPolicies found in $NAMESPACE"
fi

# =============================================================================
# Summary
# =============================================================================
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BOLD}=============================================${RESET}"
echo -e "${BOLD}  Chapter 15 Verification Results${RESET}"
echo -e "${BOLD}=============================================${RESET}"
echo -e "  Passed:   ${GREEN}$PASS${RESET}"
echo -e "  Failed:   ${RED}$FAIL${RESET}"
if [ "$WARNINGS" -gt 0 ]; then
  echo -e "  Warnings: ${YELLOW}$WARNINGS${RESET}"
fi
echo -e "  Total:    $TOTAL checks"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed. Chapter 15 complete.${RESET}"
  echo ""
  echo "  Sarah says: \"RBAC locked down, pods hardened, secrets managed,"
  echo "  network isolated. The security auditor is going to be impressed."
  echo "  More importantly, a compromised pod now has minimal blast radius."
  echo "  That's how you run a secure cluster.\""
  echo ""
  echo "  Take the quiz: curriculum/world-4-kubernetes-production/ch15-k8s-security/quiz.md"
  exit 0
else
  echo -e "${RED}${BOLD}$FAIL check(s) failed.${RESET}"
  echo ""
  echo "  Re-read the challenge file for the failing section."
  echo "  Use 'kubectl auth can-i' and 'kubectl describe' to investigate."
  echo "  Run this script again after making your fix."
  exit 1
fi
