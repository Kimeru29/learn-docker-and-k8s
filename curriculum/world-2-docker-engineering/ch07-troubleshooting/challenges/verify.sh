#!/bin/bash
# Chapter 7 — The Debugging Grind: Verification Script
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -uo pipefail

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0

# ── Helpers ────────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$1"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$1"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$1"; }

pass() {
  green "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  red "  FAIL: $1"
  if [ -n "${2:-}" ]; then
    yellow "  HINT: $2"
  fi
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED=1
}

check() {
  local description="$1"
  local command="$2"
  local hint="${3:-}"

  if eval "$command" > /dev/null 2>&1; then
    pass "$description"
  else
    fail "$description" "$hint"
  fi
}

echo ""
yellow "=== Chapter 7: The Debugging Grind ==="
yellow "=== Verification Script ==="
echo ""

# ── Challenge 1: The Silent Crash ──────────────────────────────────────────────

echo "--- Challenge 1: The Silent Crash ---"
echo ""

# Look for API container from ch07
API_CONTAINER=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "api|ch07.*api" | head -1 || echo "")

if [ -z "$API_CONTAINER" ]; then
  API_CONTAINER=$(docker ps --filter "name=learn-ch07" --format '{{.Names}}' 2>/dev/null | grep -i "api" | head -1 || echo "")
fi

check_api_running() {
  [ -n "$API_CONTAINER" ] && docker inspect "$API_CONTAINER" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check_api_stable() {
  if [ -z "$API_CONTAINER" ]; then
    return 1
  fi
  # Check the container is running and has not restarted recently.
  # RestartCount == 0 means no crash-loops. This avoids cross-platform date parsing.
  local restarts
  restarts=$(docker inspect "$API_CONTAINER" --format '{{.RestartCount}}' 2>/dev/null || echo "99")
  [ "$restarts" -eq 0 ] 2>/dev/null
}

check \
  "API container is running (not crash-looping)" \
  "check_api_running" \
  "The API should be running. Fix the missing config file."

check \
  "API container is stable (no restarts)" \
  "check_api_stable" \
  "The container may be crash-looping. Check docker logs for the root cause."

check \
  "API /health endpoint responds on port 3000" \
  "curl -sf --max-time 5 http://localhost:3000/health | grep -q 'ok'" \
  "The API should respond on /health. Check docker logs for errors."

echo ""

# ── Challenge 2: The Memory Hog ───────────────────────────────────────────────

echo "--- Challenge 2: The Memory Hog ---"
echo ""

RECOMMENDER=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "recomm|leak" | head -1 || echo "")

if [ -z "$RECOMMENDER" ]; then
  RECOMMENDER=$(docker ps --filter "name=learn-ch07" --format '{{.Names}}' 2>/dev/null | grep -iE "recomm|leak" | head -1 || echo "")
fi

check_recommender_running() {
  [ -n "$RECOMMENDER" ] && docker inspect "$RECOMMENDER" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check_memory_limit() {
  if [ -z "$RECOMMENDER" ]; then
    return 1
  fi
  local mem
  mem=$(docker inspect "$RECOMMENDER" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
  # Must have a limit set (not 0 = unlimited)
  [ "$mem" != "0" ] && [ "$mem" != "" ]
}

check_reasonable_limit() {
  if [ -z "$RECOMMENDER" ]; then
    return 1
  fi
  local mem
  mem=$(docker inspect "$RECOMMENDER" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
  # Between 64MB (67108864) and 256MB (268435456)
  [ "$mem" -ge 67108864 ] 2>/dev/null && [ "$mem" -le 268435456 ] 2>/dev/null
}

check \
  "Recommender container is running" \
  "check_recommender_running" \
  "Build and start the recommender with a memory limit."

check \
  "Memory limit is configured (not unlimited)" \
  "check_memory_limit" \
  "Add deploy.resources.limits.memory to the recommender service."

check \
  "Memory limit is reasonable (64M-256M)" \
  "check_reasonable_limit" \
  "The memory limit should be between 64M and 256M."

echo ""

# ── Challenge 3: The Network Black Hole ────────────────────────────────────────

echo "--- Challenge 3: The Network Black Hole ---"
echo ""

BACKEND=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "backend" | head -1 || echo "")

if [ -z "$BACKEND" ]; then
  BACKEND=$(docker ps --filter "name=learn-ch07" --format '{{.Names}}' 2>/dev/null | grep -i "backend" | head -1 || echo "")
fi

POSTGRES=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "postgres" | head -1 || echo "")

if [ -z "$POSTGRES" ]; then
  POSTGRES=$(docker ps --filter "name=learn-ch07" --format '{{.Names}}' 2>/dev/null | grep -i "postgres" | head -1 || echo "")
fi

check_backend_running() {
  [ -n "$BACKEND" ] && docker inspect "$BACKEND" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check_postgres_healthy() {
  if [ -z "$POSTGRES" ]; then
    return 1
  fi
  local status
  status=$(docker inspect "$POSTGRES" --format '{{.State.Health.Status}}' 2>/dev/null || echo "none")
  [ "$status" = "healthy" ]
}

check_db_connected() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q "connected"
}

check \
  "Backend container is running" \
  "check_backend_running" \
  "Build and start the backend."

check \
  "Postgres is healthy" \
  "check_postgres_healthy" \
  "Postgres should be running with a health check."

check \
  "Backend can connect to Postgres (health returns 'connected')" \
  "check_db_connected" \
  "The backend must be on the same network as Postgres. Check network membership."

echo ""

# ── Challenge 4: The Stale Image ───────────────────────────────────────────────

echo "--- Challenge 4: The Stale Image ---"
echo ""

STALE_API=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "^learn-ch07.*api" | head -1 || echo "")

if [ -z "$STALE_API" ]; then
  STALE_API=$(docker ps --filter "name=learn-ch07" --format '{{.Names}}' 2>/dev/null | grep -i "api" | head -1 || echo "")
fi

check_stale_running() {
  [ -n "$STALE_API" ] && docker inspect "$STALE_API" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check_new_version() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q '"version":"2.0.0"'
}

check_fixed_typo() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q '"status"'
}

check \
  "API container is running" \
  "check_stale_running" \
  "Build and start the API."

check \
  "API returns version 2.0.0 (not 1.0.0)" \
  "check_new_version" \
  "The image might be stale. Did you rebuild with --build?"

check \
  "API returns 'status' (not 'staus' — the typo is fixed)" \
  "check_fixed_typo" \
  "The response should have the key 'status', not 'staus'. Rebuild the image."

echo ""

# ── Summary ────────────────────────────────────────────────────────────────────

TOTAL=$((PASS_COUNT + FAIL_COUNT))

if [ "$FAILED" -eq 0 ]; then
  green "============================================"
  green " All $TOTAL checks passed! Chapter 7 complete!"
  green "============================================"
  echo ""
  echo "You diagnosed silent crashes, memory hogs, network issues,"
  echo "and stale deployments. The 6-step debugging workflow is"
  echo "now part of your toolkit."
  echo ""
  echo "But then, the security audit arrived..."
  echo "See you in Chapter 8: The Audit."
  exit 0
else
  red "============================================"
  red " $FAIL_COUNT of $TOTAL checks failed."
  red "============================================"
  echo ""
  echo "$PASS_COUNT of $TOTAL checks passed."
  echo ""
  echo "Review the FAIL and HINT lines above, fix the issues, then run this script again."
  exit 1
fi
