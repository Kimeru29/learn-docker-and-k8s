#!/bin/bash
# Chapter 8 — The Audit: Verification Script
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
yellow "=== Chapter 8: The Audit ==="
yellow "=== Verification Script ==="
echo ""

# ── Locate compose file ───────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE=""

for candidate in \
  "$SCRIPT_DIR/docker-compose.yml" \
  "$SCRIPT_DIR/../docker-compose.yml" \
  "$(pwd)/docker-compose.yml"
do
  if [ -f "$candidate" ]; then
    COMPOSE_FILE="$candidate"
    break
  fi
done

COMPOSE_DIR=""
if [ -n "$COMPOSE_FILE" ]; then
  COMPOSE_DIR="$(dirname "$COMPOSE_FILE")"
fi

# ── Challenge 1: Harden the Container ─────────────────────────────────────────

echo "--- Challenge 1: Harden the Container ---"
echo ""

# Find API container
API_CONTAINER=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "api" | head -1 || echo "")

if [ -z "$API_CONTAINER" ]; then
  API_CONTAINER=$(docker ps --filter "name=learn-ch08" --format '{{.Names}}' 2>/dev/null | grep -i "api" | head -1 || echo "")
fi

check_api_responds() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q "ok"
}

check \
  "API container responds on /health" \
  "check_api_responds" \
  "Build and start the API: docker compose up -d"

check_not_root() {
  if [ -z "$API_CONTAINER" ]; then
    return 1
  fi
  local uid
  uid=$(docker exec "$API_CONTAINER" id -u 2>/dev/null || echo "0")
  [ "$uid" != "0" ]
}

check \
  "API container runs as non-root (UID != 0)" \
  "check_not_root" \
  "Add USER instruction to Dockerfile or user: in docker-compose.yml"

check_caps_dropped() {
  if [ -z "$API_CONTAINER" ]; then
    return 1
  fi
  local cap_drop
  cap_drop=$(docker inspect "$API_CONTAINER" --format '{{json .HostConfig.CapDrop}}' 2>/dev/null || echo "null")
  echo "$cap_drop" | grep -qi "all"
}

check \
  "All capabilities dropped (cap_drop: ALL)" \
  "check_caps_dropped" \
  "Add cap_drop: [ALL] to the API service in docker-compose.yml"

check_read_only() {
  if [ -z "$API_CONTAINER" ]; then
    return 1
  fi
  docker inspect "$API_CONTAINER" --format '{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null | grep -q "true"
}

check \
  "Root filesystem is read-only" \
  "check_read_only" \
  "Add read_only: true to the API service. Use tmpfs for writable directories."

echo ""

# ── Challenge 2: Clean the Layers ─────────────────────────────────────────────

echo "--- Challenge 2: Clean the Layers ---"
echo ""

# Check for the API image
API_IMAGE=$(docker images --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | head -1 || echo "")

if [ -z "$API_IMAGE" ]; then
  API_IMAGE=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -i "learn-ch08" | head -1 || echo "")
fi

check_no_secret_in_history() {
  if [ -z "$API_IMAGE" ]; then
    # Try to find the image from the container
    if [ -n "$API_CONTAINER" ]; then
      API_IMAGE=$(docker inspect "$API_CONTAINER" --format '{{.Config.Image}}' 2>/dev/null || echo "")
    fi
  fi
  if [ -z "$API_IMAGE" ]; then
    return 1
  fi
  ! docker history "$API_IMAGE" --no-trunc 2>/dev/null | grep -iE "password|secret|p@ss"
}

check \
  "No passwords visible in docker history" \
  "check_no_secret_in_history" \
  "Remove ENV DB_PASSWORD from the Dockerfile. Inject secrets at runtime."

# Check .dockerignore exists
DOCKERIGNORE=""
for candidate in \
  "$SCRIPT_DIR/.dockerignore" \
  "$SCRIPT_DIR/../.dockerignore" \
  "$(pwd)/.dockerignore"
do
  if [ -f "$candidate" ]; then
    DOCKERIGNORE="$candidate"
    break
  fi
done

check \
  ".dockerignore file exists" \
  "[ -n '$DOCKERIGNORE' ] && [ -f '$DOCKERIGNORE' ]" \
  "Create a .dockerignore that excludes secrets.env, .env, and other sensitive files."

if [ -n "$DOCKERIGNORE" ] && [ -f "$DOCKERIGNORE" ]; then
  check \
    ".dockerignore excludes secrets.env" \
    "grep -q 'secrets.env\|*.env\|.env' '$DOCKERIGNORE'" \
    "Add secrets.env to your .dockerignore file."
fi

