# Lesson 02: Seccomp and AppArmor

> "Namespaces and cgroups are the first wall. Seccomp and AppArmor are the second. They control what a container can actually do — down to individual kernel system calls."
> — Sarah

---

## Defense in Depth

Even with namespaces isolating what a container can see, the container still makes **system calls (syscalls)** to the shared kernel. Every file read, network connection, process creation, and memory allocation is a syscall. If a vulnerable syscall is exploited, an attacker could escape the container.

**Seccomp** restricts *which* syscalls a process can make.
**AppArmor** restricts *what resources* a process can access (files, network, capabilities).

Together with namespaces and cgroups, they form layers of defense:

```
Container process
    │
    ▼
  Seccomp filter (block dangerous syscalls)
    │
    ▼
  AppArmor profile (restrict file/network access)
    │
    ▼
  Capabilities (limit root powers)
    │
    ▼
  Namespaces (isolate view of system)
    │
    ▼
  cgroups (limit resources)
    │
    ▼
  Linux kernel
```

---

## Seccomp: System Call Filtering

### What syscalls are

A **syscall** is how a program asks the kernel to do something. There are ~300+ syscalls on Linux. Examples:

| Syscall | What it does |
|---------|-------------|
| `read` / `write` | Read from / write to a file descriptor |
| `open` / `openat` | Open a file |
| `socket` / `connect` | Network operations |
| `fork` / `clone` | Create new processes |
| `mount` | Mount a filesystem |
| `reboot` | Reboot the system |
| `ptrace` | Debug/trace another process |
| `kexec_load` | Load a new kernel |

Most containers only need a small subset. `reboot`, `kexec_load`, `mount`, and `ptrace` are dangerous and rarely needed.

### Docker's default seccomp profile

Docker applies a default seccomp profile that blocks ~44 syscalls considered dangerous. You can see it:

```bash
# The default profile blocks syscalls like:
# - kexec_load, kexec_file_load (load new kernel)
# - reboot (reboot the host)
# - mount, umount2 (mount filesystems)
# - unshare (create new namespaces)
# - ptrace (debug other processes)
# - clone with CLONE_NEWUSER (create user namespaces)
# - keyctl (kernel keyring access)
```

Check if seccomp is active on a container:

```bash
docker run --rm alpine grep Seccomp /proc/1/status
# Seccomp:     2
# Seccomp_filters:  1
```

`Seccomp: 2` means seccomp filter mode is active.

### What happens when a blocked syscall is called

The process receives `EPERM` (permission denied) or is killed with `SIGSYS`, depending on the profile's default action.

```bash
# This fails because the default profile blocks mount:
docker run --rm alpine mount -t tmpfs tmpfs /mnt
# mount: permission denied (are you root?)
# (seccomp blocked the mount syscall)
```

### Running without seccomp (dangerous — for comparison only)

```bash
# With --security-opt seccomp=unconfined:
docker run --rm --security-opt seccomp=unconfined alpine sh -c \
  'mount -t tmpfs tmpfs /mnt && echo "mount succeeded" && umount /mnt'
# mount succeeded
```

> ⚠️ Never use `seccomp=unconfined` in production. This is for understanding what the profile blocks.

---

## Custom Seccomp Profiles

Sometimes the default profile blocks a syscall your application needs. Instead of disabling seccomp entirely, create a custom profile that allows only what's needed.

### Profile structure

A seccomp profile is a JSON file:

```json
{
    "defaultAction": "SCMP_ACT_ERRNO",
    "architectures": [
        "SCMP_ARCH_X86_64",
        "SCMP_ARCH_AARCH64"
    ],
    "syscalls": [
        {
            "names": [
                "read", "write", "open", "close", "stat", "fstat",
                "mmap", "mprotect", "munmap", "brk",
                "rt_sigaction", "rt_sigprocmask",
                "ioctl", "access", "pipe", "select",
                "socket", "connect", "accept", "sendto", "recvfrom",
                "clone", "execve", "exit", "exit_group",
                "getpid", "getuid", "getgid",
                "arch_prctl", "futex", "set_tid_address",
                "openat", "newfstatat", "readlinkat"
            ],
            "action": "SCMP_ACT_ALLOW"
        }
    ]
}
```

- `defaultAction: SCMP_ACT_ERRNO` — block everything by default
- `syscalls[].action: SCMP_ACT_ALLOW` — allow these specific syscalls

### Using a custom profile

```bash
docker run --rm \
  --security-opt seccomp=/path/to/profile.json \
  alpine echo "running with custom seccomp"
```

### Discovering which syscalls your app needs

Use `strace` to trace syscalls:

```bash
# Trace what syscalls a process makes:
docker run --rm --security-opt seccomp=unconfined \
  alpine sh -c 'apk add --no-cache strace > /dev/null 2>&1 && strace -c echo hello 2>&1'
```

Or use Docker's built-in audit mode to log blocked syscalls:

