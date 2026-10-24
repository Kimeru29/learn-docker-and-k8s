#!/bin/bash
# Chapter 5 — The Symphony of Steam: Verification Script (World 2)
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

# ── Locate the compose file ────────────────────────────────────────────────────

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

if [ -z "$COMPOSE_FILE" ]; then
  echo ""
  red "=== Chapter 5 Verification ==="
  echo ""
  fail "docker-compose.yml not found" \
    "Create docker-compose.yml in the challenges/ directory or the ch05-compose/ directory."
  echo ""
  red "Verification failed: no Compose file found."
  exit 1
fi

COMPOSE_DIR="$(dirname "$COMPOSE_FILE")"

echo ""
yellow "=== Chapter 5: The Symphony of Steam ==="
yellow "=== Verification Script (World 2) ==="
echo ""
echo "Using Compose file: $COMPOSE_FILE"
echo ""

# ── Challenge 1 checks: All four services running ─────────────────────────────

echo "--- Challenge 1: Full Stack ---"
echo ""

running_services() {
  local service="$1"
  docker compose -f "$COMPOSE_FILE" ps --status running --services 2>/dev/null | grep -q "^${service}$"
}

check \
  "Service 'postgres' is running" \
  "running_services postgres" \
  "Make sure postgres is defined in your docker-compose.yml and docker compose up -d has been run."

check \
  "Service 'redis' is running" \
  "running_services redis" \
  "Make sure redis is defined in your docker-compose.yml."

check \
  "Service 'backend' is running" \
  "running_services backend" \
  "The backend may have crashed on startup. Check: docker compose logs backend"

check \
  "Service 'frontend' is running" \
  "running_services frontend" \
  "Make sure frontend is defined with the correct build path."

check \
  "Frontend accessible on port 8080" \
  "curl -sf --max-time 5 http://localhost:8080 | grep -qi 'cloudbrew\|nocappuccino'" \
  "Is port 8080 mapped in your frontend service? Check: ports: ['8080:80']"

check \
  "Backend /health endpoint responds" \
  "curl -sf --max-time 5 http://localhost:3000/health | grep -q 'ok'" \
  "Is port 3000 mapped? Check: docker compose logs backend"

check \
  "Backend /api/coffees endpoint responds" \
  "curl -sf --max-time 5 http://localhost:3000/api/coffees | grep -q 'source'" \
  "The backend may not be connected to Postgres or Redis. Check: docker compose logs backend"

echo ""

# ── Challenge 2 checks: Health checks ─────────────────────────────────────────

echo "--- Challenge 2: Health Checks ---"
echo ""

postgres_container() {
  docker compose -f "$COMPOSE_FILE" ps -q postgres 2>/dev/null | head -1
}

redis_container() {
  docker compose -f "$COMPOSE_FILE" ps -q redis 2>/dev/null | head -1
}

check_health() {
  local service="$1"
  local get_id_fn="$2"
  local container_id
  container_id=$(eval "$get_id_fn")
  if [ -z "$container_id" ]; then
    return 1
  fi
  local status
  status=$(docker inspect "$container_id" --format '{{.State.Health.Status}}' 2>/dev/null || echo "none")
  [ "$status" = "healthy" ]
}

check \
  "Postgres has a health check configured and is 'healthy'" \
  "check_health postgres postgres_container" \
  "Add a healthcheck: block to the postgres service using pg_isready. Wait for it to become healthy."

check \
  "Redis has a health check configured and is 'healthy'" \
  "check_health redis redis_container" \
  "Add a healthcheck: block to the redis service using redis-cli ping."

check \
  "docker-compose.yml uses 'service_healthy' condition for backend depends_on" \
  "grep -q 'service_healthy' '$COMPOSE_FILE'" \
  "Update backend's depends_on to use 'condition: service_healthy' for postgres and redis."

echo ""

# ── Challenge 3 checks: Secrets and profiles ──────────────────────────────────

echo "--- Challenge 3: Secrets and Profiles ---"
echo ""

