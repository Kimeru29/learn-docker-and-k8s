# Validation Guide

## How to Verify Challenges

### Priority Order
1. If `challenges/verify.sh` exists for the chapter, run it
2. If not, use the inline verification commands specified in each challenge file
3. As a last resort, use Docker/kubectl inspection commands

### verify.sh Contract

Every `verify.sh` follows this contract:

```bash
#!/bin/bash
# Exit 0 = all checks passed
# Exit 1 = one or more checks failed
# Output: human-readable status for each check

# Example check pattern:
check_result() {
    local description="$1"
    local command="$2"

    if eval "$command" > /dev/null 2>&1; then
        echo "PASS: $description"
    else
        echo "FAIL: $description"
        FAILED=1
    fi
}
```

### Common Verification Patterns

#### Container Running
```bash
docker ps --filter "name=learn-ch01-nginx" --filter "status=running" -q | grep -q .
```

#### Port Accessible
```bash
curl -sf http://localhost:8080 > /dev/null
```

#### Image Size Below Threshold
```bash
size=$(docker image inspect learn-ch02-app:optimized --format '{{.Size}}')
[ "$size" -lt 104857600 ]  # 100MB in bytes
```

#### Volume Exists and Has Data
```bash
docker volume inspect learn-ch03-db-data > /dev/null 2>&1
```

#### Network Connectivity Between Containers
```bash
docker exec learn-ch04-frontend ping -c 1 learn-ch04-backend > /dev/null 2>&1
```

#### Container Name Resolution
```bash
docker exec learn-ch04-frontend nslookup learn-ch04-backend > /dev/null 2>&1
```

#### K8s Pod Count Matches
```bash
count=$(kubectl get pods -n learn-ch06 -l app=nginx --field-selector status.phase=Running --no-headers | wc -l)
[ "$count" -eq 3 ]
```

#### K8s Service Endpoint Reachable
```bash
kubectl run learn-test-curl --rm -i --restart=Never -n learn-ch06 --image=curlimages/curl -- curl -sf http://frontend-svc:80
```

### Verification Philosophy

Verification should test **outcomes and invariants**, not exact implementations.

**Good verification** (outcome-based):
- Image size is under 100MB
- Application responds on expected port
- Data persists after container restart
- Containers can communicate by name
- No processes running as root

**Bad verification** (implementation-specific):
- Dockerfile contains exactly `FROM alpine:3.21`
- The YAML has exactly 3 spaces of indentation
- The volume is named exactly `learn-ch03-db-data`

When multiple valid solutions exist (and they usually do), the verifier should accept all of them. The post-challenge debrief is where the AI discusses quality differences between approaches.

### Verification Output Format

When reporting to the player:

**All Passed:**
```
=== Challenge Verification ===
PASS: Container 'learn-ch01-nginx' is running
PASS: Port 8080 is accessible
PASS: Response contains "Welcome to nginx"

All checks passed! Challenge complete!
```

**Some Failed:**
```
=== Challenge Verification ===
PASS: Container 'learn-ch01-nginx' is running
FAIL: Port 8080 is not accessible
HINT: Check if you mapped the port correctly with -p

1 of 2 checks passed. Keep going!
```

### Boss Fight Verification

Boss fights have multiple independent failure checks. Report each one separately so the player can triage:

```
=== Boss Fight: The Morning From Hell ===

Issue 1 — Image Bloat:
  PASS: Image size under 100MB
  PASS: No compiler tools in final image

Issue 2 — Data Persistence:
  FAIL: Database data did not survive restart
  HINT: Check your volume configuration

Issue 3 — Network Connectivity:
  PASS: Frontend can reach backend by name

Issue 4 — Port Access:
  PASS: Frontend accessible on port 8080

3 of 4 issues resolved. One more to go!
```

### K8s Additional Verification Patterns

#### Pod Security Context
```bash
kubectl get pod -n learn-ch15 -o jsonpath='{.spec.containers[0].securityContext.runAsNonRoot}' | grep -q "true"
```

#### HPA Scaling
```bash
replicas=$(kubectl get hpa -n learn-ch14 -o jsonpath='{.status.currentReplicas}')
[ "$replicas" -gt 1 ]
```

#### Secret Not in Env Vars
```bash
# Verify secret is mounted as file, not env var
kubectl get pod -n learn-ch15 -o jsonpath='{.spec.containers[0].env[*].name}' | grep -qv "DB_PASSWORD"
```

#### RBAC Restriction
```bash
# Verify ServiceAccount cannot create pods
kubectl auth can-i create pods --as=system:serviceaccount:learn-ch15:readonly-sa -n learn-ch15 | grep -q "no"
```

#### Graceful Shutdown Time
```bash
# Verify pod stops within acceptable time
start=$(date +%s)
kubectl delete pod -n learn-ch13 -l app=learn-test --wait=true
end=$(date +%s)
elapsed=$((end - start))
[ "$elapsed" -lt 5 ]
```

### Platform-Aware Verification

Some checks need platform adaptation:

```bash
# Detect architecture for image checks
ARCH=$(uname -m)
case "$ARCH" in
    arm64|aarch64)
        # ARM64: some images may be larger due to emulation layers
        THRESHOLD=157286400  # 150MB
        ;;
    *)
        THRESHOLD=104857600  # 100MB
        ;;
esac
```

### Curriculum Self-Testing

Run `bash tests/test-curriculum.sh` to validate curriculum integrity:
- Every chapter has a README, lessons, challenges, and quiz
- Every verify.sh is valid bash
- Cross-references between files are consistent
- No hardcoded architecture assumptions in fixtures

See `tests/test-curriculum.sh` for the full test suite.