check_db_configured() {
  curl -sf --max-time 5 http://localhost:3000/health 2>/dev/null | grep -q "db_configured.*true\|db_configured\":true"
}

check \
  "API reports database is configured (password set at runtime)" \
  "check_db_configured" \
  "Pass DB_PASSWORD through docker-compose.yml environment using \${DB_PASSWORD} from .env"

echo ""

# ── Challenge 3: Least Privilege ───────────────────────────────────────────────

echo "--- Challenge 3: Least Privilege ---"
echo ""

# Check for multi-service stack
BACKEND=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "backend" | head -1 || echo "")
FRONTEND=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "frontend" | head -1 || echo "")
REDIS=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "redis" | head -1 || echo "")
POSTGRES=$(docker ps --filter "label=app=learn-docker-k8s" --filter "label=world=w02" --format '{{.Names}}' 2>/dev/null | grep -iE "postgres" | head -1 || echo "")

check_service_running() {
  local container="$1"
  [ -n "$container" ] && docker inspect "$container" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"
}

check \
  "Backend service is running" \
  "check_service_running '$BACKEND'" \
  "Start the full stack: docker compose up -d"

check \
  "Frontend service is running" \
  "check_service_running '$FRONTEND'" \
  "Ensure frontend is defined in your docker-compose.yml"

check \
  "Redis service is running" \
  "check_service_running '$REDIS'" \
  "Ensure redis is defined in your docker-compose.yml"

check \
  "Postgres service is running" \
  "check_service_running '$POSTGRES'" \
  "Ensure postgres is defined in your docker-compose.yml"

# Check backend non-root
check_backend_nonroot() {
  if [ -z "$BACKEND" ]; then
    return 1
  fi
  local uid
  uid=$(docker exec "$BACKEND" id -u 2>/dev/null || echo "0")
  [ "$uid" != "0" ]
}

check \
  "Backend runs as non-root" \
  "check_backend_nonroot" \
  "Set user: '1000:1000' or similar on the backend service."

# Check network isolation
check_frontend_not_on_backend() {
  if [ -z "$FRONTEND" ]; then
    return 1
  fi
  ! docker inspect "$FRONTEND" --format '{{json .NetworkSettings.Networks}}' 2>/dev/null | grep -qi "backend"
}

check_postgres_not_on_frontend() {
  if [ -z "$POSTGRES" ]; then
    return 1
  fi
  ! docker inspect "$POSTGRES" --format '{{json .NetworkSettings.Networks}}' 2>/dev/null | grep -qi "frontend"
}

check \
  "Frontend is NOT on backend network" \
  "check_frontend_not_on_backend" \
  "The frontend should only be on frontend-net, not backend-net."

check \
  "Postgres is NOT on frontend network" \
  "check_postgres_not_on_frontend" \
  "Postgres should only be on backend-net, not frontend-net."

# Check memory limits on services
check_service_memory_limit() {
  local container="$1"
  if [ -z "$container" ]; then
    return 1
  fi
  local mem
  mem=$(docker inspect "$container" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
  [ "$mem" != "0" ] && [ "$mem" != "" ]
}

check \
  "Backend has memory limits" \
  "check_service_memory_limit '$BACKEND'" \
  "Add deploy.resources.limits.memory to the backend service."

check \
  "Redis has memory limits" \
  "check_service_memory_limit '$REDIS'" \
  "Add deploy.resources.limits.memory to the redis service."

check \
  "Postgres has memory limits" \
  "check_service_memory_limit '$POSTGRES'" \
  "Add deploy.resources.limits.memory to the postgres service."

# Check capabilities dropped on backend
check_backend_caps() {
  if [ -z "$BACKEND" ]; then
    return 1
  fi
  docker inspect "$BACKEND" --format '{{json .HostConfig.CapDrop}}' 2>/dev/null | grep -qi "all"
}

check \
  "Backend has all capabilities dropped" \
  "check_backend_caps" \
  "Add cap_drop: [ALL] to the backend service."

echo ""

# ── Summary ────────────────────────────────────────────────────────────────────

TOTAL=$((PASS_COUNT + FAIL_COUNT))

if [ "$FAILED" -eq 0 ]; then
  green "============================================"
  green " All $TOTAL checks passed! Chapter 8 complete!"
  green "============================================"
  echo ""
  echo "The audit is resolved. Your containers are hardened:"
  echo "  - Non-root users"
  echo "  - No leaked secrets"
  echo "  - Dropped capabilities"
  echo "  - Network isolation"
  echo "  - Resource limits"
  echo ""
  echo "One last test remains: the Full Stack Meltdown."
  echo "See you at the Boss Fight."
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