```bash
# Generate a profile from a real run using OCI runtime hooks
# (requires additional tooling like oci-seccomp-bpf-hook)
```

---

## AppArmor: Mandatory Access Control

### What AppArmor does

**AppArmor** is a Linux Security Module (LSM) that restricts programs based on per-program profiles. Where seccomp controls *which syscalls* are allowed, AppArmor controls *what resources* those syscalls can access:

| Seccomp | AppArmor |
|---------|----------|
| "Can this process call `open`?" | "Can this process open `/etc/passwd`?" |
| "Can this process call `mount`?" | "Can this process mount anything at `/mnt`?" |
| "Can this process call `socket`?" | "Can this process create a raw socket?" |

### Docker's default AppArmor profile

Docker applies a default AppArmor profile (`docker-default`) that:
- Denies writing to `/proc` (except allowed entries)
- Denies writing to `/sys`
- Denies mounting filesystems
- Denies access to `/proc/kcore`, `/proc/sysrq-trigger`
- Restricts signal sending
- Denies `ptrace`

Check if AppArmor is active:

```bash
# On systems with AppArmor:
docker inspect <container> --format '{{.AppArmorProfile}}'
# docker-default

# Check from inside the container:
docker run --rm alpine cat /proc/1/attr/current
# docker-default (enforce)
```

> ⚠️ **Availability:** AppArmor is available on Debian, Ubuntu, and SUSE. It's not available on RHEL/CentOS/Fedora (they use SELinux instead). Docker Desktop's Linux VM may or may not have it enabled.

### Custom AppArmor profiles

```
#include <tunables/global>

profile docker-nocappuccino-app flags=(attach_disconnected) {
  #include <abstractions/base>

  # Allow reading configuration
  /app/config/** r,

  # Allow reading/writing to data directory
  /app/data/** rw,

  # Allow network access
  network inet tcp,
  network inet udp,

  # Deny everything else by default
  deny /proc/** w,
  deny /sys/** w,
  deny /etc/shadow r,
}
```

Load and use a custom profile:

```bash
# Load the profile:
sudo apparmor_parser -r /path/to/profile

# Use it:
docker run --rm --security-opt apparmor=docker-nocappuccino-app alpine sh
```

---

## Capabilities: Fine-Grained Root Powers

Linux capabilities split root's powers into ~40 individual privileges:

| Capability | What it allows |
|-----------|---------------|
| `CAP_NET_BIND_SERVICE` | Bind to ports < 1024 |
| `CAP_NET_ADMIN` | Configure network interfaces, routing, iptables |
| `CAP_SYS_ADMIN` | Mount, swapon, sethostname, and many more (the "almost root" capability) |
| `CAP_SYS_PTRACE` | Trace/debug other processes |
| `CAP_CHOWN` | Change file ownership |
| `CAP_DAC_OVERRIDE` | Bypass file permission checks |
| `CAP_SETUID` / `CAP_SETGID` | Change UID/GID |

Docker drops most capabilities by default. A container started with `docker run` gets only ~14 capabilities, not the full set.

```bash
# See what capabilities a container has:
docker run --rm alpine sh -c 'apk add --no-cache libcap > /dev/null 2>&1 && capsh --print'

# Drop all capabilities:
docker run --rm --cap-drop=ALL alpine id

# Add a specific capability:
docker run --rm --cap-drop=ALL --cap-add=NET_BIND_SERVICE alpine id
```

**Best practice:** Drop all capabilities with `--cap-drop=ALL` and add back only what's needed.

---

## Putting It Together: Layered Security

A production-hardened container uses all these layers:

```bash
docker run -d --name learn-dd-sec-hardened \
  --label app=learn-docker-k8s --label track=deep-dive \
  --user 1000:1000 \                     # Non-root user
  --cap-drop=ALL \                       # Drop all capabilities
  --cap-add=NET_BIND_SERVICE \           # Add only what's needed
  --security-opt=no-new-privileges \     # Prevent privilege escalation
  --security-opt seccomp=/path/to/custom-seccomp.json \  # Custom seccomp
  --read-only \                          # Read-only root filesystem
  --tmpfs /tmp \                         # Writable temp directory
  --memory 256m --cpus 0.5 \             # Resource limits
  nginx:alpine
```

Each layer adds defense. An attacker who bypasses one layer hits the next.

---

## Summary

- **Seccomp** filters syscalls — Docker's default profile blocks ~44 dangerous ones
- Custom seccomp profiles let you allow only the syscalls your app needs
- **AppArmor** restricts file, network, and capability access per-program
- **Capabilities** split root into ~40 individual privileges — drop all, add only what's needed
- `--security-opt=no-new-privileges` prevents escalation through setuid binaries
- Production containers should use all layers: non-root + seccomp + AppArmor + dropped capabilities + read-only FS

---

**Next:** [Supply Chain Security](03-supply-chain-security.md) — Trusting the images you run
