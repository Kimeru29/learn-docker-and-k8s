#!/bin/bash
# Known-good solution for World 2 Boss Fight: The Full Stack Meltdown
# Used by functional tests only. NOT visible to learners during gameplay.
# Tests: setup fixed files → docker compose up → verify passes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VERIFY="$PROJECT_DIR/curriculum/world-2-docker-engineering/boss-production-docker/challenges/verify.sh"
WORK_DIR="/tmp/learn-boss-w2"

echo "=== W2 Boss Fight: Known-Good Solution Test ==="
echo ""

# ─── Cleanup previous state ──────────────────────────────────────────────────

echo "Cleaning up previous state..."
cd /tmp
docker compose -p learn-boss -f "${WORK_DIR}/docker-compose.yml" down --volumes --remove-orphans 2>/dev/null || true
rm -rf "$WORK_DIR"

# ─── Create directory structure ───────────────────────────────────────────────

mkdir -p "$WORK_DIR/api" "$WORK_DIR/worker" "$WORK_DIR/frontend"

# ─── api/server.js ────────────────────────────────────────────────────────────

cat > "$WORK_DIR/api/server.js" << 'EOF'
const http = require('http');

const PORT = process.env.PORT || 3000;
const DB_HOST = process.env.DB_HOST || 'postgres';
const DB_PASSWORD = process.env.DB_PASSWORD;

console.log(`API starting on port ${PORT}`);
console.log(`DB host: ${DB_HOST}, password: ${DB_PASSWORD ? 'SET' : 'NOT SET'}`);

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'ok',
      service: 'api',
      db_host: DB_HOST,
      db_configured: !!DB_PASSWORD
    }));
    return;
  }
  res.writeHead(200);
  res.end('NoCappuccino API\n');
});

// SIGTERM handler — works correctly with exec form CMD
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('API shut down cleanly.');
    process.exit(0);
  });
});

server.listen(PORT, () => {
  console.log(`API listening on port ${PORT}`);
});
EOF

# ─── api/Dockerfile (FIXED — exec form CMD, no ENV DB_PASSWORD) ──────────────

cat > "$WORK_DIR/api/Dockerfile" << 'EOF'
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY server.js .

# FIX 1: exec form CMD so SIGTERM is forwarded
# FIX 3: No ENV DB_PASSWORD — credentials injected at runtime
CMD ["node", "server.js"]
EOF

# ─── worker/leaky-worker.js ──────────────────────────────────────────────────

cat > "$WORK_DIR/worker/leaky-worker.js" << 'EOF'
// Worker that processes recommendations — has a memory leak
const cache = [];

function processRecommendation() {
  const data = Buffer.alloc(512 * 1024, 'recommendation-data');
  cache.push(data);
  console.log(`Processed recommendation #${cache.length} — cache: ~${(cache.length * 0.5).toFixed(1)}MB`);
}

setInterval(processRecommendation, 2000);
processRecommendation();

process.on('SIGTERM', () => {
  console.log('Worker shutting down...');
  process.exit(0);
});

console.log('Recommendation worker started.');
EOF

# ─── worker/Dockerfile ───────────────────────────────────────────────────────

cat > "$WORK_DIR/worker/Dockerfile" << 'EOF'
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

WORKDIR /app
COPY leaky-worker.js .

CMD ["node", "leaky-worker.js"]
EOF

# ─── frontend/index.html ─────────────────────────────────────────────────────

cat > "$WORK_DIR/frontend/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>NoCappuccino</title>
  <style>body { font-family: sans-serif; background: #1a0a00; color: #f5e6d0; padding: 2rem; }
  h1 { color: #d4a96a; }</style>
</head>
<body>
  <h1>NoCappuccino</h1>
  <p>Specialty Coffee Subscriptions</p>
</body>
</html>
EOF

# ─── frontend/Dockerfile (FIXED — nginx:alpine, no bloat) ────────────────────

cat > "$WORK_DIR/frontend/Dockerfile" << 'EOF'
FROM nginx:1.25-alpine

LABEL app=learn-docker-k8s
LABEL world=w02

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
EOF

# ─── docker-compose.yml (FIXED — memory limit + backend-net on api) ──────────

cat > "$WORK_DIR/docker-compose.yml" << 'EOF'
name: learn-boss

services:

  api:
    build: ./api
    ports:
      - "3000:3000"
    environment:
      PORT: "3000"
      DB_HOST: postgres
      DB_PASSWORD: ${DB_PASSWORD:-nocap_prod_password_2025}
    networks:
      - frontend-net
      - backend-net          # FIX 5: API on both networks
    depends_on:
      postgres:
        condition: service_healthy
    labels:
      app: learn-docker-k8s
      world: w02

  worker:
    build: ./worker
    deploy:                  # FIX 2: memory limit on worker
      resources:
        limits:
          memory: 128M
    restart: on-failure
    networks:
      - backend-net
    labels:
      app: learn-docker-k8s
      world: w02

  frontend:
    build: ./frontend
    ports:
      - "8080:80"
    networks:
      - frontend-net
    labels:
      app: learn-docker-k8s
      world: w02

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: cloudbrew
      POSTGRES_USER: brew
      POSTGRES_PASSWORD: ${DB_PASSWORD:-nocap_prod_password_2025}
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - backend-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    labels:
      app: learn-docker-k8s
      world: w02

networks:
  frontend-net:
    labels:
      app: learn-docker-k8s
      world: w02
  backend-net:
    labels:
      app: learn-docker-k8s
      world: w02

volumes:
  db-data:
    labels:
      app: learn-docker-k8s
      world: w02
EOF

# ─── .env (runtime credentials) ──────────────────────────────────────────────

cat > "$WORK_DIR/.env" << 'EOF'
DB_PASSWORD=runtime-secure-password
EOF

# ─── Build and start ─────────────────────────────────────────────────────────

echo "Building and starting stack..."
cd "$WORK_DIR"
docker compose up -d --build

echo "Waiting for postgres to become healthy..."
RETRIES=0
MAX_RETRIES=30
while [ $RETRIES -lt $MAX_RETRIES ]; do
  STATUS=$(docker inspect --format '{{.State.Health.Status}}' learn-boss-postgres-1 2>/dev/null || echo "starting")
  if [ "$STATUS" = "healthy" ]; then
    echo "Postgres is healthy."
    break
  fi
  RETRIES=$((RETRIES + 1))
  sleep 2
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
  echo "WARNING: Postgres did not become healthy in time."
fi

# Wait for API to be ready
echo "Waiting for API to respond..."
RETRIES=0
while [ $RETRIES -lt 15 ]; do
  if curl -sf --max-time 2 http://localhost:3000/health > /dev/null 2>&1; then
    echo "API is responding."
    break
  fi
  RETRIES=$((RETRIES + 1))
  sleep 2
done

echo ""

# ─── Verify ──────────────────────────────────────────────────────────────────

echo "=== Running verify.sh ==="
if bash "$VERIFY"; then
    echo ""
    echo "SOLUTION TEST PASSED"
    exit 0
else
    echo ""
    echo "SOLUTION TEST FAILED — verifier rejected known-good solution"
    exit 1
fi
