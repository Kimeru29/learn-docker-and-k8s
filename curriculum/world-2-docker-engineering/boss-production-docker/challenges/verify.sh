#!/bin/bash
# Boss Fight — The Full Stack Meltdown: Verification Script
# Each problem is verified independently — partial credit is possible.
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
cyan()   { printf '\033[0;36m%s\033[0m\n' "$1"; }

pass() {
  green "  ✅ PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  red "  ❌ FAIL: $1"
  if [ -n "${2:-}" ]; then
    yellow "  💡 HINT: $2"
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
cyan "╔══════════════════════════════════════════════════════╗"
cyan "║                                                      ║"
cyan "║      BOSS FIGHT: THE FULL STACK MELTDOWN             ║"
cyan "║      Verification Script                             ║"
cyan "║                                                      ║"
cyan "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Find containers ────────────────────────────────────────────────────────────

API=$(docker ps -a --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "boss.*api|api" | grep -iv "frontend" | head -1 || echo "")
WORKER=$(docker ps -a --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "worker" | head -1 || echo "")
FRONTEND=$(docker ps -a --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "frontend" | head -1 || echo "")
POSTGRES=$(docker ps -a --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "postgres" | head -1 || echo "")

# Fallback to project name
if [ -z "$API" ]; then
  API=$(docker ps -a --filter "name=learn-boss" --format '{{.Names}}' 2>/dev/null | grep -i "api" | grep -iv "frontend" | head -1 || echo "")
fi
if [ -z "$WORKER" ]; then
  WORKER=$(docker ps -a --filter "name=learn-boss" --format '{{.Names}}' 2>/dev/null | grep -i "worker" | head -1 || echo "")
fi
if [ -z "$FRONTEND" ]; then
  FRONTEND=$(docker ps -a --filter "name=learn-boss" --format '{{.Names}}' 2>/dev/null | grep -i "frontend" | head -1 || echo "")
fi
if [ -z "$POSTGRES" ]; then
  POSTGRES=$(docker ps -a --filter "name=learn-boss" --format '{{.Names}}' 2>/dev/null | grep -i "postgres" | head -1 || echo "")
fi

# ── Problem 1: Signal Handling ─────────────────────────────────────────────────

echo ""
yellow "--- Problem 1: API Signal Handling (Ch06) ---"
echo ""

check_api_running() {
  [ -n "$API" ] && docker inspect "$API" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check \
  "API container is running" \
  "check_api_running" \
  "Build and start the stack: docker compose up -d --build"

check_pid1_not_shell() {
  if [ -z "$API" ]; then return 1; fi
  ! docker top "$API" 2>/dev/null | head -3 | grep -q "/bin/sh -c"
}

check \
  "API PID 1 is NOT a shell wrapper" \
  "check_pid1_not_shell" \
  "Change CMD in api/Dockerfile from shell form to exec form: CMD [\"node\", \"server.js\"]"

check_api_stop_time() {
  if [ -z "$API" ]; then return 1; fi
  local start_time end_time elapsed
  start_time=$(date +%s)
  docker stop "$API" --time 5 > /dev/null 2>&1
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  # Restart it
  docker start "$API" > /dev/null 2>&1 || true
  sleep 2
  [ "$elapsed" -lt 4 ]
}

check \
  "API stops gracefully in under 4 seconds" \
  "check_api_stop_time" \
  "Use exec form CMD so the app receives SIGTERM directly."

# ── Problem 2: Worker Memory Limit ─────────────────────────────────────────────

echo ""
yellow "--- Problem 2: Worker Memory Limit (Ch07) ---"
echo ""

check_worker_exists() {
  [ -n "$WORKER" ]
}

check \
  "Worker container exists" \
  "check_worker_exists" \
  "The worker service should be defined in docker-compose.yml"

check_worker_memory_limit() {
  if [ -z "$WORKER" ]; then return 1; fi
  local mem
  mem=$(docker inspect "$WORKER" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
  [ "$mem" != "0" ] && [ "$mem" != "" ]
}

check_worker_reasonable_limit() {
  if [ -z "$WORKER" ]; then return 1; fi
  local mem
  mem=$(docker inspect "$WORKER" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
  # Between 64MB and 256MB
  [ "$mem" -ge 67108864 ] 2>/dev/null && [ "$mem" -le 268435456 ] 2>/dev/null
}

check \
  "Worker has a memory limit configured" \
  "check_worker_memory_limit" \
  "Add deploy.resources.limits.memory to the worker service."

check \
  "Worker memory limit is reasonable (64M-256M)" \
  "check_worker_reasonable_limit" \
  "Set the worker memory limit between 64M and 256M."

# ── Problem 3: Credentials in Image History ────────────────────────────────────

echo ""
yellow "--- Problem 3: Credentials in Image (Ch08) ---"
echo ""

check_no_password_in_history() {
  local api_image
  if [ -n "$API" ]; then
    api_image=$(docker inspect "$API" --format '{{.Config.Image}}' 2>/dev/null || echo "")
  fi
  if [ -z "$api_image" ]; then
    api_image="learn-boss-api"
  fi
  # Check docker history for password strings
  ! docker history "$api_image" --no-trunc 2>/dev/null | grep -iE "password|nocap_prod|secret"
}

check \
  "No passwords visible in API image history" \
  "check_no_password_in_history" \
  "Remove the ENV DB_PASSWORD line from api/Dockerfile. Inject at runtime."

check_api_db_configured() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q "db_configured.*true\|db_configured\":true"
}

check \
  "API reports database is configured (runtime injection works)" \
  "check_api_db_configured" \
  "Pass DB_PASSWORD through docker-compose.yml environment using a .env file."

# ── Problem 4: Bloated Frontend Image ──────────────────────────────────────────

echo ""
yellow "--- Problem 4: Frontend Image Size (Ch02/Ch08) ---"
echo ""

check_frontend_running() {
  [ -n "$FRONTEND" ] && docker inspect "$FRONTEND" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check \
  "Frontend container is running" \
  "check_frontend_running" \
  "Build and start the frontend."

check_frontend_responds() {
  curl -sf --max-time 5 http://localhost:8080 2>/dev/null | grep -qi "nocappuccino\|coffee"
}

check \
  "Frontend responds on port 8080" \
  "check_frontend_responds" \
  "The frontend should serve HTML on port 8080."

check_frontend_image_size() {
  local frontend_image
  if [ -n "$FRONTEND" ]; then
    frontend_image=$(docker inspect "$FRONTEND" --format '{{.Image}}' 2>/dev/null || echo "")
  fi
  if [ -z "$frontend_image" ]; then
    # Try by name
    frontend_image=$(docker images "learn-boss-frontend" --format '{{.ID}}' 2>/dev/null | head -1 || echo "")
  fi
  if [ -z "$frontend_image" ]; then
    return 1
  fi
  local size_bytes
  size_bytes=$(docker inspect "$frontend_image" --format '{{.Size}}' 2>/dev/null || echo "999999999")
  # Must be under 50MB (52428800 bytes)
  [ "$size_bytes" -lt 52428800 ] 2>/dev/null
}

check \
  "Frontend image is under 50 MB" \
  "check_frontend_image_size" \
  "Replace the ubuntu+apache Dockerfile with nginx:alpine. Just COPY the HTML."

# ── Problem 5: Network Configuration ──────────────────────────────────────────

echo ""
yellow "--- Problem 5: Network Configuration (Ch04/Ch05) ---"
echo ""

check_postgres_healthy() {
  if [ -z "$POSTGRES" ]; then return 1; fi
  local status
  status=$(docker inspect "$POSTGRES" --format '{{.State.Health.Status}}' 2>/dev/null || echo "none")
  [ "$status" = "healthy" ]
}

check \
  "Postgres is running and healthy" \
  "check_postgres_healthy" \
  "Postgres should be running with a health check."

check_api_on_backend_net() {
  if [ -z "$API" ]; then return 1; fi
  docker inspect "$API" --format '{{json .NetworkSettings.Networks}}' 2>/dev/null | grep -qi "backend"
}

check \
  "API is on backend network (can reach Postgres)" \
  "check_api_on_backend_net" \
  "Add backend-net to the API service's networks list."

check_api_health_db() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q "ok"
}

check \
  "API /health endpoint responds" \
  "check_api_health_db" \
  "The API should be accessible on port 3000 and report status ok."

echo ""

# ── Final Summary ─────────────────────────────────────────────────────────────

TOTAL=$((PASS_COUNT + FAIL_COUNT))

echo ""

if [ "$FAILED" -eq 0 ]; then
  cyan "╔══════════════════════════════════════════════════════╗"
  cyan "║                                                      ║"
  green "║   🏆 ALL $TOTAL CHECKS PASSED — BOSS DEFEATED!          ║"
  cyan "║                                                      ║"
  cyan "║   The Full Stack Meltdown is over.                   ║"
  cyan "║   NoCappuccino survived the traffic spike.           ║"
  cyan "║                                                      ║"
  cyan "║   World 2: Docker Engineering — COMPLETE             ║"
  cyan "║                                                      ║"
  cyan "╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "  You fixed:"
  echo "    ✅ Signal handling — graceful shutdown in <4 seconds"
  echo "    ✅ Memory limits — worker can't eat all host memory"
  echo "    ✅ Image security — no credentials in layers"
  echo "    ✅ Image size — frontend from 3GB to <50MB"
  echo "    ✅ Networking — all services can communicate"
  echo ""
  echo "  Dave: (ˊ_>ˋ) 'See? I told you containers would work out.'"
  echo "  Sarah: (★‿★) 'You handled that like a pro.'"
  echo "  Marcus: (⊙_⊙) 'Wait, that actually worked?'"
  echo ""
  echo "  Next: World 3 — Kubernetes Core"
  echo "  'One machine isn't going to cut it anymore.'"
  echo ""
  exit 0
else
  red "╔══════════════════════════════════════════════════════╗"
  red "║                                                      ║"
  red "║   $FAIL_COUNT of $TOTAL checks failed.                        ║"
  red "║   $PASS_COUNT of $TOTAL checks passed.                        ║"
  red "║                                                      ║"
  red "║   Keep going — each fix is independent.              ║"
  red "║                                                      ║"
  red "╚══════════════════════════════════════════════════════╝"
  echo ""
  echo "  Review the ❌ FAIL and 💡 HINT lines above."
  echo "  Fix one problem at a time, rebuild, and run this script again."
  echo ""
  exit 1
fi
