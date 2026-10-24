#!/bin/bash
# Deep Dive: Container Security — Verification Script
# Checks that all container-security challenges are complete
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

echo "=== Deep Dive: Container Security — Challenge Verification ==="
echo ""

# ─── Challenge 01: Custom Seccomp Profile ─────────────────────────────────────

echo "[ Challenge 01: Custom Seccomp Profile ]"

check \
    "Custom seccomp profile exists at /tmp/learn-dd-sec/custom-seccomp.json" \
    "test -f /tmp/learn-dd-sec/custom-seccomp.json"

# Validate the profile structure
if [ -f /tmp/learn-dd-sec/custom-seccomp.json ]; then
    # Check defaultAction is SCMP_ACT_ERRNO (not ALLOW)
    DEFAULT_ACTION=$(python3 -c "import json; print(json.load(open('/tmp/learn-dd-sec/custom-seccomp.json'))['defaultAction'])" 2>/dev/null)
    if [ "$DEFAULT_ACTION" = "SCMP_ACT_ERRNO" ]; then
        echo "PASS: Profile defaultAction is SCMP_ACT_ERRNO (block by default)"
    else
        echo "FAIL: Profile defaultAction should be SCMP_ACT_ERRNO, got: $DEFAULT_ACTION"
        echo "      Using SCMP_ACT_ALLOW as default defeats the purpose of seccomp"
        FAILED=1
    fi

    # Check that mount is in the allowed syscalls
    MOUNT_ALLOWED=$(python3 -c "
import json
profile = json.load(open('/tmp/learn-dd-sec/custom-seccomp.json'))
for rule in profile.get('syscalls', []):
    if rule.get('action') == 'SCMP_ACT_ALLOW' and 'mount' in rule.get('names', []):
        print('yes')
        break
else:
    print('no')
" 2>/dev/null)

    if [ "$MOUNT_ALLOWED" = "yes" ]; then
        echo "PASS: Profile allows the 'mount' syscall"
    else
        echo "FAIL: Profile does not allow the 'mount' syscall"
        FAILED=1
    fi
else
    echo "FAIL: Cannot validate profile — file not found"
    FAILED=1
fi

check \
    "Container 'learn-dd-sec-mount' exists" \
    "docker ps -a --filter 'name=^learn-dd-sec-mount$' -q | grep -q ."

check \
    "Container 'learn-dd-sec-mount' is running" \
    "docker ps --filter 'name=^learn-dd-sec-mount$' --filter 'status=running' -q | grep -q ."

check \
    "Container 'learn-dd-sec-mount' has label app=learn-docker-k8s" \
    "docker inspect learn-dd-sec-mount --format '{{index .Config.Labels \"app\"}}' | grep -q 'learn-docker-k8s'"

check \
    "Container 'learn-dd-sec-mount' has label track=deep-dive" \
    "docker inspect learn-dd-sec-mount --format '{{index .Config.Labels \"track\"}}' | grep -q 'deep-dive'"

# Check that the container has a seccomp profile set (not unconfined)
SECCOMP_PROFILE=$(docker inspect learn-dd-sec-mount --format '{{json .HostConfig.SecurityOpt}}' 2>/dev/null)
if echo "$SECCOMP_PROFILE" | grep -q "seccomp"; then
    if echo "$SECCOMP_PROFILE" | grep -q "unconfined"; then
        echo "FAIL: Container is using seccomp=unconfined — should use a custom profile"
        FAILED=1
    else
        echo "PASS: Container has a seccomp profile applied"
    fi
else
    echo "FAIL: Container does not have a seccomp profile applied via --security-opt"
    FAILED=1
fi

# Check that tmpfs is mounted inside the container
check \
    "Container has tmpfs mounted at /tmp/cache" \
    "docker exec learn-dd-sec-mount mount | grep -q '/tmp/cache.*tmpfs'"

echo ""

# ─── Challenge 02: Scan and Fix ──────────────────────────────────────────────

echo "[ Challenge 02: Scan and Fix ]"

check \
    "Vulnerable image 'learn-dd-sec-vulnerable:v1' exists" \
    "docker image inspect learn-dd-sec-vulnerable:v1"

check \
    "Fixed image 'learn-dd-sec-fixed:v1' exists" \
    "docker image inspect learn-dd-sec-fixed:v1"

check \
    "Fixed Dockerfile exists at /tmp/learn-dd-sec-scan/Dockerfile.fixed" \
    "test -f /tmp/learn-dd-sec-scan/Dockerfile.fixed"

# Check the fixed image uses a different base (not node:18-bullseye)
if [ -f /tmp/learn-dd-sec-scan/Dockerfile.fixed ]; then
    if grep -q "node:18-bullseye" /tmp/learn-dd-sec-scan/Dockerfile.fixed; then
        echo "FAIL: Fixed Dockerfile still uses node:18-bullseye as base image"
        FAILED=1
    else
        echo "PASS: Fixed Dockerfile uses a different base image"
    fi
fi

# Check the fixed image is smaller than the vulnerable one
VULN_SIZE=$(docker image inspect learn-dd-sec-vulnerable:v1 --format '{{.Size}}' 2>/dev/null)
FIXED_SIZE=$(docker image inspect learn-dd-sec-fixed:v1 --format '{{.Size}}' 2>/dev/null)

if [ -n "$VULN_SIZE" ] && [ -n "$FIXED_SIZE" ]; then
    if [ "$FIXED_SIZE" -lt "$VULN_SIZE" ]; then
        VULN_MB=$((VULN_SIZE / 1024 / 1024))
        FIXED_MB=$((FIXED_SIZE / 1024 / 1024))
        echo "PASS: Fixed image (${FIXED_MB}MB) is smaller than vulnerable image (${VULN_MB}MB)"
    else
        echo "FAIL: Fixed image should be smaller than the vulnerable image"
        echo "      Vulnerable: $VULN_SIZE bytes, Fixed: $FIXED_SIZE bytes"
        FAILED=1
    fi
fi

check \
    "Container 'learn-dd-sec-fixed-app' exists" \
    "docker ps -a --filter 'name=^learn-dd-sec-fixed-app$' -q | grep -q ."

check \
    "Container 'learn-dd-sec-fixed-app' is running" \
    "docker ps --filter 'name=^learn-dd-sec-fixed-app$' --filter 'status=running' -q | grep -q ."

check \
    "Container 'learn-dd-sec-fixed-app' has label app=learn-docker-k8s" \
    "docker inspect learn-dd-sec-fixed-app --format '{{index .Config.Labels \"app\"}}' | grep -q 'learn-docker-k8s'"

check \
    "Port 3333 is accessible" \
    "curl -sf http://localhost:3333"

check_output \
    "Response from port 3333 contains 'status' and 'ok'" \
    "curl -s http://localhost:3333" \
    '"status":"ok"'

echo ""

# ─── Summary ──────────────────────────────────────────────────────────────────

if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed! Deep Dive: Container Security complete!"
    echo ""
    echo "Sarah: 'Custom seccomp profiles, vulnerability scanning, image hardening —'"
    echo "       'you're building real defense in depth. The next security auditor'"
    echo "       'is going to be impressed.'"
    echo ""
    echo "(★‿★) The vault is sealed. Your containers are hardened."
    exit 0
else
    echo "Some checks failed. Review the FAIL lines above and try again."
    echo ""
    echo "Tips:"
    echo "  - Challenge 01: Create a seccomp profile with defaultAction SCMP_ACT_ERRNO"
    echo "    that allows mount/umount2, then run a container with it"
    echo "  - Challenge 02: Scan the vulnerable image, create a fixed Dockerfile with"
    echo "    a newer/smaller base, and verify it runs on port 3333"
    exit 1
fi
