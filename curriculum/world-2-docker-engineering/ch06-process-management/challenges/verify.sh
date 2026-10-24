#!/bin/bash
# Chapter 6 — The Zombie Barista: Verification Script
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
yellow "=== Chapter 6: The Zombie Barista ==="
yellow "=== Verification Script ==="
echo ""

# ── Challenge 1: Signal Handling ───────────────────────────────────────────────

echo "--- Challenge 1: Fix Signal Handling ---"
echo ""

# Find the worker container
WORKER_CONTAINER=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -i "worker" | head -1 || echo "")

if [ -z "$WORKER_CONTAINER" ]; then
  # Try compose project name
  WORKER_CONTAINER=$(docker ps --filter "name=learn-ch06" --format '{{.Names}}' 2>/dev/null | grep -i "worker" | head -1 || echo "")
fi

check_worker_running() {
  [ -n "$WORKER_CONTAINER" ] && docker inspect "$WORKER_CONTAINER" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check \
  "Worker container is running" \
  "check_worker_running" \
  "Build and start the worker: docker compose up -d"

# Check stop time
check_stop_time() {
  if [ -z "$WORKER_CONTAINER" ]; then
    return 1
  fi

  # Get the compose file directory
  local compose_dir=""
  for candidate in "$(pwd)/docker-compose.yml" "$(pwd)/../docker-compose.yml"; do
    if [ -f "$candidate" ]; then
      compose_dir="$(dirname "$candidate")"
      break
    fi
  done

  # Time the stop
  local start_time
  start_time=$(date +%s)
  docker stop "$WORKER_CONTAINER" --time 5 > /dev/null 2>&1
  local end_time
  end_time=$(date +%s)
  local elapsed=$((end_time - start_time))

  # Restart it for further checks
  docker start "$WORKER_CONTAINER" > /dev/null 2>&1 || true

  [ "$elapsed" -lt 3 ]
}

check_graceful_logs() {
  if [ -z "$WORKER_CONTAINER" ]; then
    return 1
  fi
  docker logs "$WORKER_CONTAINER" 2>&1 | grep -qi "sigterm\|graceful\|shut.*down\|cleaning"
}

check_pid1_exec_form() {
  if [ -z "$WORKER_CONTAINER" ]; then
    return 1
  fi
  # PID 1 should NOT be /bin/sh -c
  ! docker top "$WORKER_CONTAINER" 2>/dev/null | head -3 | grep -q "/bin/sh -c"
}

check \
  "PID 1 is NOT a shell wrapper (/bin/sh -c)" \
  "check_pid1_exec_form" \
  "Use exec form in CMD: CMD [\"node\", \"worker.js\"] instead of CMD node worker.js"

check \
  "docker stop completes in under 3 seconds" \
  "check_stop_time" \
  "The container should handle SIGTERM and exit quickly. Check CMD form and signal handlers."

check \
  "Container logs show graceful shutdown message" \
  "check_graceful_logs" \
  "The app should log a message when it receives SIGTERM."

echo ""

# ── Challenge 2: Zombie Cleanup ────────────────────────────────────────────────

echo "--- Challenge 2: Zombie Cleanup ---"
echo ""

SPAWNER_CONTAINER=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -i "spawn" | head -1 || echo "")

if [ -z "$SPAWNER_CONTAINER" ]; then
  SPAWNER_CONTAINER=$(docker ps --filter "name=learn-ch06" --format '{{.Names}}' 2>/dev/null | grep -i "spawn" | head -1 || echo "")
fi

check_spawner_running() {
  [ -n "$SPAWNER_CONTAINER" ] && docker inspect "$SPAWNER_CONTAINER" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check \
  "Spawner container is running" \
  "check_spawner_running" \
  "Build and start the spawner: docker compose up -d"

check_no_zombies() {
  if [ -z "$SPAWNER_CONTAINER" ]; then
    return 1
  fi
  # Wait a bit for processes to spawn and potentially become zombies
  sleep 5
  local zombie_count
  zombie_count=$(docker exec "$SPAWNER_CONTAINER" sh -c 'ps aux 2>/dev/null | grep -c "[d]efunct"' 2>/dev/null || echo "0")
  [ "$zombie_count" -lt 2 ]
}

check_orders_processing() {
  if [ -z "$SPAWNER_CONTAINER" ]; then
    return 1
  fi
  docker logs --tail 5 "$SPAWNER_CONTAINER" 2>&1 | grep -qi "order\|process"
}

check \
  "Spawner has no (or minimal) zombie processes" \
  "check_no_zombies" \
  "Use 'init: true' in Compose, or install tini, or fix the script to reap children with wait."

check \
  "Spawner is still processing orders" \
  "check_orders_processing" \
  "The spawner should still be running and processing orders. Check docker logs."

echo ""

# ── Challenge 3: ENTRYPOINT Puzzle ─────────────────────────────────────────────

echo "--- Challenge 3: ENTRYPOINT Puzzle ---"
echo ""

API_CONTAINER=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -i "api" | head -1 || echo "")

if [ -z "$API_CONTAINER" ]; then
  API_CONTAINER=$(docker ps --filter "name=learn-ch06" --format '{{.Names}}' 2>/dev/null | grep -i "api" | head -1 || echo "")
fi

check_api_running() {
  [ -n "$API_CONTAINER" ] && docker inspect "$API_CONTAINER" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check \
  "API container is running" \
  "check_api_running" \
  "Build and start the API: docker compose up -d"

check_api_responds() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q "ok"
}

check \
  "API responds on /health endpoint" \
  "check_api_responds" \
  "The API should be accessible on port 3000."

check_migrations_ran() {
  if [ -z "$API_CONTAINER" ]; then
    return 1
  fi
  docker logs "$API_CONTAINER" 2>&1 | grep -qi "migration\|entrypoint"
}

check \
  "Entrypoint script executed (migrations ran)" \
  "check_migrations_ran" \
  "The entrypoint script should run and log migration messages. Check if ENTRYPOINT is exec form."

check_api_pid1() {
  if [ -z "$API_CONTAINER" ]; then
    return 1
  fi
  ! docker top "$API_CONTAINER" 2>/dev/null | head -3 | grep -q "/bin/sh -c"
}

check \
  "API PID 1 is NOT a shell wrapper" \
  "check_api_pid1" \
  "Use exec form ENTRYPOINT and exec \"\$@\" in the entrypoint script."

check_api_stop_time() {
  if [ -z "$API_CONTAINER" ]; then
    return 1
  fi
  local start_time
  start_time=$(date +%s)
  docker stop "$API_CONTAINER" --time 5 > /dev/null 2>&1
  local end_time
  end_time=$(date +%s)
  local elapsed=$((end_time - start_time))

  docker start "$API_CONTAINER" > /dev/null 2>&1 || true

  [ "$elapsed" -lt 3 ]
}

check \
  "API container stops gracefully (under 3 seconds)" \
  "check_api_stop_time" \
  "The entrypoint script should use 'exec \"\$@\"' so the app becomes PID 1 and receives SIGTERM."

echo ""

# ── Summary ────────────────────────────────────────────────────────────────────

TOTAL=$((PASS_COUNT + FAIL_COUNT))

if [ "$FAILED" -eq 0 ]; then
  green "============================================"
  green " All $TOTAL checks passed! Chapter 6 complete!"
  green "============================================"
  echo ""
  echo "No more 10-second stops. No more zombies."
  echo "Your containers handle signals properly and clean up after themselves."
  echo ""
  echo "But on Monday, a container starts crashing and you don't know why..."
  echo "See you in Chapter 7: The Debugging Grind."
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
