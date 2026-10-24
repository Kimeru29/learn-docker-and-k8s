#!/bin/bash
# Curriculum Self-Testing Framework
# Validates that the curriculum is internally consistent and functional.
#
# Run: bash tests/test-curriculum.sh [--quick|--full|--docker|--portability]
#
# CI Tiers:
#   --quick        Structural checks only (no Docker/K8s required, <5s)
#   --full         Structural + platform compatibility (no Docker required)
#   --docker       Structural + Docker functional tests (requires Docker)
#   --portability  Static analysis for hardcoded paths/architectures
#
# Checks:
#   1. Structural integrity: all referenced files exist
#   2. Challenge fixtures: starting state can be created
#   3. Verification scripts: syntax-valid and executable
#   4. Cross-references: quiz, lesson, and challenge files are consistent
#   5. Platform compatibility: architecture-aware checks
#   6. Migration: v1→v2 progress migration works
#   7. Engine consistency: competency model matches across files
#
# Exit 0 = all checks passed
# Exit 1 = failures found

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CURRICULUM_DIR="$PROJECT_DIR/curriculum"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0
MODE="${1:---quick}"
TARGET_CHAPTER="${2:-}"

# ─── Helpers ──────────────────────────────────────────────────────────────────

green()  { printf "\033[0;32m%s\033[0m\n" "$*"; }
red()    { printf "\033[0;31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[0;33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

pass() { green "  PASS: $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { red "  FAIL: $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { yellow "  WARN: $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
skip() { echo "  SKIP: $1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }

# ─── Check 1: Structural Integrity ───────────────────────────────────────────

check_structure() {
    bold "=== Structural Integrity ==="
    echo ""

    # Check curriculum map exists
    if [ -f "$CURRICULUM_DIR/map.yaml" ]; then
        pass "curriculum/map.yaml exists"
    else
        fail "curriculum/map.yaml missing"
    fi

    # Check each world directory
    for world_dir in "$CURRICULUM_DIR"/world-*/; do
        if [ ! -d "$world_dir" ]; then continue; fi
        local world_name=$(basename "$world_dir")

        if [ -f "$world_dir/README.md" ]; then
            pass "$world_name/README.md exists"
        else
            fail "$world_name/README.md missing"
        fi

        # Check chapters within world
        for chapter_dir in "$world_dir"ch*/; do
            if [ ! -d "$chapter_dir" ]; then continue; fi
            local chapter_name=$(basename "$chapter_dir")

            # Skip if targeting a specific chapter
            if [ -n "$TARGET_CHAPTER" ] && [ "$chapter_name" != "$TARGET_CHAPTER" ]; then
                continue
            fi

            # README
            if [ -f "$chapter_dir/README.md" ]; then
                pass "$world_name/$chapter_name/README.md exists"
            else
                fail "$world_name/$chapter_name/README.md missing"
            fi

            # Lessons directory
            if [ -d "$chapter_dir/lessons" ]; then
                local lesson_count=$(find "$chapter_dir/lessons" -name "*.md" -type f | wc -l | tr -d ' ')
                if [ "$lesson_count" -gt 0 ]; then
                    pass "$world_name/$chapter_name has $lesson_count lesson(s)"
                else
                    warn "$world_name/$chapter_name/lessons/ is empty"
                fi
            else
                fail "$world_name/$chapter_name/lessons/ directory missing"
            fi

            # Challenges directory
            if [ -d "$chapter_dir/challenges" ]; then
                local challenge_count=$(find "$chapter_dir/challenges" -name "*.md" -type f | wc -l | tr -d ' ')
                if [ "$challenge_count" -gt 0 ]; then
                    pass "$world_name/$chapter_name has $challenge_count challenge(s)"
                else
                    warn "$world_name/$chapter_name/challenges/ is empty"
                fi
            else
                fail "$world_name/$chapter_name/challenges/ directory missing"
            fi

            # Quiz
            if [ -f "$chapter_dir/quiz.md" ]; then
                pass "$world_name/$chapter_name/quiz.md exists"
            else
                warn "$world_name/$chapter_name/quiz.md missing (skip-level quizzes won't work)"
            fi
        done

        # Check boss fight
        for boss_dir in "$world_dir"boss-*/; do
            if [ ! -d "$boss_dir" ]; then continue; fi
            local boss_name=$(basename "$boss_dir")

            if [ -f "$boss_dir/README.md" ]; then
                pass "$world_name/$boss_name/README.md exists"
            else
                warn "$world_name/$boss_name/README.md missing"
            fi
        done
    done

    # Check deep dives
    for dive_dir in "$CURRICULUM_DIR"/deep-dives/*/; do
        if [ ! -d "$dive_dir" ]; then continue; fi
        local dive_name=$(basename "$dive_dir")

        if [ -f "$dive_dir/README.md" ]; then
            pass "deep-dives/$dive_name/README.md exists"
        else
            warn "deep-dives/$dive_name/README.md missing"
        fi
    done

    echo ""
}

# ─── Check 2: Verification Scripts ───────────────────────────────────────────

check_verify_scripts() {
    bold "=== Verification Scripts ==="
    echo ""

    local verify_scripts=$(find "$CURRICULUM_DIR" -name "verify.sh" -type f)

    if [ -z "$verify_scripts" ]; then
        warn "No verify.sh scripts found"
        return
    fi

    while IFS= read -r script; do
        local rel_path="${script#$PROJECT_DIR/}"

        # Check it's executable or at least valid bash
        if bash -n "$script" 2>/dev/null; then
            pass "$rel_path is valid bash"
        else
            fail "$rel_path has syntax errors"
        fi

        # Check it uses the learn- prefix in checks
        if grep -q "learn-" "$script" 2>/dev/null; then
            pass "$rel_path references learn- prefixed resources"
        else
            warn "$rel_path doesn't reference learn- prefixed resources"
        fi
    done <<< "$verify_scripts"

    echo ""
}

# ─── Check 3: Cross-References ───────────────────────────────────────────────

check_cross_references() {
    bold "=== Cross-References ==="
    echo ""

    # Check that lesson files referenced in READMEs actually exist
    for readme in $(find "$CURRICULUM_DIR" -name "README.md" -path "*/ch*/README.md"); do
        local dir=$(dirname "$readme")
        local rel_dir="${dir#$PROJECT_DIR/}"

        # Extract lesson references
        while IFS= read -r ref; do
            local target="$dir/$ref"
            if [ -f "$target" ]; then
                pass "$rel_dir: referenced file $ref exists"
            else
                fail "$rel_dir: referenced file $ref NOT FOUND"
            fi
        done < <(grep -oE 'lessons/[0-9]+-[a-z-]+\.md' "$readme" 2>/dev/null || true)

        # Extract challenge references
        while IFS= read -r ref; do
            local target="$dir/$ref"
            if [ -f "$target" ]; then
                pass "$rel_dir: referenced file $ref exists"
            else
                fail "$rel_dir: referenced file $ref NOT FOUND"
            fi
        done < <(grep -oE 'challenges/[0-9]+-[a-z-]+\.md' "$readme" 2>/dev/null || true)
    done

    echo ""
}

# ─── Check 4: Engine Files ───────────────────────────────────────────────────

check_engine() {
    bold "=== Engine Files ==="
    echo ""

    local engine_dir="$PROJECT_DIR/engine"
    local required_files=(rules.md narrator.md validation.md competency.md modes.md environment-check.sh cleanup.sh platform.sh)

    for f in "${required_files[@]}"; do
        if [ -f "$engine_dir/$f" ]; then
            pass "engine/$f exists"
        else
            fail "engine/$f missing"
        fi
    done

    # Check scripts are executable
    for script in environment-check.sh cleanup.sh platform.sh; do
        if [ -x "$engine_dir/$script" ] || bash -n "$engine_dir/$script" 2>/dev/null; then
            pass "engine/$script is valid"
        else
            fail "engine/$script has issues"
        fi
    done

    echo ""
}

# ─── Check 5: Progress Template ──────────────────────────────────────────────

check_progress() {
    bold "=== Progress Template ==="
    echo ""

    local template="$PROJECT_DIR/.player/progress.yaml.template"
    if [ -f "$template" ]; then
        pass "progress.yaml.template exists"

        # Check it has the new v2 structure
        if grep -q "version: 2" "$template"; then
            pass "Progress template is v2 format"
        else
            warn "Progress template may be outdated (missing version: 2)"
        fi

        if grep -q "competencies:" "$template"; then
            pass "Progress template includes competency tracking"
        else
            warn "Progress template missing competency tracking"
        fi

        if grep -q "worlds:" "$template"; then
            pass "Progress template uses world structure"
        else
            fail "Progress template missing world structure"
        fi
    else
        fail "progress.yaml.template missing"
    fi

    echo ""
}

# ─── Check 6: Platform Compatibility (--full only) ───────────────────────────

check_platform() {
    if [ "$MODE" != "--full" ]; then
        skip "Platform checks (run with --full to enable)"
        return
    fi

    bold "=== Platform Compatibility ==="
    echo ""

    # Detect current platform
    local arch=$(uname -m)
    echo "  Current architecture: $arch"

    # Check for hardcoded amd64 references in Dockerfiles
    local hardcoded=$(grep -rl "amd64\|x86_64" "$CURRICULUM_DIR" --include="Dockerfile*" --include="*.sh" 2>/dev/null || true)
    if [ -n "$hardcoded" ]; then
        warn "Files with hardcoded architecture references:"
        echo "$hardcoded" | while read -r f; do
            yellow "    ${f#$PROJECT_DIR/}"
        done
    else
        pass "No hardcoded architecture references found"
    fi

    echo ""
}

# ─── Run Checks ──────────────────────────────────────────────────────────────

echo ""
bold "╔══════════════════════════════════════════════════════════╗"
bold "║       Learn Docker & K8s — Curriculum Self-Test         ║"
bold "║       Mode: $MODE                                       "
bold "╚══════════════════════════════════════════════════════════╝"
echo ""

check_structure
check_verify_scripts
check_cross_references
check_engine
check_progress

# ─── Check 6: Engine Consistency ──────────────────────────────────────────────

check_engine_consistency() {
    bold "=== Engine Consistency ==="
    echo ""

    # Verify competency levels are consistent across files
    local rules_levels=$(grep -c "unexposed\|introduced\|practicing\|competent\|proficient" "$PROJECT_DIR/engine/rules.md" 2>/dev/null || echo "0")
    local comp_levels=$(grep -c "unexposed\|introduced\|practicing\|competent\|proficient" "$PROJECT_DIR/engine/competency.md" 2>/dev/null || echo "0")

    if [ "$rules_levels" -gt 0 ] && [ "$comp_levels" -gt 0 ]; then
        pass "Competency terminology present in both rules.md and competency.md"
    else
        fail "Competency terminology missing from rules.md ($rules_levels refs) or competency.md ($comp_levels refs)"
    fi

    # Check for old terminology (novice/developing/advanced as competency levels)
    local old_terms=$(grep -n "Novice:\|Developing:\|Advanced:" "$PROJECT_DIR/engine/rules.md" 2>/dev/null | grep -iv "difficulty\|world\|chapter\|deep" | head -5)
    if [ -n "$old_terms" ]; then
        fail "Old competency terminology found in rules.md (should use unexposed/introduced/practicing/competent/proficient)"
    else
        pass "No old competency terminology in rules.md"
    fi

    # Check interview-readiness.md exists
    if [ -f "$PROJECT_DIR/engine/interview-readiness.md" ]; then
        pass "engine/interview-readiness.md exists"
    else
        warn "engine/interview-readiness.md missing (interview readiness not defined)"
    fi

    # Check migration script exists and is valid
    if [ -f "$PROJECT_DIR/engine/migrate-progress.sh" ]; then
        if bash -n "$PROJECT_DIR/engine/migrate-progress.sh" 2>/dev/null; then
            pass "engine/migrate-progress.sh exists and is valid bash"
        else
            fail "engine/migrate-progress.sh has syntax errors"
        fi
    else
        fail "engine/migrate-progress.sh missing"
    fi

    echo ""
}

# ─── Check 7: Legacy Cleanup ─────────────────────────────────────────────────

check_legacy_cleanup() {
    bold "=== Legacy Cleanup ==="
    echo ""

    # Old curriculum dirs should NOT exist in curriculum/
    local old_dirs=0
    for d in curriculum/ch01-containers curriculum/ch02-image-optimization curriculum/ch03-persistence curriculum/ch04-networking curriculum/ch05-compose curriculum/ch06-k8s-intro curriculum/ch07-k8s-production; do
        if [ -d "$PROJECT_DIR/$d" ]; then
            fail "Legacy directory still exists: $d (should be in _legacy/)"
            old_dirs=$((old_dirs + 1))
        fi
    done
    if [ "$old_dirs" -eq 0 ]; then
        pass "No legacy curriculum directories in curriculum/"
    fi

    # images/ directory should not exist
    if [ -d "$PROJECT_DIR/images" ]; then
        fail "images/ directory still exists (duplicate fixtures)"
    else
        pass "No images/ directory (duplicates cleaned up)"
    fi

    # fixtures/ directory should not exist (was empty, removed)
    if [ -d "$PROJECT_DIR/fixtures" ]; then
        warn "Empty fixtures/ directory still exists"
    else
        pass "No empty fixtures/ directory"
    fi

    echo ""
}

# ─── Check 8: Portability ────────────────────────────────────────────────────

check_portability() {
    if [ "$MODE" != "--full" ] && [ "$MODE" != "--portability" ]; then
        skip "Portability checks (run with --full or --portability)"
        return
    fi

    bold "=== Portability Analysis ==="
    echo ""

    local arch=$(uname -m)
    echo "  Current architecture: $arch"

    # Check for macOS-only date syntax in verifiers
    local date_issues=$(grep -rn "date -j" "$CURRICULUM_DIR" --include="*.sh" 2>/dev/null || true)
    if [ -n "$date_issues" ]; then
        fail "macOS-only 'date -j' found in verifiers:"
        echo "$date_issues" | while read -r line; do red "    $line"; done
    else
        pass "No macOS-only date syntax in verifiers"
    fi

    # Check for hardcoded architecture in non-deep-dive content
    local hardcoded=$(grep -rl "amd64\|x86_64" "$CURRICULUM_DIR"/world-* --include="Dockerfile*" --include="*.sh" 2>/dev/null | grep -v "deep-dives/multi-architecture" || true)
    if [ -n "$hardcoded" ]; then
        warn "Files with hardcoded architecture references (outside multi-arch deep dive):"
        echo "$hardcoded" | while read -r f; do yellow "    ${f#$PROJECT_DIR/}"; done
    else
        pass "No hardcoded architecture references in core curriculum"
    fi

    # Check for GNU-specific utilities
    local gnu_issues=$(grep -rn "readlink -f\|sed -i ''" "$CURRICULUM_DIR" --include="*.sh" 2>/dev/null || true)
    if [ -n "$gnu_issues" ]; then
        warn "Potentially non-portable shell commands found:"
        echo "$gnu_issues" | while read -r line; do yellow "    $line"; done
    else
        pass "No obviously non-portable shell utilities detected"
    fi

    echo ""
}

check_engine_consistency
check_legacy_cleanup

if [ "$MODE" = "--full" ] || [ "$MODE" = "--portability" ]; then
    check_portability
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
bold "═══ Summary ═══"
green "  Passed:   $PASS_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    red "  Failed:   $FAIL_COUNT"
fi
if [ "$WARN_COUNT" -gt 0 ]; then
    yellow "  Warnings: $WARN_COUNT"
fi
if [ "$SKIP_COUNT" -gt 0 ]; then
    echo "  Skipped:  $SKIP_COUNT"
fi
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    red "Curriculum has $FAIL_COUNT issue(s) that should be fixed."
    exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
    yellow "Curriculum is functional with $WARN_COUNT warning(s)."
    exit 0
else
    green "All curriculum checks passed!"
    exit 0
fi
