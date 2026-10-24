#!/bin/bash
# Known-good solution for World 1 Boss Fight: The Morning From Hell
# Used by functional tests only. NOT visible to learners during gameplay.
# Tests: setup → broken state → apply solution → verify passes → cleanup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VERIFY="$PROJECT_DIR/curriculum/world-1-docker-foundations/boss-docker-diagnosis/challenges/verify.sh"

echo "=== W1 Boss Fight: Known-Good Solution Test ==="
echo ""

# ─── Problem 1: Optimized Image ──────────────────────────────────────────────

mkdir -p /tmp/learn-boss-app

cat > /tmp/learn-boss-app/main.go << 'GOEOF'
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "NoCappuccino Bean-Tracker v2.0")
	})
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})
	log.Printf("Bean-Tracker listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
GOEOF

cat > /tmp/learn-boss-app/go.mod << 'MODEOF'
module github.com/nocappuccino/bean-tracker
go 1.21
MODEOF

cat > /tmp/learn-boss-app/Dockerfile << 'DEOF'
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 go build -o bean-tracker .

FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/bean-tracker .
LABEL app=learn-docker-k8s world=w01 chapter=boss
EXPOSE 8080
CMD ["./bean-tracker"]
DEOF

docker build -t learn-boss-app:optimized /tmp/learn-boss-app/
echo "DONE: Image built"

# ─── Problem 2: Persistent Database ──────────────────────────────────────────

docker volume create --label app=learn-docker-k8s --label world=w01 --label chapter=boss learn-boss-db-data 2>/dev/null || true
docker rm -f learn-boss-db 2>/dev/null || true

docker run -d \
  --name learn-boss-db \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  -e MYSQL_ROOT_PASSWORD=bosspassword \
  -e MYSQL_DATABASE=preferences \
  -v learn-boss-db-data:/var/lib/mysql \
  mysql:8.0

echo "Waiting for MySQL to initialize..."
sleep 25

docker exec learn-boss-db mysql -u root -pbosspassword -e "
  USE preferences;
  CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    favorite_roast VARCHAR(50)
  );
  INSERT INTO customers (name, favorite_roast) VALUES ('TestUser', 'Colombian Dark');
" 2>/dev/null

echo "DONE: Database with volume"

# ─── Problem 3: Service Discovery ────────────────────────────────────────────

docker rm -f learn-boss-backend learn-boss-frontend-probe 2>/dev/null || true
docker network create --label app=learn-docker-k8s --label world=w01 --label chapter=boss learn-boss-app-net 2>/dev/null || true

docker run -d \
  --name learn-boss-backend \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  --network learn-boss-app-net \
  nginx:alpine

docker run -d \
  --name learn-boss-frontend-probe \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  --network learn-boss-app-net \
  alpine sleep 3600

echo "DONE: Network setup"

# ─── Problem 4: Frontend on Port 8080 ────────────────────────────────────────

docker rm -f learn-boss-rogue learn-boss-frontend 2>/dev/null || true

docker run -d \
  --name learn-boss-frontend \
  --label app=learn-docker-k8s \
  --label world=w01 \
  --label chapter=boss \
  -p 8080:80 \
  nginx:alpine

echo "DONE: Frontend on port 8080"
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
