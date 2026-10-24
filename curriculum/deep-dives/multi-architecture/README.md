  _____ _          _   _      _                     _   ___
 |_   _| |_  ___  | | | |_ _ (_)_ _____ _ _ ___ __ _| | | _ ) ___ __ _ _ _
   | | | ' \/ -_) | |_| | ' \| \ V / -_) '_(_-</ _` | | | _ \/ -_) _` | ' \
   |_| |_||_\___|  \___/|_||_|_|\_/\___|_| /__/\__,_|_| |___/\___\__,_|_||_|

 🌍 Deep Dive: "The Universal Bean"

    ┌─────────────────────────────────────────┐
    │         manifest list (tag: v1.0)       │
    │  ┌──────────┐  ┌──────────┐            │
    │  │ linux/   │  │ linux/   │            │
    │  │ amd64    │  │ arm64    │            │
    │  │ (x86_64) │  │ (Apple   │            │
    │  │          │  │  Silicon,│            │
    │  │          │  │  AWS     │            │
    │  │          │  │  Graviton)│           │
    │  └──────────┘  └──────────┘            │
    └─────────────────────────────────────────┘

    (•‿•) Sarah: "Build once, run anywhere.
           For real this time."

# Deep Dive: The Universal Bean — Multi-Platform Container Builds

## Why This Deep Dive Exists

You've been building Docker images that work on your machine. But what happens when your M1/M2/M3 Mac builds an image and someone tries to run it on an x86 server? Or you build on x86 CI and need to run on AWS Graviton (ARM64)?

The image fails. Silently, confusingly, and usually in production.

This deep dive teaches you how to build images that work on any architecture — using `docker buildx`, manifest lists, QEMU emulation, and native cross-compilation.

> *Sarah speaking:* "When we moved to Apple Silicon MacBooks at NoCappuccino, half our Docker images broke on the CI server. Dave's 'it works on my machine' had a whole new meaning. Let me show you how to never have that problem again."

---

## Prerequisites

- **Required:** Chapter 02 — Image Engineering (completed)
- You should be comfortable building Docker images and understand Dockerfile instructions

---

## What You'll Learn

- Why container images are architecture-specific
- How manifest lists let Docker serve the right image automatically
- How to use `docker buildx` for multi-platform builds
- QEMU emulation vs native cross-compilation
- Testing and CI considerations for multi-arch images

---

## Topics

| Topic | Description |
|-------|-------------|
| Architecture specificity | Why an image built on ARM64 won't run on AMD64 |
| Manifest lists | Multi-arch index that maps architectures to image digests |
| docker buildx | BuildKit-based builder for multi-platform images |
| QEMU | User-space CPU emulation for cross-architecture builds |
| Cross-compilation | Building for a target architecture without emulation |
| CI pipelines | Automating multi-arch builds in GitHub Actions, etc. |

---

## Lessons

| # | Lesson | Topics |
|---|--------|--------|
| 01 | [Why Multi-Arch](lessons/01-why-multi-arch.md) | Architecture specificity, manifest lists, the Apple Silicon problem |
| 02 | [Buildx Multi-Platform](lessons/02-buildx-multi-platform.md) | Buildx, QEMU, cross-compilation, pushing manifests |
| 03 | [Testing and CI](lessons/03-testing-and-ci.md) | Testing across architectures, CI pipelines, platform detection |

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Detect and Fix](challenges/01-detect-and-fix.md) | Detect an architecture mismatch and rebuild correctly |
| 02 | [Multi-Arch Build](challenges/02-multi-arch-build.md) | Build for amd64 and arm64, push to a local registry |

To verify your work: `bash curriculum/deep-dives/multi-architecture/challenges/verify.sh`

---

## Estimated Time

- Lessons: ~30 minutes
- Challenges: ~30 minutes
- Total: ~1 hour

---

## Platform Notes

This deep dive works on all platforms — it's specifically about handling platform differences!

- **Apple Silicon Mac:** You're building ARM64 images natively. QEMU lets you build AMD64 too.
- **x86 Linux/Mac:** You're building AMD64 natively. QEMU lets you build ARM64 too.
- **Docker Desktop:** Includes QEMU and buildx support out of the box.
- **Linux (native Docker):** May need to install QEMU and register binfmt handlers manually.

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **AMD64 (x86_64)** | Intel/AMD 64-bit architecture — traditional servers and PCs |
| **ARM64 (aarch64)** | ARM 64-bit architecture — Apple Silicon, AWS Graviton, Raspberry Pi 4+ |
| **Manifest list** | An index that maps platform/architecture pairs to specific image digests |
| **docker buildx** | BuildKit-based CLI for advanced builds, including multi-platform |
| **QEMU** | User-space CPU emulator — runs ARM binaries on x86 (and vice versa) |
| **binfmt_misc** | Linux kernel feature that delegates binary execution to QEMU based on file format |
| **Cross-compilation** | Compiling code for a different architecture than the build machine (faster than emulation) |
| **`--platform`** | Docker flag to specify target architecture (e.g., `linux/amd64`, `linux/arm64`) |
