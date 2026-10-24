# Challenge 01: Custom Seccomp Profile

> "The default seccomp profile blocks `mount` for good reason. But we have a legit use case — a container that needs to mount a tmpfs for a high-performance cache. Your job: create a profile that allows just that, nothing more."
> — Sarah

---

## The Situation

NoCappuccino's recommendation engine needs to mount a tmpfs volume inside the container at runtime for a high-speed in-memory cache. The default seccomp profile blocks the `mount` syscall, so the container fails.

The naive fix is `--security-opt seccomp=unconfined` — but that removes ALL syscall filtering. Sarah wants you to create a custom seccomp profile that allows `mount` and `umount2` while keeping everything else locked down.

---

## Setup

First, verify the problem — the default seccomp profile blocks mount:

```bash
docker run --rm --name learn-dd-sec-test \
  --label app=learn-docker-k8s --label track=deep-dive \
  alpine sh -c 'mount -t tmpfs -o size=32m tmpfs /tmp/cache && echo "mount succeeded" && ls /tmp/cache'
```

This should fail with a permission error (seccomp blocks the `mount` syscall).

---

## Your Mission

1. Create a custom seccomp profile at `/tmp/learn-dd-sec/custom-seccomp.json`
2. The profile must:
   - Use Docker's default profile as a base (allow all the standard syscalls)
   - Additionally allow `mount` and `umount2` syscalls
   - NOT use `defaultAction: SCMP_ACT_ALLOW` (that would allow everything — defeats the purpose)
3. Run a container using your custom profile that successfully mounts a tmpfs
4. The container must be named `learn-dd-sec-mount` and remain running

---

## Requirements

1. Custom seccomp profile exists at `/tmp/learn-dd-sec/custom-seccomp.json`
2. The profile's `defaultAction` must be `SCMP_ACT_ERRNO` (block by default)
3. Container `learn-dd-sec-mount` must be running
4. Container must use the custom seccomp profile
5. Container must have labels `app=learn-docker-k8s` and `track=deep-dive`
6. The container must have successfully mounted a tmpfs at `/tmp/cache`

---

## Success Criteria

```bash
bash curriculum/deep-dives/container-security/challenges/verify.sh
```

---

## Hints

<details>
<summary>Hint 1 — Profile structure</summary>

A seccomp profile is JSON with `defaultAction` and `syscalls` array. You want `defaultAction` set to `SCMP_ACT_ERRNO` (block by default) and a `syscalls` entry with `action: SCMP_ACT_ALLOW` for the syscalls you want to permit.

The challenge is knowing which syscalls to allow. You need the "standard" set plus `mount` and `umount2`.

</details>

<details>
<summary>Hint 2 — Using Docker's default as a base</summary>

Docker's default seccomp profile is available at:
https://github.com/moby/moby/blob/master/profiles/seccomp/default.json

You can also extract it with:
```
docker info --format '{{json .SecurityOptions}}'
```

The easiest approach: take Docker's default profile, find the syscalls list, and add `mount` and `umount2` to the allowed list.

Alternatively, use `defaultAction: SCMP_ACT_LOG` during development to see which syscalls your container needs without blocking them.

</details>

<details>
<summary>Hint 3 — Practical approach</summary>

The simplest way to create a "default + mount" profile:

1. Get Docker's default profile:
   ```
   docker run --rm alpine cat /proc/1/status | grep Seccomp
   ```
   The default profile is complex. A simpler approach: create a profile that starts permissive but uses an allowlist structure.

2. Create the profile with the key syscalls. The minimum set for `alpine sh` to work plus `mount`/`umount2`:
   ```json
   {
       "defaultAction": "SCMP_ACT_ERRNO",
       "syscalls": [
           {
               "names": ["mount", "umount2", ...all other standard syscalls...],
               "action": "SCMP_ACT_ALLOW"
           }
       ]
   }
   ```

3. A pragmatic alternative: use Docker's default profile but change the rules for `mount` and `umount2` from blocked to allowed.

4. Run the container:
   ```
   docker run -d --name learn-dd-sec-mount \
     --label app=learn-docker-k8s --label track=deep-dive \
     --security-opt seccomp=/tmp/learn-dd-sec/custom-seccomp.json \
     alpine sh -c 'mount -t tmpfs -o size=32m tmpfs /tmp/cache && sleep 3600'
   ```

</details>

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You created a custom seccomp profile that extends Docker's default by allowing the `mount` and `umount2` syscalls. This let the container mount a tmpfs without disabling all seccomp filtering.

**Why it works:**
Seccomp profiles are evaluated by the kernel before any syscall executes. By adding `mount` and `umount2` to the allow list, the kernel permits those specific operations while still blocking dangerous syscalls like `kexec_load`, `reboot`, and `ptrace`.

**Real-world connection:**
Custom seccomp profiles are common in production. Applications that do filesystem operations, use specific kernel features, or need capabilities beyond the default set often require custom profiles. The key is allowing only what's needed — not disabling seccomp entirely.

**Interview angle:**
"How would you handle a container that needs a syscall blocked by the default seccomp profile?" The answer: create a custom seccomp profile based on the default, adding only the needed syscalls. Never use `seccomp=unconfined` in production. In Kubernetes, you can set seccomp profiles via the `securityContext.seccompProfile` field.

**Pro tip:**
In Kubernetes 1.27+, you can use the `SeccompDefault` feature gate to apply the default seccomp profile to all pods automatically. For custom profiles, use `securityContext.seccompProfile.type: Localhost` and place the profile on the node at `/var/lib/kubelet/seccomp/`. The Kubernetes Security Profiles Operator can manage this at scale.

</details>

---

## Cleanup

```bash
docker rm -f learn-dd-sec-mount 2>/dev/null
rm -rf /tmp/learn-dd-sec
```
