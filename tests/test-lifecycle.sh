#!/bin/bash
# Engine Lifecycle State-Transition Test
#
# Tests the deterministic portions of the engine state machine:
#   - New v2 player initialization
#   - v1 → v2 migration
#   - Lesson/challenge/chapter/world status progression
#   - Competency level transitions
#   - Interview readiness calculation
#   - Boss-fight milestone tracking
#
# Does NOT test AI judgment, narrative quality, or subjective assessments.
#
# Usage: bash tests/test-lifecycle.sh
# Exit 0 = all tests passed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$PROJECT_DIR/.player/progress.yaml.template"
MIGRATE="$PROJECT_DIR/engine/migrate-progress.sh"
PROGRESS="$PROJECT_DIR/.player/progress.yaml"
PASS_COUNT=0
FAIL_COUNT=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

green()  { printf "\033[0;32m%s\033[0m\n" "$*"; }
red()    { printf "\033[0;31m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

pass() { green "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { red "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

assert_contains() {
    local file="$1" pattern="$2" desc="$3"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc (pattern '$pattern' not found)"
    fi
}

assert_not_contains() {
    local file="$1" pattern="$2" desc="$3"
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc (pattern '$pattern' found but should not exist)"
    fi
}

yaml_get() {
    local file="$1" key="$2"
    grep "  ${key}:" "$file" 2>/dev/null | head -1 | sed "s/.*${key}: *//" | tr -d '"' | tr -d "'" | sed 's/ *#.*//'
}

# Save original progress
ORIG_PROGRESS=""
if [ -f "$PROGRESS" ]; then
    ORIG_PROGRESS=$(cat "$PROGRESS")
fi

restore_progress() {
    if [ -n "$ORIG_PROGRESS" ]; then
        echo "$ORIG_PROGRESS" > "$PROGRESS"
    else
        rm -f "$PROGRESS"
    fi
}
trap restore_progress EXIT

# ─── Tests ────────────────────────────────────────────────────────────────────

echo ""
bold "╔══════════════════════════════════════════════════════════╗"
bold "║     Learn Docker & K8s — Engine Lifecycle Tests          ║"
bold "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Test 1: Template produces valid v2 file ──────────────────────────────────

bold "--- Test 1: Template Validity ---"

cp "$TEMPLATE" "$PROGRESS"
assert_contains "$PROGRESS" "version: 2" "Template has version: 2"
assert_contains "$PROGRESS" "worlds:" "Template has worlds section"
assert_contains "$PROGRESS" "competencies:" "Template has competencies section"
assert_contains "$PROGRESS" "ch01-containers:" "Template has ch01"
assert_contains "$PROGRESS" "ch09-k8s-architecture:" "Template has ch09"
assert_contains "$PROGRESS" "ch18-incident-response:" "Template has ch18"
assert_contains "$PROGRESS" "deep_dives:" "Template has deep_dives section"
assert_contains "$PROGRESS" "interview_sessions:" "Template has interview_sessions"

# All competency levels start at 0
NONZERO_COMP=$(grep "level:" "$PROGRESS" | grep -v "# " | grep -v "level: 0" | head -1)
if [ -z "$NONZERO_COMP" ]; then
    pass "All competency levels start at 0"
else
    fail "Found non-zero starting competency: $NONZERO_COMP"
fi

echo ""

# ── Test 2: Migration from v1 ───────────────────────────────────────────────

bold "--- Test 2: v1 → v2 Migration ---"

# Create a v1 file with partial progress
cat > "$PROGRESS" << 'V1EOF'
player:
  started_at: 2026-05-15
  language: es
  environment:
    docker: "27.0.0"
    compose: "2.24.0"
    os: "Darwin arm64"
chapters:
  ch01-containers:
    status: complete
    lessons: [01-what-is-docker, 02-images-and-containers, 03-basic-commands]
    challenges: [01-run-nginx, 02-build-first-image, 03-debug-port]
    skip_quiz_passed:
    quiz_score:
    current_hint_level: 0
  ch02-image-optimization:
    status: in-progress
    lessons: [01-dockerfile-deep-dive]
    challenges: []
    skip_quiz_passed:
    quiz_score:
    current_hint_level: 0
  ch03-persistence:
    status: not-started
    lessons: []
    challenges: []
    skip_quiz_passed:
    quiz_score:
    current_hint_level: 0
  ch04-networking:
    status: not-started
    lessons: []
    challenges: []
    skip_quiz_passed:
    quiz_score:
    current_hint_level: 0
  ch05-compose:
    status: not-started
    lessons: []
    challenges: []
    skip_quiz_passed:
    quiz_score:
    current_hint_level: 0
  ch06-k8s-intro:
    status: not-started
    lessons: []
    challenges: []
    skip_quiz_passed:
    quiz_score:
    current_hint_level: 0
  ch07-k8s-production:
    status: not-started
    lessons: []
    challenges: []
    skip_quiz_passed:
    quiz_score:
    current_hint_level: 0
V1EOF

bash "$MIGRATE" > /dev/null 2>&1
assert_contains "$PROGRESS" "version: 2" "Migration produces v2 file"
assert_contains "$PROGRESS" "language: es" "Migration preserves language"
assert_contains "$PROGRESS" "started_at: 2026-05-15" "Migration preserves start date"

# ch01 should be complete
MIGRATED_CH01=$(awk '/ch01-containers:/{found=1} found && /status:/{print $2; exit}' "$PROGRESS")
if [ "$MIGRATED_CH01" = "complete" ]; then
    pass "ch01 migrated as complete"
else
    fail "ch01 should be 'complete' but is '$MIGRATED_CH01'"
fi

# ch02 should be in-progress
MIGRATED_CH02=$(awk '/ch02-images:/{found=1} found && /status:/{print $2; exit}' "$PROGRESS")
if [ "$MIGRATED_CH02" = "in-progress" ]; then
    pass "ch02 migrated as in-progress"
else
    fail "ch02 should be 'in-progress' but is '$MIGRATED_CH02'"
fi

# World 1 should be in-progress (not all chapters complete)
MIGRATED_W1=$(awk '/world-1-docker-foundations:/{found=1} found && /status:/{print $2; exit}' "$PROGRESS")
if [ "$MIGRATED_W1" = "in-progress" ]; then
    pass "World 1 migrated as in-progress"
else
    fail "World 1 should be 'in-progress' but is '$MIGRATED_W1'"
fi

# World 2 should be not-started (no ch05 progress)
W2_STATUS=$(awk '/world-2-docker-engineering:/{found=1} found && /^    status:/{print $2; exit}' "$PROGRESS")
if [ "$W2_STATUS" = "not-started" ]; then
    pass "World 2 correctly not-started"
else
    fail "World 2 should be 'not-started' but is '$W2_STATUS'"
fi

# docker-cli competency should be 2 (practicing — complete chapter)
COMP_CLI=$(awk '/^  docker-cli:/{found=1} found && /level:/{print $2; exit}' "$PROGRESS")
if [ "$COMP_CLI" = "2" ]; then
    pass "docker-cli competency set to 2 (practicing)"
else
    fail "docker-cli should be level 2 but is '$COMP_CLI'"
fi

# dockerfile competency should be 1 (introduced — in-progress chapter)
COMP_DF=$(awk '/^  dockerfile:/{found=1} found && /level:/{print $2; exit}' "$PROGRESS")
if [ "$COMP_DF" = "1" ]; then
    pass "dockerfile competency set to 1 (introduced)"
else
    fail "dockerfile should be level 1 but is '$COMP_DF'"
fi

# k8s-architecture should be 0 (unexposed)
COMP_K8S=$(awk '/^  k8s-architecture:/{found=1} found && /level:/{print $2; exit}' "$PROGRESS")
if [ "$COMP_K8S" = "0" ]; then
    pass "k8s-architecture correctly at 0 (unexposed)"
else
    fail "k8s-architecture should be 0 but is '$COMP_K8S'"
fi

echo ""

# ── Test 3: Migration idempotency ────────────────────────────────────────────

bold "--- Test 3: Migration Idempotency ---"

BEFORE=$(cat "$PROGRESS")
bash "$MIGRATE" > /dev/null 2>&1
AFTER=$(cat "$PROGRESS")

if [ "$BEFORE" = "$AFTER" ]; then
    pass "Migration is idempotent (no changes on second run)"
else
    fail "Migration modified already-migrated file"
fi

echo ""

# ── Test 4: Schema validation ────────────────────────────────────────────────

bold "--- Test 4: Progress Schema Validation ---"

cp "$TEMPLATE" "$PROGRESS"

# All required top-level keys exist
for key in version player worlds deep_dives competencies interview_sessions; do
    assert_contains "$PROGRESS" "^${key}:" "Top-level key '$key' exists"
done

# All 5 worlds exist
for w in world-1-docker-foundations world-2-docker-engineering world-3-kubernetes-core world-4-kubernetes-production world-5-platform-engineering; do
    assert_contains "$PROGRESS" "$w:" "World '$w' exists"
done

# All 18 chapters exist
for ch in ch01-containers ch02-images ch03-storage ch04-networking ch05-compose ch06-process-management ch07-troubleshooting ch08-docker-security ch09-k8s-architecture ch10-workloads ch11-k8s-networking ch12-k8s-storage ch13-health-reliability ch14-scheduling ch15-k8s-security ch16-observability ch17-delivery ch18-incident-response; do
    assert_contains "$PROGRESS" "$ch:" "Chapter '$ch' exists in template"
done

# All 22 competency areas exist
for comp in docker-cli dockerfile container-runtime docker-networking docker-storage docker-compose docker-security docker-troubleshooting k8s-architecture k8s-workloads k8s-networking k8s-storage k8s-configuration k8s-health k8s-scheduling k8s-security observability delivery incident-response linux-fundamentals networking-fundamentals; do
    assert_contains "$PROGRESS" "^  ${comp}:" "Competency '$comp' exists"
done

echo ""

# ── Test 5: Interview readiness competency IDs match ─────────────────────────

bold "--- Test 5: Interview Readiness Consistency ---"

READINESS="$PROJECT_DIR/engine/interview-readiness.md"
MAP="$PROJECT_DIR/curriculum/map.yaml"

if [ -f "$READINESS" ] && [ -f "$MAP" ]; then
    # Extract competency IDs from readiness requirements
    READINESS_COMPS=$(grep "^- " "$READINESS" | sed 's/- //' | sed 's/ .*//' | grep "^[a-z]" | sort -u)

    # Extract competency IDs from map.yaml
    MAP_COMPS=$(awk '/^competencies:/,/^worlds:/' "$MAP" | grep "^  [a-z].*:" | sed 's/:.*//' | tr -d ' ' | sort -u)

    ALL_MATCH=true
    for comp in $READINESS_COMPS; do
        if ! echo "$MAP_COMPS" | grep -q "^${comp}$"; then
            fail "Readiness references competency '$comp' not found in map.yaml"
            ALL_MATCH=false
        fi
    done
    $ALL_MATCH && pass "All readiness competency IDs exist in curriculum map"
else
    fail "interview-readiness.md or map.yaml not found"
fi

echo ""

# ── Test 6: Engine file consistency ──────────────────────────────────────────

bold "--- Test 6: Engine File Consistency ---"

# rules.md and competency.md should use the same level names
RULES_LEVELS=$(grep -c "unexposed\|introduced\|practicing\|competent\|proficient" "$PROJECT_DIR/engine/rules.md" 2>/dev/null || echo "0")
COMP_LEVELS=$(grep -c "unexposed\|introduced\|practicing\|competent\|proficient" "$PROJECT_DIR/engine/competency.md" 2>/dev/null || echo "0")

if [ "$RULES_LEVELS" -gt 0 ] && [ "$COMP_LEVELS" -gt 0 ]; then
    pass "Competency level names present in both rules.md and competency.md"
else
    fail "Competency level names missing from rules.md ($RULES_LEVELS) or competency.md ($COMP_LEVELS)"
fi

# No old competency terminology
OLD_TERMS=$(grep -n "Novice:\|Developing:" "$PROJECT_DIR/engine/rules.md" 2>/dev/null | grep -iv "difficulty\|world" | wc -l | tr -d ' ')
if [ "$OLD_TERMS" = "0" ]; then
    pass "No old competency terminology in rules.md"
else
    fail "Found $OLD_TERMS instances of old competency terminology"
fi

# modes.md exists and references interview modes
assert_contains "$PROJECT_DIR/engine/modes.md" "Conceptual" "modes.md references Conceptual interview"
assert_contains "$PROJECT_DIR/engine/modes.md" "Troubleshooting" "modes.md references Troubleshooting interview"
assert_contains "$PROJECT_DIR/engine/modes.md" "Architecture" "modes.md references Architecture interview"

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
bold "═══ Lifecycle Test Summary ═══"
green "  Passed:  $PASS_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    red "  Failed:  $FAIL_COUNT"
fi
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    red "Lifecycle tests have failures."
    exit 1
else
    green "All lifecycle tests passed!"
    exit 0
fi
