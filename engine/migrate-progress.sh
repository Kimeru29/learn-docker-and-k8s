#!/bin/bash
# Migrate player progress from v1 (7-chapter) to v2 (worlds/competencies).
#
# Usage: bash engine/migrate-progress.sh [--dry-run]
#
# The script:
#   1. Detects v1 format (missing "version: 2" or has top-level "chapters:" key)
#   2. Maps old chapter progress to new world/chapter structure
#   3. Initializes competency evidence conservatively
#   4. Preserves timestamps and environment info
#   5. Writes a v2 progress file (or prints it with --dry-run)
#   6. Backs up the original before overwriting
#
# Idempotent: running on an already-v2 file does nothing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROGRESS="$PROJECT_DIR/.player/progress.yaml"
TEMPLATE="$PROJECT_DIR/.player/progress.yaml.template"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────

green()  { printf "\033[0;32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[0;33m%s\033[0m\n" "$*"; }
red()    { printf "\033[0;31m%s\033[0m\n" "$*"; }

# Simple YAML value reader (no dependency on yq/python)
yaml_value() {
    local file="$1" key="$2"
    grep "^  *${key}:" "$file" 2>/dev/null | head -1 | sed "s/.*${key}: *//" | sed 's/"//g' | sed "s/'//g" | tr -d ' '
}

yaml_list() {
    local file="$1" key="$2"
    grep "^  *${key}:" "$file" 2>/dev/null | head -1 | sed "s/.*${key}: *//" | tr -d '[]"' | tr -d "'" | tr ',' '\n' | sed 's/^ *//' | sed '/^$/d'
}

# ─── Check if migration is needed ────────────────────────────────────────────

if [[ ! -f "$PROGRESS" ]]; then
    echo "No progress file found at $PROGRESS. Nothing to migrate."
    exit 0
fi

if grep -q "^version: 2" "$PROGRESS" 2>/dev/null; then
    green "Progress file is already v2 format. No migration needed."
    exit 0
fi

if ! grep -q "^chapters:" "$PROGRESS" 2>/dev/null; then
    echo "Progress file does not look like v1 format (no top-level 'chapters:' key)."
    echo "Cannot migrate. Check the file manually."
    exit 1
fi

echo "=== Progress Migration: v1 → v2 ==="
echo ""

# ─── Read v1 data ─────────────────────────────────────────────────────────────

V1_STARTED=$(yaml_value "$PROGRESS" "started_at")
V1_LANGUAGE=$(yaml_value "$PROGRESS" "language")
V1_DOCKER=$(yaml_value "$PROGRESS" "docker")
V1_COMPOSE=$(yaml_value "$PROGRESS" "compose")
V1_OS=$(yaml_value "$PROGRESS" "os")

echo "Player started: $V1_STARTED"
echo "Language: $V1_LANGUAGE"
echo "Environment: Docker $V1_DOCKER, Compose $V1_COMPOSE, OS $V1_OS"
echo ""

# Read chapter statuses
declare -A V1_STATUS
declare -A V1_LESSONS
declare -A V1_CHALLENGES

for ch in ch01-containers ch02-image-optimization ch03-persistence ch04-networking ch05-compose ch06-k8s-intro ch07-k8s-production; do
    # Extract status by looking at the block under each chapter
    status=$(awk "/^  ${ch}:/{found=1} found && /status:/{print \$2; exit}" "$PROGRESS" 2>/dev/null || echo "not-started")
    V1_STATUS[$ch]="$status"

    lessons=$(awk "/^  ${ch}:/{found=1} found && /lessons:/{print; exit}" "$PROGRESS" 2>/dev/null | sed 's/.*lessons: *//' | tr -d '[]' || echo "")
    V1_LESSONS[$ch]="$lessons"

    challenges=$(awk "/^  ${ch}:/{found=1} found && /challenges:/{print; exit}" "$PROGRESS" 2>/dev/null | sed 's/.*challenges: *//' | tr -d '[]' || echo "")
    V1_CHALLENGES[$ch]="$challenges"

    echo "  $ch: status=${V1_STATUS[$ch]}"
done
echo ""

# ─── Build v2 chapter mappings ────────────────────────────────────────────────
# v1 chapter → v2 world/chapter mapping:
#   ch01-containers         → world-1/ch01-containers
#   ch02-image-optimization → world-1/ch02-images
#   ch03-persistence        → world-1/ch03-storage
#   ch04-networking         → world-1/ch04-networking
#   ch05-compose            → world-2/ch05-compose
#   ch06-k8s-intro          → world-3/ch09-k8s-architecture (partial)
#   ch07-k8s-production     → world-4/ch13-health-reliability (partial)

map_status() {
    local v1_status="$1"
    case "$v1_status" in
        complete)    echo "complete" ;;
        in-progress) echo "in-progress" ;;
        skipped)     echo "complete" ;;  # If they passed skip quiz, credit it
        *)           echo "not-started" ;;
    esac
}

