#!/bin/bash
# Deep Dive: Multi-Architecture — Verification Script
# Checks that all multi-architecture challenges are complete
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed

FAILED=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

check() {
    local description="$1"
    local command="$2"

    if eval "$command" > /dev/null 2>&1; then
        echo "PASS: $description"
    else
        echo "FAIL: $description"
        FAILED=1
    fi
}

check_output() {
    local description="$1"
    local command="$2"
    local expected="$3"

    local actual
    actual=$(eval "$command" 2>/dev/null)
    if echo "$actual" | grep -q "$expected"; then
        echo "PASS: $description"
    else
        echo "FAIL: $description"
        if [ -n "$actual" ]; then
            echo "      Got: $(echo "$actual" | head -1)"
            echo "      Expected to contain: $expected"
        fi
        FAILED=1
    fi
}

# ─── Header ───────────────────────────────────────────────────────────────────

echo "=== Deep Dive: Multi-Architecture — Challenge Verification ==="
echo ""

# ─── Challenge 01: Detect and Fix ────────────────────────────────────────────

echo "[ Challenge 01: Detect and Fix ]"

check \
    "Image 'learn-dd-multi-wrong:v1' exists" \
    "docker image inspect learn-dd-multi-wrong:v1"

check \
    "Image 'learn-dd-multi-fixed:v1' exists" \
    "docker image inspect learn-dd-multi-fixed:v1"

# Check that the two images have different architectures
WRONG_ARCH=$(docker inspect learn-dd-multi-wrong:v1 --format '{{.Architecture}}' 2>/dev/null)
FIXED_ARCH=$(docker inspect learn-dd-multi-fixed:v1 --format '{{.Architecture}}' 2>/dev/null)

if [ -n "$WRONG_ARCH" ] && [ -n "$FIXED_ARCH" ]; then
    if [ "$WRONG_ARCH" != "$FIXED_ARCH" ]; then
        echo "PASS: Wrong image ($WRONG_ARCH) and fixed image ($FIXED_ARCH) target different architectures"
    else
        echo "FAIL: Both images target the same architecture ($WRONG_ARCH) — the fixed image should target a different one"
        FAILED=1
    fi
else
    echo "FAIL: Could not determine architecture of one or both images"
    FAILED=1
fi

check \
    "Container 'learn-dd-multi-fixed' exists" \
    "docker ps -a --filter 'name=^learn-dd-multi-fixed$' -q | grep -q ."

check \
    "Container 'learn-dd-multi-fixed' is running" \
    "docker ps --filter 'name=^learn-dd-multi-fixed$' --filter 'status=running' -q | grep -q ."

check \
    "Container 'learn-dd-multi-fixed' has label app=learn-docker-k8s" \
    "docker inspect learn-dd-multi-fixed --format '{{index .Config.Labels \"app\"}}' | grep -q 'learn-docker-k8s'"

check \
    "Container 'learn-dd-multi-fixed' has label track=deep-dive" \
    "docker inspect learn-dd-multi-fixed --format '{{index .Config.Labels \"track\"}}' | grep -q 'deep-dive'"

echo ""

# ─── Challenge 02: Multi-Arch Build ─────────────────────────────────────────

echo "[ Challenge 02: Multi-Arch Build ]"

check \
    "Local registry 'learn-dd-multi-registry' is running" \
    "docker ps --filter 'name=^learn-dd-multi-registry$' --filter 'status=running' -q | grep -q ."

check \
    "Registry is accessible on port 5555" \
    "curl -sf http://localhost:5555/v2/"

# Check if the image exists in the registry
check \
    "Image 'nocappuccino-api:multi' exists in local registry" \
    "curl -sf http://localhost:5555/v2/nocappuccino-api/manifests/multi -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifest.v2+json'"

# Check manifest list contains both architectures
MANIFEST=$(curl -sf http://localhost:5555/v2/nocappuccino-api/manifests/multi \
  -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json' 2>/dev/null)

if [ -n "$MANIFEST" ]; then
    # Check for amd64
    if echo "$MANIFEST" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    manifests = data.get('manifests', [])
    arches = [m.get('platform', {}).get('architecture', '') for m in manifests]
    sys.exit(0 if 'amd64' in arches else 1)
except:
    sys.exit(1)
" 2>/dev/null; then
        echo "PASS: Manifest list contains linux/amd64"
    else
        echo "FAIL: Manifest list does not contain linux/amd64"
        FAILED=1
    fi

    # Check for arm64
    if echo "$MANIFEST" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    manifests = data.get('manifests', [])
    arches = [m.get('platform', {}).get('architecture', '') for m in manifests]
    sys.exit(0 if 'arm64' in arches else 1)
except:
    sys.exit(1)
" 2>/dev/null; then
        echo "PASS: Manifest list contains linux/arm64"
    else
        echo "FAIL: Manifest list does not contain linux/arm64"
        FAILED=1
    fi
else
    echo "FAIL: Could not retrieve manifest list from registry"
    echo "      Make sure you built with --push to localhost:5555"
    FAILED=1
fi

# Check the running container
check \
    "Container 'learn-dd-multi-app' exists" \
    "docker ps -a --filter 'name=^learn-dd-multi-app$' -q | grep -q ."

check \
    "Container 'learn-dd-multi-app' is running" \
    "docker ps --filter 'name=^learn-dd-multi-app$' --filter 'status=running' -q | grep -q ."

check \
    "Container 'learn-dd-multi-app' has label app=learn-docker-k8s" \
    "docker inspect learn-dd-multi-app --format '{{index .Config.Labels \"app\"}}' | grep -q 'learn-docker-k8s'"

check \
    "Port 8888 is accessible" \
    "curl -sf http://localhost:8888"

check_output \
    "Response from port 8888 contains 'nocappuccino-api'" \
    "curl -s http://localhost:8888" \
    "nocappuccino-api"

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed! Deep Dive: Multi-Architecture complete!"
    echo ""
    echo "Sarah: 'Your images now run on any architecture — x86 servers, ARM64'"
    echo "       'cloud instances, Apple Silicon laptops, even Raspberry Pis.'"
    echo "       'Dave can never blame architecture mismatches again.'"
    echo ""
    echo "(★‿★) The Universal Bean — truly universal. Build once, run anywhere."
    exit 0
else
    echo "Some checks failed. Review the FAIL lines above and try again."
    echo ""
    echo "Tips:"
    echo "  - Challenge 01: Build learn-dd-multi-fixed:v1 for a different arch than the wrong image"
    echo "  - Challenge 02: Use 'docker buildx build --platform linux/amd64,linux/arm64 --push'"
    echo "    to push to the local registry at localhost:5555"
    exit 1
fi
