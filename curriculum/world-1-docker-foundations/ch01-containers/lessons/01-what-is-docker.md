# Lesson 01: What is Docker?

*Sarah speaking:* Alright, grab your coffee -- we're starting from the beginning. I know "what is Docker" feels like a basic question, but I've seen people use Docker for two years without really understanding *why* it exists. That understanding is what separates someone who cargo-cults commands from someone who can actually debug things when they break at 3 AM.

---

## The Problem Docker Was Built to Solve

Let me tell you what happened before Docker existed.

You write an app. It works perfectly. You hand it to ops. Ops runs it on a server. It crashes. Ops says the server has Python 3.8, you developed on Python 3.11. You say "just upgrade Python." Ops says that'll break two other apps. Everyone is frustrated. Nothing ships.

This is what the industry called **dependency hell**, and it was a genuine, daily source of pain for every engineering team in the world.

The old solution was to give each app its own server. Expensive, slow to provision, and wasteful -- most of the time a server sits at 5% CPU while you're paying for 100%.

Then came **virtual machines** (VMs). A VM is a full computer running inside your computer -- its own OS, its own kernel, its own simulated hardware. You could run five VMs on one server and each app would have its own isolated environment.

VMs solved the isolation problem, but they came with a cost: each VM carries a full OS. That's 1-2 GB of overhead per VM, and it takes minutes to start.

---

## Enter Containers

A container is a different approach. Instead of virtualizing the hardware, containers virtualize *just the application environment*.

Here's the key difference:

```
Virtual Machine:
+----------------------------------+
|  App A   |  App B   |  App C     |
|  Python  |  Node    |  Java      |
|  3.11    |  18      |  17        |
|----------+----------+------------|
|  Guest   |  Guest   |  Guest     |
|  OS      |  OS      |  OS        |
+----------+----------+------------+
|        Hypervisor                |
+----------------------------------+
|      Host OS + Kernel            |
+----------------------------------+

Container:
+----------------------------------+
|  App A   |  App B   |  App C     |
|  Python  |  Node    |  Java      |
|  3.11    |  18      |  17        |
|----------+----------+------------|
|        Container Runtime         |
|        (Docker Engine)           |
+----------------------------------+
|      Host OS + Kernel            |
+----------------------------------+
```

Containers share the host OS kernel. There's no guest OS overhead. A container starts in milliseconds. A typical container image is megabytes, not gigabytes.

The isolation is real -- App A genuinely cannot see App B's files or processes -- but it's achieved differently than VMs. Which brings us to the Linux underpinnings.

---

## The Linux Magic: Namespaces and cgroups

Docker isn't magic. It's a very clever use of two Linux kernel features that have existed since 2008. Understanding these at a high level will help you debug things later.

### Namespaces -- the invisible walls

A **namespace** wraps a system resource in an abstraction, making it look like the process has its own isolated copy of that resource. Docker uses several:

| Namespace | What it isolates |
|-----------|-----------------|
| `pid` | Process IDs -- container processes can't see host processes |
| `net` | Network interfaces -- each container gets its own network stack |
| `mnt` | Filesystem mounts -- container has its own filesystem view |
| `uts` | Hostname -- each container can have a different hostname |
| `ipc` | Inter-process communication queues |
| `user` | User IDs -- can map container root to unprivileged host user |

When you run a container, you're really just starting a process on the host -- but wrapped in a set of namespaces that make it think it's alone in the world. Dave's Node app doesn't know it's sharing a machine with anything else.

### cgroups -- the resource limits

**Control groups (cgroups)** are how the Linux kernel limits and accounts for resource usage. Docker uses cgroups to enforce things like:

- This container gets at most 512MB of RAM
- This container can use at most 50% of one CPU core
- This container's disk I/O is rate-limited

Without cgroups, one runaway process could consume all available resources and starve every other container. cgroups are the bouncer at the door.

You don't need to memorize cgroup commands right now. Just know that when you see flags like `--memory 512m` or `--cpus 0.5` on `docker run`, those translate directly to cgroup limits under the hood.

---

## The Docker Runtime Stack

When you type `docker run nginx`, several pieces of software cooperate to make it happen. Understanding this stack helps you debug issues and makes sense of the terminology you'll see in docs and job descriptions.

```
You type: docker run nginx
              |
              v
   +--------------------+
   |   Docker CLI        |   <-- The `docker` command you type
   |   (client)          |       Sends API calls to the daemon
   +--------------------+
              |  REST API (usually unix socket)
              v
   +--------------------+
   |   Docker Daemon     |   <-- dockerd: manages images, containers,
   |   (dockerd)         |       networks, volumes. Runs as root.
   +--------------------+
              |  gRPC
              v
   +--------------------+
   |   containerd        |   <-- Container runtime: manages container
   |                     |       lifecycle (create, start, stop, delete)
   +--------------------+
              |  OCI spec
              v
   +--------------------+
   |   runc              |   <-- Low-level OCI runtime: actually creates
   |                     |       the namespaces, cgroups, and launches
   |                     |       the container process
   +--------------------+
```