check \
  "docker-compose.yml contains no hardcoded passwords (no literal 'password' values)" \
  "! grep -iE '^\s*[^#].*(password|secret|passwd):\s+[^$\{][^\s]+' '$COMPOSE_FILE'" \
  "Move secrets to a .env file. Use \${VARIABLE_NAME} references in docker-compose.yml instead."

ENV_FILE=""
for candidate in \
  "$COMPOSE_DIR/.env" \
  "$COMPOSE_DIR/../.env"
do
  if [ -f "$candidate" ]; then
    ENV_FILE="$candidate"
    break
  fi
done

check \
  ".env file exists" \
  "[ -n '$ENV_FILE' ] && [ -f '$ENV_FILE' ]" \
  "Create a .env file in the same directory as your docker-compose.yml with your secret values."

ENV_EXAMPLE=""
for candidate in \
  "$COMPOSE_DIR/.env.example" \
  "$COMPOSE_DIR/../.env.example"
do
  if [ -f "$candidate" ]; then
    ENV_EXAMPLE="$candidate"
    break
  fi
done

check \
  ".env.example file exists" \
  "[ -n '$ENV_EXAMPLE' ] && [ -f '$ENV_EXAMPLE' ]" \
  "Create a .env.example file with placeholder values so other developers know what to configure."

check \
  "docker-compose.yml defines a 'dev' profile" \
  "grep -q 'profiles:' '$COMPOSE_FILE' && grep -A2 'profiles:' '$COMPOSE_FILE' | grep -q '\- dev'" \
  "Add a service (e.g. adminer) with 'profiles: [dev]' to your docker-compose.yml."

check \
  "docker-compose.yml defines a 'test' profile" \
  "grep -q 'profiles:' '$COMPOSE_FILE' && grep -A2 'profiles:' '$COMPOSE_FILE' | grep -q '\- test'" \
  "Add a test-runner service with 'profiles: [test]' to your docker-compose.yml."

check \
  "adminer service starts with --profile dev" \
  "docker compose -f '$COMPOSE_FILE' --profile dev config --services 2>/dev/null | grep -q 'adminer'" \
  "Make sure your adminer service has 'profiles: [dev]' and is defined in docker-compose.yml."

echo ""

# ── Challenge 4 checks: Production Compose ─────────────────────────────────────

echo "--- Challenge 4: Production Compose ---"
echo ""

# Check resource limits
check_memory_limit() {
  local service="$1"
  local container_id
  container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null | head -1)
  if [ -z "$container_id" ]; then
    return 1
  fi
  local mem
  mem=$(docker inspect "$container_id" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
  [ "$mem" != "0" ] && [ "$mem" != "" ]
}

check \
  "Backend has memory limits configured" \
  "check_memory_limit backend" \
  "Add deploy.resources.limits.memory to the backend service."

check \
  "Postgres has memory limits configured" \
  "check_memory_limit postgres" \
  "Add deploy.resources.limits.memory to the postgres service."

check \
  "Redis has memory limits configured" \
  "check_memory_limit redis" \
  "Add deploy.resources.limits.memory to the redis service."

check \
  "Frontend has memory limits configured" \
  "check_memory_limit frontend" \
  "Add deploy.resources.limits.memory to the frontend service."

# Check logging configuration
check_log_config() {
  local service="$1"
  local container_id
  container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null | head -1)
  if [ -z "$container_id" ]; then
    return 1
  fi
  local max_size
  max_size=$(docker inspect "$container_id" --format '{{index .HostConfig.LogConfig.Config "max-size"}}' 2>/dev/null || echo "")
  [ -n "$max_size" ] && [ "$max_size" != "" ] && [ "$max_size" != "<no value>" ]
}

check \
  "Backend has log rotation configured" \
  "check_log_config backend" \
  "Add logging.options.max-size to the backend service."

check \
  "Postgres has log rotation configured" \
  "check_log_config postgres" \
  "Add logging config to all services. Use YAML anchors to avoid duplication."

