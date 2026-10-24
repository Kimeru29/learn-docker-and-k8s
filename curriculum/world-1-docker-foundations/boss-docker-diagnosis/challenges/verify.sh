#!/bin/bash
# Boss Fight Verification Script — The Morning From Hell
# Checks all four problems independently
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

set -u

PASSED=0
FAILED=0

# --- Helpers ----------------------------------------------------------------

green()  { printf "\033[0;32m%s\033[0m\n" "$*"; }
red()    { printf "\033[0;31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[0;33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

pass() {
    green "  PASS: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    red "  FAIL: $1"
    if [ -n "${2:-}" ]; then
        yellow "  HINT: $2"
    fi
    FAILED=$((FAILED + 1))
}

check() {
    local description="$1"
    local hint="${3:-}"
    if eval "$2" > /dev/null 2>&1; then
        pass "$description"
    else
        fail "$description" "$hint"
    fi
}

echo ""
bold "=========================================="
bold "  BOSS FIGHT: The Morning From Hell"
bold "  World 1 Final Verification"
bold "=========================================="
echo ""

# --- Problem 1: Bloated Image -----------------------------------------------

bold "[Problem 1: The Bloated Build]"
echo ""

# Check: optimized image exists
check \
    "Image 'learn-boss-app:optimized' exists" \
    "docker image inspect learn-boss-app:optimized" \
    "Build with: docker build -t learn-boss-app:optimized ."

# Check: image is under 100MB (104857600 bytes)
if docker image inspect learn-boss-app:optimized > /dev/null 2>&1; then
    IMAGE_SIZE=$(docker image inspect learn-boss-app:optimized --format '{{.Size}}')
    IMAGE_SIZE_MB=$(echo "scale=1; $IMAGE_SIZE / 1048576" | bc 2>/dev/null || echo "unknown")

    if [ "$IMAGE_SIZE" -lt 104857600 ]; then
        pass "Image size is under 100MB (actual: ${IMAGE_SIZE_MB}MB)"
    else
        fail "Image size is ${IMAGE_SIZE_MB}MB -- must be under 100MB" \
             "Use a multi-stage build with alpine as the final stage"
    fi
else
    fail "Cannot check image size -- image does not exist"
fi

# Check: container starts and responds
if docker image inspect learn-boss-app:optimized > /dev/null 2>&1; then
    docker rm -f learn-boss-verify-app > /dev/null 2>&1 || true
    CONTAINER_ID=$(docker run -d -p 0:8080 \
        --label app=learn-docker-k8s \
        --label world=w01 \
        --label chapter=boss \
        --name learn-boss-verify-app \
        learn-boss-app:optimized 2>/dev/null || echo "")

    if [ -n "$CONTAINER_ID" ]; then
        ASSIGNED_PORT=$(docker port learn-boss-verify-app 8080/tcp 2>/dev/null | head -1 | cut -d: -f2 || echo "")
        sleep 2
        if [ -n "$ASSIGNED_PORT" ] && curl -sf "http://localhost:${ASSIGNED_PORT}/health" > /dev/null 2>&1; then
            pass "Optimized image starts and /health endpoint responds"
        else
            fail "Container started but /health endpoint did not respond" \
                 "Make sure the app listens on port 8080 and has a /health route"
        fi
        docker rm -f learn-boss-verify-app > /dev/null 2>&1 || true
    else
        docker rm -f learn-boss-verify-app > /dev/null 2>&1 || true
        fail "Could not start container from learn-boss-app:optimized" \
             "Try: docker run --rm -p 8080:8080 learn-boss-app:optimized"
    fi
fi

echo ""

# --- Problem 2: Vanishing Database ------------------------------------------

bold "[Problem 2: The Vanishing Database]"
echo ""

# Check: volume exists
check \
    "Volume 'learn-boss-db-data' exists" \
    "docker volume inspect learn-boss-db-data" \
    "Create with: docker volume create --label app=learn-docker-k8s learn-boss-db-data"

# Check: container is running
check \
    "Container 'learn-boss-db' is running" \
    "docker ps --filter name=^learn-boss-db$ --filter status=running -q | grep -q ." \
    "Run MySQL with -v learn-boss-db-data:/var/lib/mysql"

# Check: container uses the named volume
if docker ps --filter name=^learn-boss-db$ --filter status=running -q | grep -q . 2>/dev/null; then
    VOLUME_CHECK=$(docker inspect learn-boss-db --format '{{range .Mounts}}{{.Name}} {{end}}' 2>/dev/null || echo "")
    if echo "$VOLUME_CHECK" | grep -q "learn-boss-db-data"; then
        pass "Container 'learn-boss-db' uses volume 'learn-boss-db-data'"
    else
        fail "Container 'learn-boss-db' is NOT using volume 'learn-boss-db-data'" \
             "Recreate with: -v learn-boss-db-data:/var/lib/mysql"
    fi
fi

# Check: MySQL is accepting connections
MYSQL_READY=0
for i in $(seq 1 6); do
    if docker exec learn-boss-db mysqladmin ping -u root -pbosspassword --silent > /dev/null 2>&1; then
        MYSQL_READY=1
        break
    fi
    sleep 5
done

if [ "$MYSQL_READY" -eq 1 ]; then
    pass "MySQL is accepting connections"
else
    fail "MySQL is not responding" \
         "MySQL may still be initializing. Wait 20-30 seconds and run verify again."
fi

# Check: customers table exists and has data
if [ "$MYSQL_READY" -eq 1 ]; then
    ROW_COUNT=$(docker exec learn-boss-db \
        mysql -u root -pbosspassword -sN -e "SELECT COUNT(*) FROM preferences.customers;" 2>/dev/null || echo "0")

    if [ "$ROW_COUNT" -gt 0 ] 2>/dev/null; then
        pass "Table 'customers' has $ROW_COUNT row(s) -- data persists"
    else
        fail "Table 'customers' has no rows or doesn't exist" \
             "Connect to MySQL and create the table with data"
    fi
fi

echo ""

# --- Problem 3: Silent Services ---------------------------------------------

bold "[Problem 3: The Silent Services]"
echo ""

# Check: user-defined network exists
check \
    "A user-defined network 'learn-boss-app-net' exists" \
    "docker network inspect learn-boss-app-net" \
    "Create with: docker network create --label app=learn-docker-k8s learn-boss-app-net"

# Check: both containers are running
check \
    "Container 'learn-boss-backend' is running" \
    "docker ps --filter name=^learn-boss-backend$ --filter status=running -q | grep -q ." \
    "Make sure the backend container is still running"

check \
    "Container 'learn-boss-frontend-probe' is running" \
    "docker ps --filter name=^learn-boss-frontend-probe$ --filter status=running -q | grep -q ." \
    "Make sure the frontend probe container is still running"

# Check: frontend can resolve backend by name
check \
    "learn-boss-frontend-probe can resolve learn-boss-backend by name (DNS)" \
    "docker exec learn-boss-frontend-probe nslookup learn-boss-backend" \
    "Connect both containers to learn-boss-app-net"

# Check: frontend can ping backend
check \
    "learn-boss-frontend-probe can ping learn-boss-backend" \
    "docker exec learn-boss-frontend-probe ping -c 1 -W 2 learn-boss-backend" \
    "Both containers must be on the same user-defined network"

echo ""

# --- Problem 4: Port Collision -----------------------------------------------

bold "[Problem 4: The Port Collision]"
echo ""

# Check: rogue container is stopped/removed
ROGUE_RUNNING=$(docker ps --filter name=^learn-boss-rogue$ --filter status=running -q 2>/dev/null || echo "")
if [ -z "$ROGUE_RUNNING" ]; then
    pass "Rogue container 'learn-boss-rogue' is not running"
else
    fail "Rogue container 'learn-boss-rogue' is still running on port 8080" \
         "Stop and remove it: docker stop learn-boss-rogue && docker rm learn-boss-rogue"
fi

# Check: frontend container exists and is running
check \
    "Container 'learn-boss-frontend' is running" \
    "docker ps --filter name=^learn-boss-frontend$ --filter status=running -q | grep -q ." \
    "Start a frontend container named learn-boss-frontend with -p 8080:80"

# Check: port 8080 is accessible
check \
    "Port 8080 is accessible on localhost" \
    "curl -sf http://localhost:8080" \
    "Make sure learn-boss-frontend has -p 8080:80"

# Check: port 8080 returns content
if curl -sf http://localhost:8080 > /dev/null 2>&1; then
    pass "Frontend serves content at http://localhost:8080"
else
    fail "No response from http://localhost:8080" \
         "Check that the frontend container is running with -p 8080:80"
fi

echo ""

# --- Summary -----------------------------------------------------------------

bold "=========================================="
TOTAL=$((PASSED + FAILED))
echo ""

if [ "$FAILED" -eq 0 ]; then
    green "  ALL CHECKS PASSED! ($PASSED/$TOTAL)"
    echo ""
    bold "  .--------------------------------------."
    bold "  |                                      |"
    bold "  |   WORLD 1 COMPLETE                   |"
    bold "  |   \"Docker Foundations\"                |"
    bold "  |                                      |"
    bold "  |   Boss Fight: CLEARED                |"
    bold "  |                                      |"
    bold "  |   Skills mastered:                   |"
    bold "  |   [x] Container lifecycle            |"
    bold "  |   [x] Image optimization             |"
    bold "  |   [x] Persistent storage             |"
    bold "  |   [x] Docker networking              |"
    bold "  |   [x] Incident triage                |"
    bold "  |                                      |"
    bold "  |   Next: World 2 - Docker Engineering |"
    bold "  |                                      |"
    bold "  '--------------------------------------'"
    echo ""
    green "  Sarah: \"Welcome to the team -- for real this time.\""
    echo ""
    exit 0
else
    red "  $FAILED check(s) failed. $PASSED/$TOTAL passed."
    echo ""
    yellow "  Keep going. Fix the failing checks and run verify again."
    yellow "  Each problem is independent -- partial progress counts."
    echo ""
    exit 1
fi
