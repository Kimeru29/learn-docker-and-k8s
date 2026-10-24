#!/bin/bash
# Functional Curriculum Tests
#
# Usage:
#   bash tests/test-functional.sh --docker     # Docker boss fights only
#   bash tests/test-functional.sh --k8s        # Kubernetes boss fights (requires kind)
#   bash tests/test-functional.sh --all        # Everything
#
# Each test:
#   1. Cleans up any previous state
#   2. Sets up the broken/starting state (where applicable)
#   3. Verifies broken state FAILS the verifier (rejection test)
#   4. Applies the known-good solution
#   5. Verifies fixed state PASSES the verifier (acceptance test)
#   6. Cleans up
#
# Exit 0 = all tests passed
# Exit 1 = one or more tests failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOLUTIONS_DIR="$SCRIPT_DIR/solutions/boss-fights"

MODE="${1:---docker}"
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

green()  { printf "\033[0;32m%s\033[0m\n" "$*"; }
red()    { printf "\033[0;31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[0;33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

test_pass() { green "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
test_fail() { red "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
test_skip() { yellow "  SKIP: $1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }

cleanup_docker() {
    # Remove learn-* Docker resources safely
    docker ps -a --filter "label=app=learn-docker-k8s" -q 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
    docker network ls --filter "label=app=learn-docker-k8s" -q 2>/dev/null | xargs -r docker network rm 2>/dev/null || true
    docker volume ls --filter "label=app=learn-docker-k8s" -q 2>/dev/null | xargs -r docker volume rm 2>/dev/null || true
    # Also clean up compose projects
    if docker compose version &>/dev/null; then
        for d in /tmp/learn-boss-w2 /tmp/learn-boss-w5; do
            if [ -f "$d/docker-compose.yml" ]; then
                docker compose -f "$d/docker-compose.yml" down -v 2>/dev/null || true
            fi
        done
    fi
}

cleanup_k8s() {
    if command -v kubectl &>/dev/null; then
        kubectl delete namespace learn-boss --timeout=60s 2>/dev/null || true
        kubectl delete namespace learn-boss-w4 --timeout=60s 2>/dev/null || true
        kubectl delete namespace learn-boss-w5 --timeout=60s 2>/dev/null || true
    fi
}

# ─── Pre-flight ───────────────────────────────────────────────────────────────

echo ""
bold "╔══════════════════════════════════════════════════════════╗"
bold "║     Learn Docker & K8s — Functional Tests               ║"
bold "║     Mode: $MODE                                          "
bold "╚══════════════════════════════════════════════════════════╝"
echo ""

if ! docker info &>/dev/null; then
    red "Docker is not running. Cannot execute functional tests."
    exit 1
fi

# ─── Docker Boss Fights ───────────────────────────────────────────────────────

run_docker_boss_test() {
    local world="$1" name="$2" solution="$3" verify="$4"

    bold "--- $world Boss: $name ---"
    echo ""

    if [ ! -f "$solution" ]; then
        test_skip "$name — solution script not found: $solution"
        echo ""
        return
    fi
    if [ ! -f "$verify" ]; then
        test_skip "$name — verifier not found: $verify"
        echo ""
        return
    fi

    # Step 1: Clean previous state
    echo "  Cleaning previous state..."
    cleanup_docker

    # Step 2: Rejection test — verifier should FAIL with no solution applied
    echo "  Testing verifier rejection (no solution applied)..."
    if bash "$verify" > /dev/null 2>&1; then
        test_fail "$name — verifier PASSED on empty state (should have failed)"
        echo ""
        return
    else
        test_pass "$name — verifier correctly rejects empty state"
    fi

    # Step 3: Apply known-good solution
    echo "  Applying known-good solution..."
    if bash "$solution" > /dev/null 2>&1; then
        test_pass "$name — solution script executed successfully"
    else
        test_fail "$name — solution script failed"
        cleanup_docker
        echo ""
        return
    fi

    # Step 4: Acceptance test — verifier should PASS
    echo "  Testing verifier acceptance..."
    if bash "$verify" > /dev/null 2>&1; then
        test_pass "$name — verifier accepts known-good solution"
    else
        test_fail "$name — verifier REJECTED known-good solution"
    fi

    # Step 5: Cleanup
    echo "  Cleaning up..."
    cleanup_docker
    echo ""
}

# ─── K8s Boss Fights ─────────────────────────────────────────────────────────

run_k8s_boss_test() {
    local world="$1" name="$2" solution="$3" verify="$4"

    bold "--- $world Boss: $name ---"
    echo ""

    if ! command -v kubectl &>/dev/null; then
        test_skip "$name — kubectl not available"
        echo ""
        return
    fi
    if ! kind get clusters 2>/dev/null | grep -q "learn-k8s"; then
        test_skip "$name — kind cluster 'learn-k8s' not found"
        echo ""
        return
    fi
    if [ ! -f "$solution" ]; then
        test_skip "$name — solution script not found"
        echo ""
        return
    fi

    # Step 1: Clean previous state
    echo "  Cleaning previous K8s state..."
    cleanup_k8s
    sleep 2

    # Step 2: Rejection test
    echo "  Testing verifier rejection..."
    if bash "$verify" > /dev/null 2>&1; then
        test_fail "$name — verifier PASSED on empty state"
        echo ""
        return
    else
        test_pass "$name — verifier correctly rejects empty state"
    fi

    # Step 3: Apply solution
    echo "  Applying known-good solution..."
    if bash "$solution" > /dev/null 2>&1; then
        test_pass "$name — solution script executed"
    else
        test_fail "$name — solution script failed"
        cleanup_k8s
        echo ""
        return
    fi

    # Step 4: Acceptance test
    echo "  Testing verifier acceptance..."
    if bash "$verify" > /dev/null 2>&1; then
        test_pass "$name — verifier accepts solution"
    else
        test_fail "$name — verifier REJECTED solution"
    fi

    # Step 5: Cleanup
    echo "  Cleaning up K8s resources..."
    cleanup_k8s
    echo ""
}

# ─── Execute Tests ────────────────────────────────────────────────────────────

if [ "$MODE" = "--docker" ] || [ "$MODE" = "--all" ]; then
    bold "=== Docker Functional Tests ==="
    echo ""

    run_docker_boss_test "W1" "The Morning From Hell" \
        "$SOLUTIONS_DIR/w1-morning-from-hell.sh" \
        "$PROJECT_DIR/curriculum/world-1-docker-foundations/boss-docker-diagnosis/challenges/verify.sh"

    run_docker_boss_test "W2" "The Full Stack Meltdown" \
        "$SOLUTIONS_DIR/w2-full-stack-meltdown.sh" \
        "$PROJECT_DIR/curriculum/world-2-docker-engineering/boss-production-docker/challenges/verify.sh"
fi

if [ "$MODE" = "--k8s" ] || [ "$MODE" = "--all" ]; then
    bold "=== Kubernetes Functional Tests ==="
    echo ""

    run_k8s_boss_test "W3" "The Cluster Crisis" \
        "$SOLUTIONS_DIR/w3-cluster-crisis.sh" \
        "$PROJECT_DIR/curriculum/world-3-kubernetes-core/boss-k8s-incident/challenges/verify.sh"

    run_k8s_boss_test "W4" "The Great Latte Leak" \
        "$SOLUTIONS_DIR/w4-great-latte-leak.sh" \
        "$PROJECT_DIR/curriculum/world-4-kubernetes-production/boss-great-latte-leak/challenges/verify.sh"

    run_k8s_boss_test "W5" "The Full Platform" \
        "$SOLUTIONS_DIR/w5-full-platform.sh" \
        "$PROJECT_DIR/curriculum/world-5-platform-engineering/boss-platform-capstone/challenges/verify.sh"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
bold "═══ Functional Test Summary ═══"
green "  Passed:  $PASS_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    red "  Failed:  $FAIL_COUNT"
fi
if [ "$SKIP_COUNT" -gt 0 ]; then
    yellow "  Skipped: $SKIP_COUNT"
fi
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    red "Functional tests have failures."
    exit 1
else
    green "All executed functional tests passed!"
    exit 0
fi
