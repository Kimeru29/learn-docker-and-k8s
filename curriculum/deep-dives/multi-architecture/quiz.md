# Deep Dive Quiz: The Universal Bean — Multi-Architecture

This quiz is used for **skip-level assessment**. Score 4/5 or higher to skip this deep dive.

Answer each question before looking at the answers at the bottom.

---

## Questions

**Q1.** You build a Docker image on an M2 MacBook (ARM64) and push it. A colleague pulls it on an x86 CI server and gets `exec format error`. What happened?

- A) The image was corrupted during push
- B) The image contains ARM64 binaries that can't execute on an x86 CPU
- C) Docker Hub rejected the image because it's too large
- D) The CI server's Docker version is too old

---

**Q2.** What is a manifest list (image index) in the context of multi-architecture Docker images?

- A) A list of all files inside the container filesystem
- B) A JSON document that maps platform/architecture pairs to specific image digests
- C) A Docker Compose file that lists all services
- D) A registry access control list for image permissions

---

**Q3.** In a multi-platform Dockerfile, what does `FROM --platform=$BUILDPLATFORM golang:1.22 AS build` achieve?

- A) It forces the build stage to always use linux/amd64
- B) It runs the build stage on the host's native architecture, regardless of the target platform
- C) It skips the build stage if the platform doesn't match
- D) It downloads Go for every supported platform

---

**Q4.** Why can't you use `docker buildx build --platform linux/amd64,linux/arm64 --load .`?

- A) BuildKit doesn't support building for multiple platforms
- B) The `--load` flag only imports a single platform into the local daemon, but multi-platform builds produce multiple images
- C) You need to specify `--push` and `--load` together
- D) QEMU only supports one platform at a time

---

**Q5.** You need to build a Go application for both linux/amd64 and linux/arm64. What is the fastest approach?

- A) Build twice on the same machine with QEMU emulation for the foreign architecture
- B) Use `FROM --platform=$BUILDPLATFORM` and Go's native cross-compilation (`GOOS`/`GOARCH`)
- C) Maintain two separate Dockerfiles, one for each architecture
- D) Only build for amd64 and rely on QEMU emulation at runtime for arm64

---

## Answers

| # | Answer | Explanation |
|---|--------|-------------|
| Q1 | **B** | Docker images contain compiled binaries. An image built on ARM64 contains ARM64 binaries. The x86 CPU cannot execute ARM64 instructions natively, resulting in `exec format error`. The fix: rebuild with `--platform linux/amd64` or build a multi-arch image. |
| Q2 | **B** | A manifest list (OCI image index) is a JSON document stored in the registry that maps platform/architecture pairs (like `linux/amd64`, `linux/arm64`) to specific image digests. When you `docker pull`, Docker checks the manifest list and pulls only the image matching your platform. |
| Q3 | **B** | `--platform=$BUILDPLATFORM` tells BuildKit to run this stage on the host's native architecture. This is critical for cross-compilation: the Go compiler runs natively (fast) while targeting a different architecture via `GOOS`/`GOARCH`. Without this, the build stage would run under QEMU emulation (slow). |
| Q4 | **B** | The local Docker daemon can only store images for one platform at a time. `--load` imports the built image into the local daemon, which doesn't support storing multiple platform variants of the same tag. For multi-platform builds, you must `--push` to a registry, which stores the manifest list and all platform variants. |
| Q5 | **B** | Go supports native cross-compilation — you can compile for a different target architecture without emulation. Using `FROM --platform=$BUILDPLATFORM` runs the build natively, and setting `CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH` tells Go to output binaries for the target platform. This is near-native speed for both architectures. QEMU emulation (option A) works but is 5-10x slower for compilation. |

---

## Scoring

- **5/5** — Skip approved. You understand multi-arch builds inside and out.
- **4/5** — Skip approved. Review the explanation for your missed question.
- **3/5 or below** — Work through the lessons. Multi-arch is increasingly important and worth understanding hands-on.