- **Docker CLI** (`docker`): The command-line tool. It's just a client -- it talks to the daemon over a REST API (usually via a Unix socket at `/var/run/docker.sock`).
- **Docker Daemon** (`dockerd`): The brain. It manages images, containers, networks, and volumes. It runs as a background service and requires root privileges (or rootless mode).
- **containerd**: A container runtime that sits between the daemon and the actual container process. It handles the full lifecycle: pulling images, creating containers, managing storage.
- **runc**: The lowest level. It reads the OCI container spec and uses Linux kernel features (namespaces, cgroups) to actually create and run the container process.

You can think of it like a restaurant: the CLI is the customer placing an order, dockerd is the head chef coordinating everything, containerd is the line cook managing the actual cooking, and runc is the burner that applies heat.

Most of the time you only interact with the CLI. But knowing the stack helps when things go wrong -- "is the daemon running?" is always the first question.

---

## Docker Desktop vs Native Docker Engine

If you're on macOS or Windows, you're probably running **Docker Desktop**. It's worth knowing how it differs from native Docker on Linux:

| | Docker Desktop (macOS/Windows) | Native Docker Engine (Linux) |
|---|---|---|
| **How it runs** | Inside a lightweight Linux VM | Directly on your kernel |
| **Performance** | Slight overhead from VM | Native performance |
| **File sharing** | Host files shared into VM (can be slow for bind mounts) | Direct filesystem access |
| **host networking** | `--network host` behaves differently (connects to VM, not your Mac) | True host networking |
| **Volume paths** | `/var/lib/docker/volumes/` is inside the VM | Directly on your host filesystem |

Docker Desktop is perfectly fine for learning and development. Just know that when you see a path like `/var/lib/docker/volumes/my-data/_data`, that path is inside the VM -- you can't `ls` it directly from your Mac terminal.

Alternatives to Docker Desktop on macOS include **colima** and **Rancher Desktop** -- both run a Linux VM but with different UIs and licensing. On Linux, you typically install Docker Engine directly from docker.com or your package manager.

---

## The Shipping Container Analogy

Docker's logo is a whale carrying shipping containers. That's not random.

Before standardized shipping containers existed, loading cargo onto a ship was a nightmare. Every item had a different shape. Dock workers had to figure out how to pack everything by hand. It was slow, expensive, and things got damaged in transit.

The 20-foot ISO shipping container changed everything. It doesn't matter what's inside -- electronics, furniture, bananas, engines. The container has a standard size and standard connectors. Cranes, ships, trucks, and trains are all built to handle that one standard format.

Docker containers work the same way. It doesn't matter if your app is written in Python, Node, Java, or Go. It doesn't matter what libraries it needs. Once it's in a Docker container, it can be shipped and run anywhere that has a Docker Engine -- your laptop, a CI server, AWS, a data center in Tokyo.

The infrastructure doesn't need to know what's inside. It just needs to know how to run a container.

---

## Let's See Docker in Action

Before we go further, let's verify your setup and get a feel for the tool. Run these commands and we'll look at what they tell you.

### Check your Docker version

```bash
docker version
```

You'll see output like this:

```
Client: Docker Engine - Community
 Version:           26.1.0
 API version:       1.45
 Go version:        go1.21.9
 OS/Arch:           linux/amd64

Server: Docker Engine - Community
 Engine:
  Version:          26.1.0
  API version:      1.45 (minimum version 1.24)
```

Notice there's a **Client** and a **Server**. The Docker CLI (the `docker` command you type) is just a client that talks to the Docker daemon -- a background process that does the actual work. This client-server architecture means you can run `docker` commands remotely against a daemon running on another machine. Useful in CI/CD pipelines.

### Inspect your Docker system

```bash
docker info
```

This gives you the full picture: number of running/stopped containers, images, storage driver, cgroup version, CPU and memory limits. Two things worth noting:

- **Storage Driver** -- usually `overlay2`. This is the UnionFS implementation that makes image layering work (more on this in Lesson 02).
- **Cgroup Version** -- version 2 is the modern one. If you're on a recent OS you'll see this.

---

## Containers vs VMs -- When to Use Each

Containers are not a VM replacement in every case. Here's a practical guide:

**Use containers when:**
- You're deploying application workloads (web servers, APIs, workers)
- You want fast startup times (deployments, auto-scaling)
- You need many isolated environments on shared hardware
- You're building microservices

**Use VMs when:**
- You need strong security isolation (running untrusted code, multi-tenant infrastructure)
- The app requires a different kernel (Linux app on Windows, or vice versa)
- You need to run a full OS for OS-level testing
- Regulatory requirements mandate hardware-level isolation

In practice at NoCappuccino, we run our apps in containers and those containers run *inside* VMs on our cloud provider. You get the operational benefits of both.

---

## Summary

- Docker solves the "it works on my machine" problem by packaging the app *and* its environment together
- Containers share the host kernel -- they're lighter and faster than VMs
- Namespaces provide isolation; cgroups provide resource limits
- The Docker runtime stack (CLI -> daemon -> containerd -> runc) is a layered architecture where each component has a clear job
- Docker Desktop runs a Linux VM on macOS/Windows; native Docker runs directly on the Linux kernel
- The shipping container analogy holds: standard format, runs anywhere

Ready to dig into images and containers? Let's go.

**Next lesson:** [Images and Containers](02-images-and-containers.md)
