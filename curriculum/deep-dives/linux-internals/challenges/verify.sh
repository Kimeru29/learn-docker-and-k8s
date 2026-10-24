#!/bin/bash
# Deep Dive: Linux Internals — Verification Script
# Checks that all linux-internals challenges are complete
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

check_numeric() {
    local description="$1"
    local command="$2"
    local expected="$3"

    local actual
    actual=$(eval "$command" 2>/dev/null | tr -d '[:space:]')
    if [ "$actual" = "$expected" ]; then
        echo "PASS: $description"
    else
        echo "FAIL: $description"
        echo "      Got: '$actual'"
        echo "      Expected: '$expected'"
        FAILED=1
    fi
}

# ─── Header ───────────────────────────────────────────────────────────────────

echo "=== Deep Dive: Linux Internals — Challenge Verification ==="
echo ""

# ─── Challenge 01: Namespace Exploration ──────────────────────────────────────

echo "[ Challenge 01: Namespace Exploration ]"

check \
    "Container 'learn-dd-ns-target' exists" \
    "docker ps -a --filter 'name=^learn-dd-ns-target$' -q | grep -q ."

check \
    "Container 'learn-dd-ns-target' is running" \
    "docker ps --filter 'name=^learn-dd-ns-target$' --filter 'status=running' -q | grep -q ."

check \
    "Container 'learn-dd-ns-target' has label app=learn-docker-k8s" \
    "docker inspect learn-dd-ns-target --format '{{index .Config.Labels \"app\"}}' | grep -q 'learn-docker-k8s'"

check \
    "Container 'learn-dd-ns-target' has label track=deep-dive" \
    "docker inspect learn-dd-ns-target --format '{{index .Config.Labels \"track\"}}' | grep -q 'deep-dive'"

check \
    "Findings report exists at /tmp/learn-dd-ns-findings/report.txt" \
    "test -f /tmp/learn-dd-ns-findings/report.txt"

# Validate report contents
if [ -f /tmp/learn-dd-ns-findings/report.txt ]; then
    # Check HOST_PID matches actual container PID
    ACTUAL_HOST_PID=$(docker inspect learn-dd-ns-target --format '{{.State.Pid}}' 2>/dev/null)
    REPORT_HOST_PID=$(grep '^HOST_PID=' /tmp/learn-dd-ns-findings/report.txt 2>/dev/null | cut -d= -f2)

    if [ -n "$ACTUAL_HOST_PID" ] && [ -n "$REPORT_HOST_PID" ] && [ "$ACTUAL_HOST_PID" = "$REPORT_HOST_PID" ]; then
        echo "PASS: HOST_PID in report matches actual container PID ($ACTUAL_HOST_PID)"
    else
        echo "FAIL: HOST_PID in report ($REPORT_HOST_PID) does not match actual container PID ($ACTUAL_HOST_PID)"
        FAILED=1
    fi

    # Check CONTAINER_PID is 1
    REPORT_CONTAINER_PID=$(grep '^CONTAINER_PID=' /tmp/learn-dd-ns-findings/report.txt 2>/dev/null | cut -d= -f2)
    if [ "$REPORT_CONTAINER_PID" = "1" ]; then
        echo "PASS: CONTAINER_PID correctly reported as 1"
    else
        echo "FAIL: CONTAINER_PID should be 1, got: $REPORT_CONTAINER_PID"
        FAILED=1
    fi

    # Check CONTAINER_HOSTNAME matches
    ACTUAL_HOSTNAME=$(docker exec learn-dd-ns-target hostname 2>/dev/null | tr -d '[:space:]')
    REPORT_HOSTNAME=$(grep '^CONTAINER_HOSTNAME=' /tmp/learn-dd-ns-findings/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')

    if [ -n "$ACTUAL_HOSTNAME" ] && [ -n "$REPORT_HOSTNAME" ] && [ "$ACTUAL_HOSTNAME" = "$REPORT_HOSTNAME" ]; then
        echo "PASS: CONTAINER_HOSTNAME matches ($ACTUAL_HOSTNAME)"
    else
        echo "FAIL: CONTAINER_HOSTNAME ($REPORT_HOSTNAME) does not match actual ($ACTUAL_HOSTNAME)"
        FAILED=1
    fi

    # Check that container hostname differs from host hostname
    HOST_HOSTNAME=$(hostname | tr -d '[:space:]')
    if [ "$ACTUAL_HOSTNAME" != "$HOST_HOSTNAME" ]; then
        echo "PASS: Container hostname differs from host hostname (UTS namespace works)"
    else
        echo "FAIL: Container hostname matches host hostname — UTS namespace may not be isolated"
        FAILED=1
    fi

    # Check CONTAINER_INTERFACES is present and numeric
    REPORT_IFACES=$(grep '^CONTAINER_INTERFACES=' /tmp/learn-dd-ns-findings/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    if [ -n "$REPORT_IFACES" ] && [ "$REPORT_IFACES" -gt 0 ] 2>/dev/null; then
        echo "PASS: CONTAINER_INTERFACES reported ($REPORT_IFACES)"
    else
        echo "FAIL: CONTAINER_INTERFACES must be a positive number, got: $REPORT_IFACES"
        FAILED=1
    fi
else
    echo "FAIL: Cannot validate report — file not found"
    FAILED=1
fi

echo ""

# ─── Challenge 02: cgroup Limits ─────────────────────────────────────────────

echo "[ Challenge 02: cgroup Limits ]"

check \
    "Container 'learn-dd-cg-hungry' exists" \
    "docker ps -a --filter 'name=^learn-dd-cg-hungry$' -q | grep -q ."

check \
    "Container 'learn-dd-cg-hungry' is running" \
    "docker ps --filter 'name=^learn-dd-cg-hungry$' --filter 'status=running' -q | grep -q ."

check \
    "Container 'learn-dd-cg-hungry' has label app=learn-docker-k8s" \
    "docker inspect learn-dd-cg-hungry --format '{{index .Config.Labels \"app\"}}' | grep -q 'learn-docker-k8s'"

check \
    "Container 'learn-dd-cg-hungry' has label track=deep-dive" \
    "docker inspect learn-dd-cg-hungry --format '{{index .Config.Labels \"track\"}}' | grep -q 'deep-dive'"

# Check memory limit = 128MB (134217728 bytes)
check_numeric \
    "Memory limit is 128MB (134217728 bytes)" \
    "docker inspect learn-dd-cg-hungry --format '{{.HostConfig.Memory}}'" \
    "134217728"

# Check CPU limit = 0.5 CPUs (500000000 NanoCpus)
check_numeric \
    "CPU limit is 0.5 CPUs (500000000 NanoCpus)" \
    "docker inspect learn-dd-cg-hungry --format '{{.HostConfig.NanoCpus}}'" \
    "500000000"

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed! Deep Dive: Linux Internals complete!"
    echo ""
    echo "Sarah: 'Now you know what's really happening under docker run.'"
    echo "       'Namespaces, cgroups, OverlayFS — it's just Linux.'"
    echo "       'Next time a container misbehaves, you'll know exactly where to look.'"
    echo ""
    echo "(★‿★) Impressive work. You've gone deeper than most engineers ever do."
    exit 0
else
    echo "Some checks failed. Review the FAIL lines above and try again."
    echo ""
    echo "Tips:"
    echo "  - Challenge 01: Make sure learn-dd-ns-target is running and the report file exists"
    echo "  - Challenge 02: Use 'docker update' to set limits on the running container"
    exit 1
fi