# Check network isolation
check_network_exists() {
  local network_suffix="$1"
  docker compose -f "$COMPOSE_FILE" config --services > /dev/null 2>&1
  # Check for network containing the suffix in the compose project
  docker network ls --format '{{.Name}}' 2>/dev/null | grep -q "$network_suffix"
}

check_container_network() {
  local service="$1"
  local network_suffix="$2"
  local container_id
  container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null | head -1)
  if [ -z "$container_id" ]; then
    return 1
  fi
  docker inspect "$container_id" --format '{{json .NetworkSettings.Networks}}' 2>/dev/null | grep -qi "$network_suffix"
}

check_container_not_on_network() {
  local service="$1"
  local network_suffix="$2"
  local container_id
  container_id=$(docker compose -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null | head -1)
  if [ -z "$container_id" ]; then
    return 1
  fi
  ! docker inspect "$container_id" --format '{{json .NetworkSettings.Networks}}' 2>/dev/null | grep -qi "$network_suffix"
}

check \
  "Two separate networks exist (frontend-net and backend-net)" \
  "grep -q 'frontend-net' '$COMPOSE_FILE' && grep -q 'backend-net' '$COMPOSE_FILE'" \
  "Define two networks: frontend-net (frontend + backend) and backend-net (backend + postgres + redis)."

check \
  "Frontend is NOT on backend-net" \
  "check_container_not_on_network frontend backend" \
  "The frontend should only be on frontend-net, not backend-net."

check \
  "Postgres is NOT on frontend-net" \
  "check_container_not_on_network postgres frontend" \
  "Postgres should only be on backend-net, not frontend-net."

check \
  "Backend is on both networks" \
  "check_container_network backend frontend && check_container_network backend backend" \
  "The backend bridges both tiers — it must be on both frontend-net and backend-net."

# Check override file
OVERRIDE_FILE=""
for candidate in \
  "$COMPOSE_DIR/docker-compose.override.yml" \
  "$COMPOSE_DIR/../docker-compose.override.yml"
do
  if [ -f "$candidate" ]; then
    OVERRIDE_FILE="$candidate"
    break
  fi
done

check \
  "docker-compose.override.yml exists" \
  "[ -n '$OVERRIDE_FILE' ] && [ -f '$OVERRIDE_FILE' ]" \
  "Create a docker-compose.override.yml for development-specific configuration (ports, debug settings)."

if [ -n "$OVERRIDE_FILE" ] && [ -f "$OVERRIDE_FILE" ]; then
  check \
    "Override file contains port mappings" \
    "grep -q 'ports' '$OVERRIDE_FILE'" \
    "Port mappings should be in the override file, not the base docker-compose.yml."
fi

echo ""

# ── Resource labeling check ────────────────────────────────────────────────────

echo "--- Resource Labels ---"
echo ""

check \
  "docker-compose.yml uses 'learn-docker-k8s' app label" \
  "grep -q 'learn-docker-k8s' '$COMPOSE_FILE'" \
  "Add labels to your services: app: learn-docker-k8s"

check \
  "docker-compose.yml uses world label" \
  "grep -qE 'ch05|w02' '$COMPOSE_FILE'" \
  "Add labels to your services: world: w02 (or chapter: ch05)"

echo ""

# ── Summary ────────────────────────────────────────────────────────────────────

TOTAL=$((PASS_COUNT + FAIL_COUNT))

if [ "$FAILED" -eq 0 ]; then
  green "============================================"
  green " All $TOTAL checks passed! Chapter 5 complete!"
  green "============================================"
  echo ""
  echo "You built a complete, production-grade Docker Compose stack for"
  echo "NoCappuccino — with health checks, secrets, resource limits,"
  echo "network isolation, and environment-specific configuration."
  echo ""
  echo "Something's wrong with the containers though. They take forever"
  echo "to stop, and docker top shows mystery processes..."
  echo ""
  echo "See you in Chapter 6: The Zombie Barista."
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
