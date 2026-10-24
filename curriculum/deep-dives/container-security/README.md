  _____ _          __   __          _ _
 |_   _| |_  ___  \ \ / /_ _ _  _| | |_
   | | | ' \/ -_)  \ V / _` | || | |  _|
   |_| |_||_\___|   \_/\__,_|\_,_|_|\__|

 🔐 Deep Dive: "The Vault"

    .-----------------------------------------------.
    |                                               |
    |  ┌─────────┐  seccomp    ┌──────────────┐    |
    |  │  App    │──filter───▶│   Kernel     │    |
    |  │ (non-  │             │  (syscalls)  │    |
    |  │  root) │  AppArmor   │              │    |
    |  └────┬───┘──profile───▶│              │    |
    |       │                  └──────────────┘    |
    |       │                                      |
    |  rootless   signed    scanned                |
    |  Docker     images    for CVEs               |
    |                                               |
    '-----------------------------------------------'

    (•‿•) Sarah: "Security isn't a checkbox.
           Let me show you the real defenses."

# Deep Dive: The Vault — Advanced Container Security

## Why This Deep Dive Exists

You've learned the basics of container security in Chapters 08 and 15 — non-root users, secrets management, read-only filesystems, RBAC. This deep dive goes further: rootless Docker, custom seccomp profiles, AppArmor, image signing, and vulnerability scanning.

These are the techniques that security auditors look for and that prevent containers from becoming an attack vector.

> *Sarah speaking:* "After the security audit in Chapter 08, I realized we were doing the minimum. Running as non-root is great, but what if an attacker escapes the container? What if the base image has a known CVE? What if someone pushes a malicious image to our registry? This deep dive covers the layers of defense that make those scenarios survivable."

---

## Prerequisites

- **Required:** Chapter 08 — Docker Security (completed)
- **Required:** Chapter 15 — Kubernetes Security (completed)
- You should be comfortable with non-root containers, Docker secrets, and Kubernetes RBAC

---

## What You'll Learn

- How rootless Docker works and when to use it
- What seccomp profiles are and how to create custom ones
- How AppArmor restricts container capabilities
- Image provenance, SBOMs, signing with cosign
- Vulnerability scanning with Trivy and remediation strategies

---

## Topics

| Topic | Description |
|-------|-------------|
| Rootless Docker | Running the Docker daemon without root privileges |
| Seccomp | System call filtering — controlling what the kernel allows |
| AppArmor | Mandatory access control profiles for containers |
| Image signing | Verifying image provenance with cosign and Docker Content Trust |
| SBOM | Software Bill of Materials — knowing what's in your images |
| Vulnerability scanning | Finding and fixing CVEs in container images |

---

## Lessons

| # | Lesson | Topics |
|---|--------|--------|
| 01 | [Rootless Docker](lessons/01-rootless-docker.md) | User namespaces, rootless setup, limitations, when to use |
| 02 | [Seccomp and AppArmor](lessons/02-seccomp-and-apparmor.md) | Syscall filtering, default profiles, custom profiles, AppArmor |
| 03 | [Supply Chain Security](lessons/03-supply-chain-security.md) | Image signing, SBOM, vulnerability scanning, trusted base images |

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Custom Seccomp Profile](challenges/01-custom-seccomp.md) | Create a seccomp profile that allows specific syscalls |
| 02 | [Scan and Fix](challenges/02-scan-and-fix.md) | Scan an image for CVEs and remediate critical vulnerabilities |

To verify your work: `bash curriculum/deep-dives/container-security/challenges/verify.sh`

---

## Estimated Time

- Lessons: ~45 minutes
- Challenges: ~30–45 minutes
- Total: ~1.5 hours

---

## Platform Notes

⚠️ **macOS / Docker Desktop users:** Rootless Docker is a Linux-only feature. The lesson explains the concepts and shows how it works, but you won't be able to run rootless Docker on macOS. Seccomp profiles work normally on Docker Desktop.

⚠️ **AppArmor:** Only available on Debian/Ubuntu-based systems. Docker Desktop on macOS uses a Linux VM that may or may not have AppArmor enabled. The lesson covers the concepts regardless.

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Rootless Docker** | Running dockerd as a non-root user, using user namespaces for isolation |
| **Seccomp** | Kernel feature to restrict which system calls a process can make |
| **AppArmor** | Linux Security Module that enforces per-program access control profiles |
| **Cosign** | Tool from Sigstore for signing and verifying container images |
| **SBOM** | Software Bill of Materials — a list of all components in a software artifact |
| **Trivy** | Open-source vulnerability scanner for container images, filesystems, and repos |
| **CVE** | Common Vulnerabilities and Exposures — standardized identifier for security flaws |
| **Docker Content Trust** | Docker's built-in image signing using Notary |
| **Supply chain attack** | Compromising software by attacking its dependencies, build tools, or distribution |
