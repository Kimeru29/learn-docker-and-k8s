#!/bin/bash
# Platform detection for Learn Docker & K8s
# Detects OS, architecture, Docker variant, and runtime capabilities.
# Output: key=value pairs for easy parsing by the AI engine.

set -uo pipefail

echo "=== Platform Detection ==="

# ─── OS & Architecture ────────────────────────────────────────────────────────

OS=$(uname -s)
ARCH=$(uname -m)
KERNEL=$(uname -r)

echo "os=${OS}"
echo "arch=${ARCH}"
echo "kernel=${KERNEL}"

# Detect WSL2
WSL=false
if [ "$OS" = "Linux" ]; then
    if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        WSL=true
        echo "wsl=true"
        echo "note=wsl2: Running under WSL2. Bind mount performance may differ from native Linux. Docker Desktop for Windows may be providing the Docker daemon."
    else
        echo "wsl=false"
    fi
fi

# Normalize architecture names
case "$ARCH" in
    x86_64|amd64)   NORM_ARCH="amd64" ;;
    aarch64|arm64)   NORM_ARCH="arm64" ;;
    armv7l)          NORM_ARCH="armv7" ;;
    *)               NORM_ARCH="$ARCH" ;;
esac
echo "arch_normalized=${NORM_ARCH}"

# ─── Docker Variant ───────────────────────────────────────────────────────────

DOCKER_VARIANT="unknown"
DOCKER_VERSION=""
DOCKER_CONTEXT=""

if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "docker_version=${DOCKER_VERSION}"

    # Detect Docker Desktop vs Colima vs native
    if docker info 2>/dev/null | grep -qi "docker desktop"; then
        DOCKER_VARIANT="docker-desktop"
    elif docker info 2>/dev/null | grep -qi "colima"; then
        DOCKER_VARIANT="colima"
    elif docker info 2>/dev/null | grep -qi "rancher"; then
        DOCKER_VARIANT="rancher-desktop"
    elif docker info 2>/dev/null | grep -qi "podman"; then
        DOCKER_VARIANT="podman"
    elif [ "$OS" = "Linux" ]; then
        DOCKER_VARIANT="native-linux"
    else
        DOCKER_VARIANT="unknown"
    fi
    echo "docker_variant=${DOCKER_VARIANT}"

    # Docker context (useful for remote Docker)
    DOCKER_CONTEXT=$(docker context show 2>/dev/null || echo "default")
    echo "docker_context=${DOCKER_CONTEXT}"

    # Storage driver
    STORAGE_DRIVER=$(docker info --format '{{.Driver}}' 2>/dev/null || echo "unknown")
    echo "storage_driver=${STORAGE_DRIVER}"

    # Cgroup version
    CGROUP_VERSION=$(docker info --format '{{.CgroupVersion}}' 2>/dev/null || echo "unknown")
    echo "cgroup_version=${CGROUP_VERSION}"

    # BuildKit
    BUILDKIT=$(docker buildx version 2>/dev/null && echo "available" || echo "unavailable")
    echo "buildkit=${BUILDKIT}"

    # Default platform (important for multi-arch)
    DEFAULT_PLATFORM=$(docker info --format '{{.OSType}}/{{.Architecture}}' 2>/dev/null || echo "unknown")
    echo "default_platform=${DEFAULT_PLATFORM}"
else
    echo "docker_version=not_installed"
    echo "docker_variant=not_installed"
fi

# ─── Docker Compose ───────────────────────────────────────────────────────────

if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
    echo "compose_version=${COMPOSE_VERSION}"
    echo "compose_variant=v2-plugin"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "compose_version=${COMPOSE_VERSION}"
    echo "compose_variant=v1-standalone"
else
    echo "compose_version=not_installed"
    echo "compose_variant=not_installed"
fi

# ─── Kubernetes Tools ─────────────────────────────────────────────────────────

if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -oE '"gitVersion":\s*"v[^"]+' | grep -oE 'v[0-9.]+' || echo "unknown")
    echo "kubectl_version=${KUBECTL_VERSION}"
else
    echo "kubectl_version=not_installed"
fi

if command -v kind &> /dev/null; then
    KIND_VERSION=$(kind version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo "kind_version=${KIND_VERSION}"
else
    echo "kind_version=not_installed"
fi

if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null | grep -oE 'v[0-9.]+' || echo "unknown")
    echo "helm_version=${HELM_VERSION}"
else
    echo "helm_version=not_installed"
fi

# ─── Platform-Specific Notes ──────────────────────────────────────────────────

NOTES=""

if [ "$OS" = "Darwin" ] && [ "$NORM_ARCH" = "arm64" ]; then
    NOTES="apple-silicon"
    echo "note=apple-silicon: Multi-arch image builds may default to arm64. Use --platform linux/amd64 for x86 compatibility."
fi

if [ "$DOCKER_VARIANT" = "colima" ]; then
    echo "note=colima: Some Docker Desktop features (like Extensions, Dev Environments) are unavailable."
fi

if [ "$DOCKER_VARIANT" = "podman" ]; then
    echo "note=podman: Some Docker-specific commands may behave differently. docker compose may need podman-compose."
fi

echo ""
echo "=== Detection Complete ==="