# Compute competency level from v1 completion evidence
# Conservative: complete chapter → level 2 (practicing), not 3 (competent)
# Rationale: v1 didn't track hint usage or solution quality
competency_from_chapter() {
    local status="$1"
    case "$status" in
        complete) echo 2 ;;   # practicing — they passed but we lack quality signals
        in-progress) echo 1 ;; # introduced
        *) echo 0 ;;          # unexposed
    esac
}

# ─── Generate v2 progress ────────────────────────────────────────────────────

# Determine world statuses
w1_complete=true
for ch in ch01-containers ch02-image-optimization ch03-persistence ch04-networking; do
    [[ "${V1_STATUS[$ch]}" != "complete" ]] && w1_complete=false
done

w2_ch05="${V1_STATUS[ch05-compose]}"

# v1 ch06 only partially maps to W3 ch09
w3_partial="${V1_STATUS[ch06-k8s-intro]}"

# v1 ch07 only partially maps to W4 ch13
w4_partial="${V1_STATUS[ch07-k8s-production]}"

# Compute competency levels
CL_DOCKER_CLI=$(competency_from_chapter "${V1_STATUS[ch01-containers]}")
CL_DOCKERFILE=$(competency_from_chapter "${V1_STATUS[ch02-image-optimization]}")
CL_STORAGE=$(competency_from_chapter "${V1_STATUS[ch03-persistence]}")
CL_NETWORKING=$(competency_from_chapter "${V1_STATUS[ch04-networking]}")
CL_COMPOSE=$(competency_from_chapter "${V1_STATUS[ch05-compose]}")
CL_K8S_ARCH=$(competency_from_chapter "${V1_STATUS[ch06-k8s-intro]}")
CL_K8S_HEALTH=$(competency_from_chapter "${V1_STATUS[ch07-k8s-production]}")
CL_LINUX=$(( CL_DOCKER_CLI > 0 ? 1 : 0 ))
CL_NET_FUND=$(( CL_NETWORKING > 0 ? 1 : 0 ))
CL_RUNTIME=$(( CL_DOCKER_CLI > 0 ? 1 : 0 ))

# Determine world-level status
if $w1_complete; then
    W1_STATUS="complete"
else
    has_any=false
    for ch in ch01-containers ch02-image-optimization ch03-persistence ch04-networking; do
        [[ "${V1_STATUS[$ch]}" != "not-started" ]] && has_any=true
    done
    $has_any && W1_STATUS="in-progress" || W1_STATUS="not-started"
fi

[[ "$w2_ch05" == "complete" || "$w2_ch05" == "in-progress" ]] && W2_STATUS="in-progress" || W2_STATUS="not-started"
[[ "$w3_partial" == "complete" || "$w3_partial" == "in-progress" ]] && W3_STATUS="in-progress" || W3_STATUS="not-started"
[[ "$w4_partial" == "complete" || "$w4_partial" == "in-progress" ]] && W4_STATUS="in-progress" || W4_STATUS="not-started"

echo "Migration mapping:"
echo "  World 1: $W1_STATUS"
echo "  World 2: $W2_STATUS (ch05 only)"
echo "  World 3: $W3_STATUS (ch09 from old ch06, partial)"
echo "  World 4: $W4_STATUS (ch13 from old ch07, partial)"
echo ""
echo "Competency levels (conservative — old format lacks quality signals):"
echo "  docker-cli: $CL_DOCKER_CLI, dockerfile: $CL_DOCKERFILE"
echo "  docker-storage: $CL_STORAGE, docker-networking: $CL_NETWORKING"
echo "  docker-compose: $CL_COMPOSE, k8s-architecture: $CL_K8S_ARCH"
echo "  k8s-health: $CL_K8S_HEALTH"
echo ""

if $DRY_RUN; then
    yellow "Dry run — no changes written."
    exit 0
fi

# ─── Backup and write ────────────────────────────────────────────────────────

BACKUP="${PROGRESS}.v1-backup.$(date +%Y%m%d%H%M%S)"
cp "$PROGRESS" "$BACKUP"
green "Backed up v1 progress to: $BACKUP"

# Start from template and fill in values
cp "$TEMPLATE" "$PROGRESS"

