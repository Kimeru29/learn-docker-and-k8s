# Deep Dive Quiz: Under the Hood — Linux Internals

This quiz is used for **skip-level assessment**. Score 4/5 or higher to skip this deep dive.

Answer each question before looking at the answers at the bottom.

---

## Questions

**Q1.** A container's main process is PID 1 inside the container, but PID 4829 on the host. Which Linux kernel feature is responsible for this?

- A) cgroups — they reassign process IDs
- B) PID namespace — it creates an isolated process ID space
- C) OverlayFS — it virtualizes the /proc filesystem
- D) seccomp — it filters PID-related system calls

---

**Q2.** You run a container with `docker run --memory 256m`. The container tries to allocate 512MB of memory. What happens?

- A) The container is paused until memory is available
- B) Docker logs a warning but allows the allocation
- C) The kernel's OOM killer sends SIGKILL to the container's process (exit code 137)
- D) The allocation silently fails and returns NULL

---

**Q3.** You modify a file inside a running container. In OverlayFS terms, what happens?

- A) The file is modified directly in the lower (image) layer
- B) The file is copied from the lower layer to the upper layer, then the modification is applied to the upper copy
- C) OverlayFS creates a diff patch file in the workdir
- D) The entire layer containing the file is duplicated

---

**Q4.** You run `docker inspect mycontainer --format '{{.HostConfig.NanoCpus}}'` and get `500000000`. What does this mean in terms of CPU allocation?

- A) The container is limited to 500 CPU cores
- B) The container can use at most 0.5 of one CPU core
- C) The container has a guaranteed minimum of 500MHz
- D) The container can burst to 500% CPU for short periods

---

**Q5.** Two containers are running from the same `nginx:alpine` image. How does OverlayFS handle disk space?

- A) Each container gets a full copy of the image filesystem (2x disk usage)
- B) Both containers share the read-only image layers; only their writable upper layers are separate
- C) The second container creates hard links to the first container's files
- D) Docker deduplicates files at the block level using btrfs snapshots

---

## Answers

| # | Answer | Explanation |
|---|--------|-------------|
| Q1 | **B** | The **PID namespace** creates an isolated process ID space. The first process in a new PID namespace is assigned PID 1 within that namespace, while the kernel tracks a separate "real" PID in the host namespace. cgroups handle resource limits, not PID isolation. |
| Q2 | **C** | When a cgroup's memory limit (`memory.max`) is exceeded, the kernel's OOM killer terminates the process with SIGKILL (signal 9). The exit code is `128 + 9 = 137`. SIGKILL cannot be caught or handled — the process gets no warning and no chance for graceful shutdown. |
| Q3 | **B** | This is the **copy-on-write (copy-up)** mechanism. When a file in a lower (read-only) layer is modified, OverlayFS copies the entire file to the upper (writable) layer first, then applies the modification there. The lower layer remains untouched. Future reads of that file will see the upper layer version. |
| Q4 | **B** | NanoCpus are specified in nanoseconds of CPU time per second. `500000000` nanoseconds = 0.5 seconds of CPU time per second = 50% of one CPU core. Docker translates this to the CFS bandwidth control in cgroups (`cpu.max: 50000 100000`). |
| Q5 | **B** | OverlayFS allows multiple containers to share the same read-only image layers (lower dirs). Each container gets its own writable layer (upper dir). This is why running 100 containers from the same image uses almost no additional disk — only the writable layers (which contain only changes) are unique per container. |

---

## Scoring

- **5/5** — Skip approved. You understand the kernel foundations.
- **4/5** — Skip approved. Review the explanation for your missed question.
- **3/5 or below** — Work through the lessons. Seeing these concepts in action will make them click.
