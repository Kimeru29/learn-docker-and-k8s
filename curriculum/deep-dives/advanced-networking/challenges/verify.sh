#!/bin/bash
# Deep Dive: Advanced Networking — Verification Script
# Checks that all advanced-networking challenges are complete
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

echo "=== Deep Dive: Advanced Networking — Challenge Verification ==="
echo ""

# ─── Challenge 01: Trace the Packet ──────────────────────────────────────────

echo "[ Challenge 01: Trace the Packet ]"

check \
    "Container 'learn-dd-net-trace' exists" \
    "docker ps -a --filter 'name=^learn-dd-net-trace$' -q | grep -q ."

check \
    "Container 'learn-dd-net-trace' is running" \
    "docker ps --filter 'name=^learn-dd-net-trace$' --filter 'status=running' -q | grep -q ."

check \
    "Container 'learn-dd-net-trace' has label app=learn-docker-k8s" \
    "docker inspect learn-dd-net-trace --format '{{index .Config.Labels \"app\"}}' | grep -q 'learn-docker-k8s'"

check \
    "Port 7777 is accessible" \
    "curl -sf http://localhost:7777"

check \
    "Report file exists at /tmp/learn-dd-net-trace/report.txt" \
    "test -f /tmp/learn-dd-net-trace/report.txt"

