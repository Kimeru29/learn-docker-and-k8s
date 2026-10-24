```
  ___ _   _ ___    _____ _            _               _       _
 / __| |_/ | __|  |_   _| |_  ___   | |   ___  __| |____| |_____ __ ___ _
| (__| ' \___ \    | | | ' \/ -_)  | |__/ _ \/ _| / / _` / _ \ V  V / ' \
 \___|_||_|___/    |_| |_||_\___|  |____\___/\__|_\_\__,_\___/\_/\_/|_||_|

    "Anyone can kubectl exec into any pod. That changes today."

    .----------------------------------------------.
    |  SECURITY AUDIT FINDINGS                      |
    |                                               |
    |  [CRITICAL] Default SA has cluster-admin      |
    |  [CRITICAL] DB creds in plain env vars        |
    |  [HIGH]     All pods run as root              |
    |  [HIGH]     No network policies               |
    |  [MEDIUM]   Capabilities not dropped          |
    |                                               |
    |  Sarah: "Time for RBAC."                      |
    '----------------------------------------------'
```

# Chapter 15: The Lockdown

## The Story

The security auditor just left. The report is not kind.

Every pod in the cluster runs as root with full Linux capabilities. The default ServiceAccount has unrestricted access to the Kubernetes API. Database credentials are stored as plain environment variables — visible in `kubectl describe`, pod logs, and `/proc` inside the container. There are no NetworkPolicies, so every pod can talk to every other pod across all namespaces.

Marcus reads the first page of the audit report and closes it. "How bad is it?"

Sarah doesn't sugarcoat it. "Bad. If someone gets shell access to any pod, they can read every secret in the cluster, exec into any other pod, and talk directly to the database. We need RBAC, security contexts, proper secret management, and network isolation. Today."

---

## What You'll Learn

By the end of this chapter, you will be able to:

- Create ServiceAccounts with specific RBAC permissions (least privilege)
- Verify what a ServiceAccount can and cannot do
- Apply security contexts: non-root, dropped capabilities, read-only filesystem
- Understand Pod Security Standards (Restricted, Baseline, Privileged)
- Manage Secrets properly: volume mounts over env vars, rotation, external secrets concepts
- Write NetworkPolicies for pod-to-pod isolation and egress control

---

## Prerequisites

- World 3: Kubernetes Core (ch09–ch12 completed)
- `learn-k8s` kind cluster running
- Familiarity with Services, Deployments, and ConfigMaps/Secrets

---

## Estimated Time

- Lessons: ~90 minutes
- Challenges: ~120 minutes
- Total: ~4–5 hours

---

## Lessons

| # | Lesson | What you'll learn |
|---|--------|-------------------|
| 01 | [RBAC](lessons/01-rbac.md) | ServiceAccounts, Roles, RoleBindings, the principal-verb-resource model |
| 02 | [Security Contexts](lessons/02-security-contexts.md) | Non-root, capabilities, read-only FS, Pod Security Standards |
| 03 | [Secrets Management](lessons/03-secrets-management.md) | Why base64 isn't encryption, volume mounts vs env vars, external secrets |
| 04 | [Network Security](lessons/04-network-security.md) | Default deny, explicit allow, namespace isolation, egress policies |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [RBAC Lockdown](challenges/01-rbac-lockdown.md) | Create a ServiceAccount that can only read pods in one namespace |
| 02 | [Harden Pods](challenges/02-harden-pods.md) | Apply security context to a pod running as root with all capabilities |
| 03 | [Secret Hygiene](challenges/03-secret-hygiene.md) | Move secrets from env vars to volume mounts and add network isolation |

To verify your work: `bash curriculum/world-4-kubernetes-production/ch15-k8s-security/challenges/verify.sh`

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **ServiceAccount** | Identity assigned to pods for Kubernetes API access |
| **Role** | Set of permissions (verbs on resources) in a single namespace |
| **ClusterRole** | Set of permissions across the entire cluster |
| **RoleBinding** | Grants a Role to a ServiceAccount/user in a namespace |
| **ClusterRoleBinding** | Grants a ClusterRole cluster-wide |
| **Security context** | Pod/container-level security settings (user, capabilities, FS) |
| **runAsNonRoot** | Prevents container from running as UID 0 |
| **readOnlyRootFilesystem** | Makes the container's root filesystem read-only |
| **Capabilities** | Fine-grained Linux privileges (drop ALL, add only what's needed) |
| **Pod Security Standards** | Cluster-wide policies: Privileged, Baseline, Restricted |
| **NetworkPolicy** | Firewall rules controlling pod-to-pod and pod-to-external traffic |

---

> **Sarah:** "Security in Kubernetes is not optional and it's not something you bolt on later. RBAC, security contexts, secret management, and network isolation — these are the four walls of a secure cluster. Right now, we have no walls."

**Start with:** [Lesson 01 — RBAC](lessons/01-rbac.md)
