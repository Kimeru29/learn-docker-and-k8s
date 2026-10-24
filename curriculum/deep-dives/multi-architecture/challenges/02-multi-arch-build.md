# Challenge 02: Multi-Arch Build

> "Time for the real thing. Build an image that works on both AMD64 and ARM64, push it to a local registry, and prove both architectures are available."
> — Sarah

---

## The Situation

NoCappuccino is deploying to both x86 cloud instances (AMD64) and AWS Graviton instances (ARM64) for cost savings. You need to build a multi-architecture image and push it to a registry so both environments can pull the right version automatically.

---

## Setup

### Start a local registry

```bash
docker run -d --name learn-dd-multi-registry \
  --label app=learn-docker-k8s --label track=deep-dive \
  -p 5555:5000 \
  registry:2
```

### Create a Go application

```bash
mkdir -p /tmp/learn-dd-multi-build
cat > /tmp/learn-dd-multi-build/main.go <<'EOF'
package main

import (
	"fmt"
	"net/http"
	"runtime"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, `{"service":"nocappuccino-api","arch":"%s","os":"%s"}`, runtime.GOARCH, runtime.GOOS)
	})
	fmt.Printf("NoCappuccino API listening on :8080 (arch: %s)\n", runtime.GOARCH)
	http.ListenAndServe(":8080", nil)
}
EOF

cat > /tmp/learn-dd-multi-build/go.mod <<'EOF'
module nocappuccino-api

go 1.22
EOF
```

### Create a cross-compilation Dockerfile

```bash
cat > /tmp/learn-dd-multi-build/Dockerfile <<'EOF'
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS build

ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY go.mod ./
COPY main.go ./

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /server .

FROM alpine:3.19
LABEL app=learn-docker-k8s
LABEL track=deep-dive
COPY --from=build /server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
EOF
```

---

## Your Mission

1. **Create a multi-platform builder** (if you don't already have one)
2. **Build the image for both `linux/amd64` and `linux/arm64`**
3. **Push to the local registry** at `localhost:5555/nocappuccino-api:multi`
4. **Verify** the manifest list contains both architectures
5. **Run the image** as `learn-dd-multi-app` and confirm it responds

---

## Requirements

1. Local registry container `learn-dd-multi-registry` must be running on port 5555
2. Image `localhost:5555/nocappuccino-api:multi` must exist in the registry
3. The image's manifest list must contain entries for both `linux/amd64` AND `linux/arm64`
4. Container `learn-dd-multi-app` must be running
5. Port 8888 must respond with a JSON body containing `"service":"nocappuccino-api"`
6. Container must have labels `app=learn-docker-k8s` and `track=deep-dive`

---

## Success Criteria

```bash
bash curriculum/deep-dives/multi-architecture/challenges/verify.sh
```

---

## Hints

<details>
<summary>Hint 1 — Creating a builder</summary>

You need a buildx builder that supports multi-platform builds:

```
docker buildx create --name learn-multiarch --use --bootstrap
```

Check it supports your target platforms:
```
docker buildx inspect learn-multiarch
```

</details>

<details>
<summary>Hint 2 — Building and pushing</summary>

Build for both platforms and push to the local registry:

```
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t localhost:5555/nocappuccino-api:multi \
  --push \
  /tmp/learn-dd-multi-build/
```

Remember: `--push` is required for multi-platform builds (can't use `--load` for multiple architectures).

</details>

<details>
<summary>Hint 3 — Verifying and running</summary>

Verify the manifest list:
```
docker manifest inspect localhost:5555/nocappuccino-api:multi
```

Pull and run:
```
docker pull localhost:5555/nocappuccino-api:multi

docker run -d --name learn-dd-multi-app \
  --label app=learn-docker-k8s --label track=deep-dive \
  -p 8888:8080 \
  localhost:5555/nocappuccino-api:multi
```

Test:
```
curl http://localhost:8888
```

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You built a Go application for both AMD64 and ARM64 architectures using `docker buildx`, pushed a multi-arch manifest list to a local registry, and ran the image successfully.

**Why it works:**
The Dockerfile uses `FROM --platform=$BUILDPLATFORM` for the build stage, so Go compiles natively (no QEMU needed). The `TARGETOS` and `TARGETARCH` build arguments tell Go's cross-compiler to output binaries for each target. BuildKit runs the build stage once per platform, produces two image variants, creates a manifest list, and pushes everything to the registry.

When you `docker pull` the image, Docker checks the manifest list, finds the entry matching your local platform, and pulls only those layers.

**Real-world connection:**
This is exactly how teams deploy to mixed-architecture clusters. AWS Graviton instances (ARM64) are 20-30% cheaper than equivalent x86 instances. By building multi-arch images, you can take advantage of ARM64 pricing without maintaining separate Dockerfiles or pipelines.

**Interview angle:**
"How would you build container images for both AMD64 and ARM64?" Answer: use `docker buildx` with `--platform linux/amd64,linux/arm64 --push`. For compiled languages like Go, use cross-compilation with `FROM --platform=$BUILDPLATFORM` and `ARG TARGETARCH` for near-native build speed. For interpreted languages, QEMU handles it but is slower.

**Pro tip:**
The Go cross-compilation approach in this challenge is the gold standard for multi-arch builds. The build stage runs at native speed (no emulation), and only the final `FROM alpine` layer is platform-specific (but it's just copying a binary — no compilation). This makes the build almost as fast as a single-platform build.

</details>

---

## Cleanup

```bash
docker rm -f learn-dd-multi-app learn-dd-multi-registry 2>/dev/null
docker buildx rm learn-multiarch 2>/dev/null
rm -rf /tmp/learn-dd-multi-build
```
