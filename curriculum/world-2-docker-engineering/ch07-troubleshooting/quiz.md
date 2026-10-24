# Chapter 7 Quiz: The Debugging Grind

> "Debugging isn't a talent. It's a process. These questions test whether the process is in your bones."
> — Sarah

---

## Question 1

A container exits with code 137. `docker inspect` shows `"OOMKilled": true`. What happened, and what's your immediate response?

A) The container received SIGTERM (signal 15) and shut down gracefully. No action needed.

B) The container exceeded its memory limit and the Linux kernel's OOM killer terminated it with SIGKILL (signal 9). Check `docker stats` for memory trends, verify the memory limit, and either increase the limit or fix the memory leak.

C) Exit code 137 means the Docker daemon crashed. Restart Docker Desktop.

D) The container's health check failed 137 times. Reduce the health check interval.

<details>
<summary>Answer</summary>

**B** is correct.

Exit code 137 = 128 + 9 (SIGKILL). When `OOMKilled` is `true`, it means the container used more memory than its configured limit. The kernel's OOM killer sent SIGKILL to terminate the process immediately.

Immediate response:
1. `docker stats --no-stream` — check memory usage of running containers
2. `docker inspect --format '{{.HostConfig.Memory}}'` — verify the limit
3. `docker events --since 1h --filter event=oom` — check the timeline
4. Decide: increase the limit or fix the application's memory usage

Option A is wrong: SIGTERM is signal 15, which gives exit code 143 (128 + 15). Option C is wrong: 137 relates to the container process, not the Docker daemon.

</details>

---

## Question 2

A developer runs `docker compose up -d` after changing their application code, but the API still returns the old response. What is the most likely cause?

A) Docker has a deployment cooldown period of 5 minutes

B) `docker compose up -d` reuses the cached image — it does not rebuild. The developer needs to run `docker compose up -d --build` to force a rebuild.

C) The developer needs to clear their browser cache

D) Environment variables are cached at the container level and require `docker compose restart`

<details>
<summary>Answer</summary>

**B** is correct.

`docker compose up -d` checks if an image exists for each service. If the image is cached (from a previous build), Compose uses the cached image — it does not re-run the Dockerfile. Source code changes on disk are not reflected in the running container.

The fix:
```bash
docker compose up -d --build
```

This forces Compose to re-run the `docker build` step, which picks up the updated source files via `COPY` instructions, creates a new image, and starts containers with the new code.

You can verify staleness by checking when the image was created:
```bash
docker inspect <image> --format '{{.Created}}'
```

</details>

---

## Question 3

You're following the 6-step debugging ladder. A container shows `Exited (127)` in `docker ps -a`. What does exit code 127 mean, and which step of the ladder should you go to?

A) Exit code 127 means the network is unreachable. Go to Step 5 (Test Connectivity).

B) Exit code 127 means "command not found" — the binary specified in CMD or ENTRYPOINT doesn't exist in the image. Go to Step 3 (Inspect Configuration) to check the CMD.

C) Exit code 127 means the container ran out of disk space. Go to Step 4 (Check Resources).

D) Exit code 127 is a Docker-internal error. Contact Docker support.

<details>
<summary>Answer</summary>

**B** is correct.

Exit code 127 is the standard Unix code for "command not found." The CMD or ENTRYPOINT in the Dockerfile (or the command override) references a binary that doesn't exist in the image.

Common causes:
- Typo in CMD: `CMD ["nod", "server.js"]` (should be `node`)
- Multi-stage build: binary was built in stage 1 but not `COPY`ed to stage 2
- Wrong base image: the binary exists in `debian` but not `alpine`
- Wrong `WORKDIR`: the script exists but the container is looking in the wrong directory

Diagnose with:
```bash
docker inspect <container> --format '{{.Config.Cmd}} {{.Config.Entrypoint}}'
docker run --rm --entrypoint sh <image> -c "which node"
```

</details>

---

## Question 4

`docker ps` shows a container with status `Restarting (1) 3 seconds ago`. The restart count from `docker inspect` is 47. What is happening, and what's the correct first step?

A) The container is in a restart loop — it crashes on startup and the restart policy keeps restarting it. First step: `docker stop` to break the loop, then `docker logs` to read the crash output.

B) The container restarted 47 times successfully. This is normal behavior for long-running services.

C) Docker is performing 47 rolling updates. Wait for it to complete.

D) The restart count indicates 47 health check failures. Remove the health check.

<details>
<summary>Answer</summary>

**A** is correct.

A restart count of 47 with the container currently showing `Restarting (1)` means the container keeps crashing (exit code 1 = application error) and the restart policy keeps restarting it. This is a crash loop.

The correct approach:
1. `docker stop <container>` — break the loop so logs stop being overwritten
2. `docker logs --tail 50 <container>` — read the last crash output
3. Diagnose the root cause (missing dependency, bad config, wrong image)
4. Fix and restart

Common mistake: leaving the container running while trying to read logs. In a crash loop, logs from each restart attempt are mixed together. Stopping the container freezes the state so you can read the last failure clearly.

</details>

---

## Question 5

You need to check if a container is consuming too much memory. Which command gives you a live view of CPU, memory, and network usage for all containers?

A) `docker inspect --format '{{.State.Memory}}'`

B) `docker stats`

C) `docker system df`

D) `docker top`

<details>
<summary>Answer</summary>

**B** is correct.

`docker stats` provides a live-updating dashboard of resource usage:
```
NAME          CPU %   MEM USAGE / LIMIT   MEM %   NET I/O
backend       2.3%    120MiB / 512MiB     23.4%   1.2MB / 890kB
postgres      5.1%    89MiB / 512MiB      17.4%   45kB / 120kB
```

Use `docker stats --no-stream` for a one-time snapshot (useful in scripts).

Option A (`docker inspect`) shows configuration, not live usage. Option C (`docker system df`) shows disk usage (images, containers, volumes), not live resource consumption. Option D (`docker top`) shows the process list inside a container, not resource metrics.

</details>