# Validate report contents
if [ -f /tmp/learn-dd-net-trace/report.txt ]; then
    # Check CONTAINER_IP matches actual container IP
    ACTUAL_IP=$(docker inspect learn-dd-net-trace --format '{{.NetworkSettings.IPAddress}}' 2>/dev/null)
    REPORT_IP=$(grep '^CONTAINER_IP=' /tmp/learn-dd-net-trace/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')

    if [ -n "$ACTUAL_IP" ] && [ -n "$REPORT_IP" ] && [ "$ACTUAL_IP" = "$REPORT_IP" ]; then
        echo "PASS: CONTAINER_IP matches actual container IP ($ACTUAL_IP)"
    else
        echo "FAIL: CONTAINER_IP ($REPORT_IP) does not match actual ($ACTUAL_IP)"
        FAILED=1
    fi

    # Check HOST_PORT
    REPORT_HOST_PORT=$(grep '^HOST_PORT=' /tmp/learn-dd-net-trace/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    if [ "$REPORT_HOST_PORT" = "7777" ]; then
        echo "PASS: HOST_PORT correctly reported as 7777"
    else
        echo "FAIL: HOST_PORT should be 7777, got: $REPORT_HOST_PORT"
        FAILED=1
    fi

    # Check CONTAINER_PORT
    REPORT_CONTAINER_PORT=$(grep '^CONTAINER_PORT=' /tmp/learn-dd-net-trace/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    if [ "$REPORT_CONTAINER_PORT" = "80" ]; then
        echo "PASS: CONTAINER_PORT correctly reported as 80"
    else
        echo "FAIL: CONTAINER_PORT should be 80, got: $REPORT_CONTAINER_PORT"
        FAILED=1
    fi

    # Check DNAT_RULE_EXISTS
    REPORT_DNAT=$(grep '^DNAT_RULE_EXISTS=' /tmp/learn-dd-net-trace/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    if [ "$REPORT_DNAT" = "yes" ]; then
        echo "PASS: DNAT rule existence confirmed"
    else
        echo "FAIL: DNAT_RULE_EXISTS should be 'yes', got: $REPORT_DNAT"
        FAILED=1
    fi

    # Check BRIDGE is present (accept docker0 or any value)
    REPORT_BRIDGE=$(grep '^BRIDGE=' /tmp/learn-dd-net-trace/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
    if [ -n "$REPORT_BRIDGE" ]; then
        echo "PASS: Bridge name reported ($REPORT_BRIDGE)"
    else
        echo "FAIL: BRIDGE must be specified in the report"
        FAILED=1
    fi
else
    echo "FAIL: Cannot validate report — file not found"
    FAILED=1
fi

echo ""

# ─── Challenge 02: K8s Service Routing ───────────────────────────────────────

echo "[ Challenge 02: K8s Service Routing ]"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "SKIP: kubectl not available — skipping K8s challenge verification"
    echo "      (This challenge requires a kind cluster)"
    echo ""
else
    # Check if cluster is reachable
    if ! kubectl cluster-info &> /dev/null; then
        echo "SKIP: No Kubernetes cluster reachable — skipping K8s challenge verification"
        echo ""
    else
        check \
            "Deployment 'learn-dd-net-echo' exists" \
            "kubectl get deployment learn-dd-net-echo -o name"

        check \
            "Deployment 'learn-dd-net-echo' has 2 ready replicas" \
            "[ \$(kubectl get deployment learn-dd-net-echo -o jsonpath='{.status.readyReplicas}' 2>/dev/null) = '2' ]"

        check \
            "Service 'learn-dd-net-echo-svc' exists" \
            "kubectl get service learn-dd-net-echo-svc -o name"

        check \
            "Report file exists at /tmp/learn-dd-net-k8s/report.txt" \
            "test -f /tmp/learn-dd-net-k8s/report.txt"

        # Validate report contents
        if [ -f /tmp/learn-dd-net-k8s/report.txt ]; then
            # Check CLUSTER_IP
            ACTUAL_CLUSTER_IP=$(kubectl get svc learn-dd-net-echo-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
            REPORT_CLUSTER_IP=$(grep '^CLUSTER_IP=' /tmp/learn-dd-net-k8s/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')

            if [ -n "$ACTUAL_CLUSTER_IP" ] && [ "$ACTUAL_CLUSTER_IP" = "$REPORT_CLUSTER_IP" ]; then
                echo "PASS: CLUSTER_IP matches actual Service ClusterIP ($ACTUAL_CLUSTER_IP)"
            else
                echo "FAIL: CLUSTER_IP ($REPORT_CLUSTER_IP) does not match actual ($ACTUAL_CLUSTER_IP)"
                FAILED=1
            fi

            # Check pod IPs (order-independent)
            ACTUAL_POD_IPS=$(kubectl get pods -l app=learn-dd-net-echo -o jsonpath='{.items[*].status.podIP}' 2>/dev/null)
            REPORT_POD_IP1=$(grep '^POD_IP_1=' /tmp/learn-dd-net-k8s/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
            REPORT_POD_IP2=$(grep '^POD_IP_2=' /tmp/learn-dd-net-k8s/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')

            POD_IPS_MATCH=false
            for ip in $ACTUAL_POD_IPS; do
                if [ "$ip" = "$REPORT_POD_IP1" ] || [ "$ip" = "$REPORT_POD_IP2" ]; then
                    POD_IPS_MATCH=true
                fi
            done

            if [ "$POD_IPS_MATCH" = "true" ]; then
                echo "PASS: Pod IPs in report match actual pod IPs"
            else
                echo "FAIL: Pod IPs ($REPORT_POD_IP1, $REPORT_POD_IP2) do not match actual ($ACTUAL_POD_IPS)"
                FAILED=1
            fi

            # Check SERVICE_PORT and TARGET_PORT
            REPORT_SVC_PORT=$(grep '^SERVICE_PORT=' /tmp/learn-dd-net-k8s/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
            REPORT_TGT_PORT=$(grep '^TARGET_PORT=' /tmp/learn-dd-net-k8s/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')

            if [ "$REPORT_SVC_PORT" = "80" ] && [ "$REPORT_TGT_PORT" = "5678" ]; then
                echo "PASS: SERVICE_PORT (80) and TARGET_PORT (5678) correct"
            else
                echo "FAIL: Expected SERVICE_PORT=80, TARGET_PORT=5678, got: $REPORT_SVC_PORT, $REPORT_TGT_PORT"
                FAILED=1
            fi

            # Check IPTABLES_RULES_FOUND
            REPORT_RULES=$(grep '^IPTABLES_RULES_FOUND=' /tmp/learn-dd-net-k8s/report.txt 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
            if [ "$REPORT_RULES" = "yes" ]; then
                echo "PASS: iptables rules confirmed found"
            else
                echo "FAIL: IPTABLES_RULES_FOUND should be 'yes', got: $REPORT_RULES"
                FAILED=1
            fi
        else
            echo "FAIL: Cannot validate K8s report — file not found"
            FAILED=1
        fi

        echo ""
    fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

if [ "$FAILED" -eq 0 ]; then
    echo "All checks passed! Deep Dive: Advanced Networking complete!"
    echo ""
    echo "Sarah: 'You can trace a packet from browser to pod. That puts you'"
    echo "       'ahead of 90% of people who use containers. When something'"
    echo "       'breaks at the network level, you know exactly where to look.'"
    echo ""
    echo "(★‿★) Packets have no secrets from you anymore."
    exit 0
else
    echo "Some checks failed. Review the FAIL lines above and try again."
    echo ""
    echo "Tips:"
    echo "  - Challenge 01: Make sure learn-dd-net-trace is running and port 7777 is accessible"
    echo "  - Challenge 02: Ensure the kind cluster is running and the deployment/service exist"
    exit 1
fi
