# Deep Dive Quiz: The Vault — Container Security

This quiz is used for **skip-level assessment**. Score 4/5 or higher to skip this deep dive.

Answer each question before looking at the answers at the bottom.

---

## Questions

**Q1.** What is the primary security benefit of rootless Docker?

- A) It prevents containers from accessing the network
- B) It runs the Docker daemon as a non-root user, so container escape doesn't grant host root access
- C) It encrypts all container filesystem data at rest
- D) It forces all containers to use read-only filesystems

---

**Q2.** A container runs with Docker's default seccomp profile and tries to call the `mount` syscall. What happens?

- A) The mount succeeds because Docker allows all syscalls by default
- B) The container is immediately terminated with SIGKILL
- C) The syscall is blocked and returns EPERM (permission denied)
- D) Docker logs a warning but allows the mount to proceed

---

**Q3.** You scan a container image with Trivy and find 3 CRITICAL vulnerabilities in `libssl3`. What is the most effective remediation?

- A) Add `RUN apt-get remove libssl3` to the Dockerfile
- B) Use `--security-opt seccomp=unconfined` to bypass the vulnerability
- C) Update the base image to a newer version that includes a patched `libssl3`
- D) Set `CVE_IGNORE=true` as an environment variable

---

**Q4.** What does cosign do in the context of container security?

- A) Signs and verifies container images to prove provenance and integrity
- B) Encrypts container network traffic between pods
- C) Scans container images for malware signatures
- D) Generates TLS certificates for container-to-container communication

---

**Q5.** You want to harden a production container. Which combination provides the best defense in depth?

- A) `--privileged` flag with a custom AppArmor profile
- B) `--user 1000 --cap-drop=ALL --security-opt=no-new-privileges --read-only` with a custom seccomp profile
- C) `--network=host` with `--security-opt seccomp=unconfined`
- D) Running as root with `--memory 256m` resource limits

---

## Answers

| # | Answer | Explanation |
|---|--------|-------------|
| Q1 | **B** | Rootless Docker runs `dockerd` as a non-root user, using user namespaces to map container UID 0 to an unprivileged host UID. If an attacker escapes the container, they land as an unprivileged user on the host — not root. This is the core security benefit. |
| Q2 | **C** | Docker's default seccomp profile blocks approximately 44 syscalls considered dangerous, including `mount`. When a blocked syscall is attempted, the kernel returns `EPERM` (permission denied). The container is not killed — the individual syscall simply fails. |
| Q3 | **C** | Most vulnerabilities in container images come from outdated OS packages in the base image. Updating to a newer base image (e.g., from `debian:bullseye` to `debian:bookworm`) typically includes patched versions of system libraries. Removing `libssl3` would break TLS entirely. |
| Q4 | **A** | Cosign (from the Sigstore project) is a tool for signing container images with a cryptographic signature. When you verify a signed image, you confirm that: (1) the image was built by a trusted party, (2) the image hasn't been tampered with since signing, and (3) the image matches a specific build pipeline. |
| Q5 | **B** | This combination provides multiple layers of defense: non-root user (limits privilege), `--cap-drop=ALL` (removes all Linux capabilities), `--security-opt=no-new-privileges` (prevents escalation via setuid), `--read-only` (prevents filesystem modification), and a custom seccomp profile (restricts syscalls). Option A uses `--privileged` which disables ALL security features. Options C and D weaken security. |

---

## Scoring

- **5/5** — Skip approved. Your security knowledge is solid.
- **4/5** — Skip approved. Review the explanation for your missed question.
- **3/5 or below** — Work through the lessons. Container security is too important to skim.