# Portable sed in-place (works on both macOS and Linux)
psed() {
    local expr="$1" file="$2"
    awk "$expr" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Patch player section using awk for portability
awk -v sa="${V1_STARTED:-}" -v lang="${V1_LANGUAGE:-en}" \
    -v dock="${V1_DOCKER:-}" -v comp="${V1_COMPOSE:-}" -v os="${V1_OS:-}" '
    /^  started_at:/ { print "  started_at: " sa; next }
    /^  language:/ { print "  language: " lang; next }
    dock != "" && /^    docker:/ { print "    docker: \"" dock "\""; next }
    comp != "" && /^    compose:/ { print "    compose: \"" comp "\""; next }
    os != "" && /^    os:/ { print "    os: \"" os "\""; next }
    { print }
' "$PROGRESS" > "${PROGRESS}.tmp" && mv "${PROGRESS}.tmp" "$PROGRESS"

# Helper: patch chapter status in the v2 file
patch_chapter() {
    local chapter="$1" status="$2" lessons="$3" challenges="$4"
    # Use awk to find the chapter block and patch it
    awk -v ch="$chapter" -v st="$status" -v les="$lessons" -v chal="$challenges" '
    $0 ~ "^      " ch ":" { found=1 }
    found && /status:/ { sub(/not-started/, st); found_status=1 }
    found && found_status && /lessons:/ {
        if (les != "") { sub(/\[\]/, "[" les "]") }
        found_lessons=1
    }
    found && found_lessons && /challenges:/ {
        if (chal != "") { sub(/\[\]/, "[" chal "]") }
        found=0; found_status=0; found_lessons=0
    }
    { print }
    ' "$PROGRESS" > "${PROGRESS}.tmp" && mv "${PROGRESS}.tmp" "$PROGRESS"
}

# Patch individual chapters FIRST (before world status, to avoid awk matching conflicts)
patch_chapter "ch01-containers" "$(map_status "${V1_STATUS[ch01-containers]}")" "${V1_LESSONS[ch01-containers]}" "${V1_CHALLENGES[ch01-containers]}"
patch_chapter "ch02-images" "$(map_status "${V1_STATUS[ch02-image-optimization]}")" "${V1_LESSONS[ch02-image-optimization]}" "${V1_CHALLENGES[ch02-image-optimization]}"
patch_chapter "ch03-storage" "$(map_status "${V1_STATUS[ch03-persistence]}")" "${V1_LESSONS[ch03-persistence]}" "${V1_CHALLENGES[ch03-persistence]}"
patch_chapter "ch04-networking" "$(map_status "${V1_STATUS[ch04-networking]}")" "${V1_LESSONS[ch04-networking]}" "${V1_CHALLENGES[ch04-networking]}"
patch_chapter "ch05-compose" "$(map_status "${V1_STATUS[ch05-compose]}")" "${V1_LESSONS[ch05-compose]}" "${V1_CHALLENGES[ch05-compose]}"
patch_chapter "ch09-k8s-architecture" "$(map_status "${V1_STATUS[ch06-k8s-intro]}")" "${V1_LESSONS[ch06-k8s-intro]}" "${V1_CHALLENGES[ch06-k8s-intro]}"
patch_chapter "ch13-health-reliability" "$(map_status "${V1_STATUS[ch07-k8s-production]}")" "${V1_LESSONS[ch07-k8s-production]}" "${V1_CHALLENGES[ch07-k8s-production]}"

# NOW patch world-level statuses (after chapters, so awk doesn't conflict)
# Patch each world status independently using a targeted awk per world
patch_world_status() {
    local world_key="$1" new_status="$2"
    if [[ "$new_status" == "not-started" ]]; then
        return  # No change needed
    fi
    awk -v wk="$world_key" -v st="$new_status" '
        !patched && $0 ~ "^  " wk ":" { found=1 }
        found && !patched && /^    status:/ { sub(/not-started/, st); found=0; patched=1 }
        /^  world-[0-9]/ && !($0 ~ wk) { found=0 }
        { print }
    ' "$PROGRESS" > "${PROGRESS}.tmp" && mv "${PROGRESS}.tmp" "$PROGRESS"
}

patch_world_status "world-1-docker-foundations" "$W1_STATUS"
patch_world_status "world-2-docker-engineering" "$W2_STATUS"
patch_world_status "world-3-kubernetes-core" "$W3_STATUS"
patch_world_status "world-4-kubernetes-production" "$W4_STATUS"

# Patch competency levels
for pair in "docker-cli:$CL_DOCKER_CLI" "dockerfile:$CL_DOCKERFILE" "docker-storage:$CL_STORAGE" \
            "docker-networking:$CL_NETWORKING" "docker-compose:$CL_COMPOSE" \
            "k8s-architecture:$CL_K8S_ARCH" "k8s-health:$CL_K8S_HEALTH" \
            "linux-fundamentals:$CL_LINUX" "networking-fundamentals:$CL_NET_FUND" \
            "container-runtime:$CL_RUNTIME"; do
    key="${pair%%:*}"
    val="${pair##*:}"
    if [[ "$val" -gt 0 ]]; then
        awk -v k="$key" -v v="$val" '
        $0 ~ "^  " k ":" { found=1 }
        found && /level: 0/ { sub(/level: 0/, "level: " v); found=0 }
        { print }
        ' "$PROGRESS" > "${PROGRESS}.tmp" && mv "${PROGRESS}.tmp" "$PROGRESS"
    fi
done

# Clean up any stray temp files
rm -f "${PROGRESS}.bak" "${PROGRESS}.tmp"

green ""
green "Migration complete!"
echo "  v1 backup: $BACKUP"
echo "  v2 progress: $PROGRESS"
echo ""
echo "Note: Competency levels are set conservatively (level 2 = practicing)"
echo "because the old format did not track hint usage or solution quality."
echo "Levels will adjust upward as you complete challenges in the new format."
