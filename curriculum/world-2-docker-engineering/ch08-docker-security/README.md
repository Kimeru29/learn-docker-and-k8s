```
  ___ _    ___  ___
 / __| |_ / _ \( _ )
| (__| ' \ (_) / _ \
 \___|_||_\___/\___/

 🔒 "The Audit"

    SECURITY ASSESSMENT — CRITICAL FINDINGS

    ┌────────────────────────────────────────────┐
    │  Finding 1: All containers run as root  ❌  │
    │  Finding 2: DB creds in image history   ❌  │
    │  Finding 3: No resource limits          ❌  │
    │  Finding 4: Docker socket mounted       ❌  │
    │                                            │
    │  Severity: HIGH                            │
    │  Deadline: 2 weeks                         │
    └────────────────────────────────────────────┘

    (◎_◎;) Dave: "How bad is it?"
    (•_•)  Sarah: "Fixable. If we start now."
```

# Chapter 8: The Audit

> "A security auditor found root containers, leaked secrets in image layers, and no resource limits. Time to harden everything."
> — Sarah, forwarding the audit report

## The Story So Far

The debugging skills from Chapter 7 saved the team twice last week. Containers that crash get diagnosed and fixed in minutes. Dave started calling you "the container whisperer." Marcus is cautiously impressed.

Then the security audit happened.

NoCappuccino hired an external security firm as part of their Series A due diligence. The auditor spent three days poking at the infrastructure. Their report landed on Dave's desk like a brick:

1. **Every container runs as root.** If an attacker compromises the web app, they get root inside the container — which can be escalated to root on the host in certain configurations.

2. **Database credentials are visible in `docker history`.** Someone used `ENV DB_PASSWORD=...` in a Dockerfile. The secret is permanently baked into the image layer. Anyone who can pull the image can see it.

3. **No resource limits.** A single compromised container could consume all host CPU and memory, taking down every other service — a denial-of-service from the inside.

4. **Docker socket mounted in a dev container.** A development tool has access to the Docker socket, which is equivalent to root access on the host. The auditor's exact words: "This is the same as giving the container the keys to the entire server."

Dave reads the report three times. Then he looks at you and Sarah.

Sarah is already walking toward your desk. "I've been waiting for this conversation. Let's fix everything."

---

## Chapter Objectives

By the end of this chapter, you will be able to:

1. Run containers as non-root users and fix common permission issues that arise
2. Detect and prevent secret leakage through Docker image layers
3. Use multi-stage builds as a security boundary
4. Drop Linux capabilities and set read-only root filesystems
5. Apply resource limits as a security measure
6. Understand Docker socket exposure risks
7. Apply least-privilege principles to a multi-service Compose stack

---

## Lessons

| # | Lesson | Concepts |
|---|--------|----------|
| 01 | [Running as Non-Root](lessons/01-running-as-non-root.md) | USER instruction, UID/GID, permission fixes, why root is dangerous |
| 02 | [Image Security](lessons/02-image-security.md) | Layer secrets, .dockerignore, multi-stage as security, base image choice |
| 03 | [Runtime Security](lessons/03-runtime-security.md) | Capabilities, read-only filesystem, resource limits, Docker socket |

## Challenges

| # | Challenge | Focus |
|---|-----------|-------|
| 01 | [Harden the Container](challenges/01-harden-the-container.md) | Switch to non-root, drop capabilities, read-only filesystem |
| 02 | [Clean the Layers](challenges/02-clean-the-layers.md) | Remove credentials baked into image layers |
| 03 | [Least Privilege](challenges/03-least-privilege.md) | Harden a full Compose stack: non-root, network isolation, limits |

---

## Post-Chapter Debrief

Once you complete all three challenges and `verify.sh` passes:

**What you did:** Hardened NoCappuccino's container stack from the ground up — non-root users, no leaked secrets, dropped capabilities, read-only filesystems, network isolation, and resource limits.

**Why it matters:** Container security is not optional. Containers share a kernel with the host. A container running as root with full capabilities is one exploit away from host compromise. The fixes you applied are the minimum standard for any production deployment.

**Real-world connection:** Every container security benchmark (CIS Docker Benchmark, NIST, SOC 2) requires these controls. Major cloud providers (AWS ECS, GCP Cloud Run, Azure Container Instances) enforce non-root by default or strongly recommend it. Kubernetes PodSecurityStandards can reject containers that run as root.

**Interview angle:** "How do you secure a Docker container for production?" Hit these points: non-root USER, minimal base image, no secrets in layers, dropped capabilities, read-only root filesystem, resource limits, network segmentation. This question separates developers who've run containers from those who've run them in production.

**Pro tip:** Security scanning tools like Trivy, Snyk, and Docker Scout can automatically check images for known vulnerabilities, leaked secrets, and insecure configurations. Integrate them into your CI pipeline to catch issues before they reach production.

---

## The Cliffhanger

The audit findings are all resolved. Dave sends the remediation report back to the security firm. They respond with: "Significant improvement. Approved for production."

Sarah smiles. "Good work. But we have one more test."

She pulls up a Slack message from Dave: "The coffee influencer is back. She just posted about our new cold brew subscription. Last time, our single server melted. We need to be ready."

Sarah turns to you. "Everything you've learned — Compose, process management, debugging, security — we're about to test it all at once. The NoCappuccino stack is about to face the Full Stack Meltdown."

*Boss Fight: The Full Stack Meltdown — coming up.*
