# Lesson 03: OverlayFS and Layers

> "Every time someone asks 'why is my image 2GB?' or 'why did my build cache miss?', the answer is in the layers. Let me show you what's actually on disk."
> — Sarah

---

## The Problem OverlayFS Solves

Docker images are built from layers. Each `RUN`, `COPY`, or `ADD` instruction in a Dockerfile creates a new layer. If you have 50 containers running from the same image, you don't want 50 copies of that image on disk.

**OverlayFS** (Overlay Filesystem) is a **union filesystem** that merges multiple directories into a single unified view. It lets all those containers share the same read-only image layers while giving each one its own writable space.

---

## The Four OverlayFS Directories

OverlayFS works with four directories:

```
┌──────────────────────────────────────┐
│         merged (unified view)        │  ← What the container sees
├──────────────────────────────────────┤
│         upper (writable layer)       │  ← Container's changes go here
├──────────────────────────────────────┤
│         lower (read-only layers)     │  ← Image layers (stacked)
├──────────────────────────────────────┤
│         workdir (internal scratch)   │  ← OverlayFS bookkeeping
└──────────────────────────────────────┘
```

| Directory | Role |
|-----------|------|
| **lower** | One or more read-only directories stacked bottom-up. These are the image layers. |
| **upper** | A single writable directory. All modifications (new files, edits, deletes) land here. |
| **merged** | The unified view presented to the process. Reads fall through from upper → lower. |
| **workdir** | Internal scratch space OverlayFS uses for atomic operations. You never touch this. |

---

## Seeing It on a Real Container

Start a container and inspect its filesystem layers:

```bash
docker run -d --name learn-dd-overlay-demo \
  --label app=learn-docker-k8s --label track=deep-dive \
  nginx:alpine
```

### Find the GraphDriver data

```bash
docker inspect learn-dd-overlay-demo --format '{{json .GraphDriver.Data}}' | python3 -m json.tool
```

You'll see something like:

```json
{
    "LowerDir": "/var/lib/docker/overlay2/<id1>/diff:/var/lib/docker/overlay2/<id2>/diff:...",
    "MergedDir": "/var/lib/docker/overlay2/<id>/merged",
    "UpperDir": "/var/lib/docker/overlay2/<id>/diff",
    "WorkDir": "/var/lib/docker/overlay2/<id>/work"
}
```

- **LowerDir** — Colon-separated list of image layer directories (read-only)
- **UpperDir** — The container's writable layer
- **MergedDir** — The union mount the container sees as its root filesystem
- **WorkDir** — OverlayFS internal bookkeeping

### Count the layers

The number of paths in `LowerDir` (separated by `:`) tells you how many read-only layers the image has:

```bash
docker inspect learn-dd-overlay-demo \
  --format '{{.GraphDriver.Data.LowerDir}}' | tr ':' '\n' | wc -l
```

---

## Copy-on-Write in Action

The copy-on-write (COW) mechanism is the key optimization. Here's how it works:

### Reading a file
1. Process reads `/etc/nginx/nginx.conf`
2. OverlayFS checks the upper layer — file not there
3. Falls through to the lower layers — found it
4. Returns the file from the lower layer
5. **No copy is made** — all containers share this read-only layer

### Writing to an existing file
1. Process writes to `/etc/nginx/nginx.conf`
2. OverlayFS copies the entire file from the lower layer to the upper layer (**copy-up**)
3. The write happens on the upper layer copy
4. Future reads see the upper layer version (it shadows the lower layer)
5. The lower layer file is untouched — other containers still see the original

### Creating a new file
1. Process creates `/app/data.json`
2. The file is written directly to the upper layer
3. No copy-up needed — the file didn't exist before

### Deleting a file
1. Process deletes `/etc/nginx/nginx.conf`
2. OverlayFS creates a **whiteout file** in the upper layer
3. The whiteout tells OverlayFS to hide the lower layer version
4. The file appears gone in the merged view, but still exists in the lower layer

Let's demonstrate:

```bash
# Check if the file exists in the container:
docker exec learn-dd-overlay-demo cat /etc/nginx/nginx.conf > /dev/null && echo "File exists"

# The upper layer should be mostly empty right now:
docker inspect learn-dd-overlay-demo \
  --format '{{.GraphDriver.Data.UpperDir}}'
# On Linux, you could: ls $(docker inspect ... --format '{{.GraphDriver.Data.UpperDir}}')

# Now modify a file inside the container:
docker exec learn-dd-overlay-demo sh -c 'echo "# modified" >> /etc/nginx/nginx.conf'

# The copy-up happened — the file now exists in the upper layer too
# On Linux: ls $(docker inspect ... --format '{{.GraphDriver.Data.UpperDir}}')/etc/nginx/

# Create a brand new file:
docker exec learn-dd-overlay-demo sh -c 'echo "hello" > /tmp/new-file.txt'

# Delete a file:
docker exec learn-dd-overlay-demo rm /etc/nginx/fastcgi_params

# The whiteout is a character device in the upper layer:
# On Linux: ls -la $(docker inspect ... --format '{{.GraphDriver.Data.UpperDir}}')/etc/nginx/
# You'll see: c--------- ... fastcgi_params  (character device = whiteout)
```

> ⚠️ **Docker Desktop users:** The `/var/lib/docker/overlay2/` paths are inside the Docker Desktop VM. To explore them:
> ```bash
> docker run --rm --privileged --pid=host \
>   -v /var/lib/docker:/var/lib/docker:ro \
>   alpine ls /var/lib/docker/overlay2/
> ```

---

## Why Layers Matter for Image Size

Each Dockerfile instruction creates a layer. Understanding this explains some common image optimization mistakes.

### The "delete doesn't free space" problem

```dockerfile
# BAD: This image is still huge!
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y build-essential   # Layer 1: +300MB
RUN rm -rf /var/lib/apt/lists/*                            # Layer 2: adds whiteouts, ~0 savings
```

The files from Layer 1 still exist in Layer 1's directory on disk. Layer 2 just adds whiteout markers. The total image size is Layer 1 + Layer 2.

```dockerfile
# GOOD: Single layer, cleanup in the same RUN
FROM ubuntu:22.04
RUN apt-get update && \
    apt-get install -y build-essential && \
    rm -rf /var/lib/apt/lists/*            # All in one layer: smaller
```

### Inspecting layer sizes

```bash
# See each layer's size:
docker history nginx:alpine
```

```
IMAGE          CREATED       CREATED BY                                     SIZE
<id>           2 days ago    CMD ["nginx" "-g" "daemon off;"]               0B
<id>           2 days ago    STOPSIGNAL SIGQUIT                             0B
<id>           2 days ago    EXPOSE map[80/tcp:{}]                          0B
<id>           2 days ago    ENTRYPOINT ["docker-entrypoint.sh"]            0B
<id>           2 days ago    COPY docker-entrypoint.sh / # buildkit         4.62kB
<id>           2 days ago    RUN /bin/sh -c set -x && addgroup...           19.2MB
<id>           2 days ago    /bin/sh -c #(nop) ADD file:...                 7.38MB
```

Instructions like `CMD`, `EXPOSE`, and `STOPSIGNAL` add 0-byte layers (metadata only). The `RUN` and `COPY/ADD` instructions have actual content.

---

## Layer Caching and Build Performance

Docker caches layers by their instruction hash. When rebuilding an image:

1. Docker checks each instruction top-to-bottom
2. If the instruction hasn't changed AND the parent layer is cached → reuse the cache
3. The moment a cache miss occurs → all subsequent layers rebuild

This is why instruction order in a Dockerfile matters:

```dockerfile
# GOOD ordering: dependencies change rarely, code changes often
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./           # Layer: rarely changes
RUN npm ci                      # Layer: only rebuilds when deps change
COPY . .                        # Layer: changes on every code edit
RUN npm run build               # Layer: rebuilds when code changes
```

```dockerfile
# BAD ordering: everything rebuilds on every code change
FROM node:20-alpine
WORKDIR /app
COPY . .                        # Layer: changes on every code edit
RUN npm ci                      # Layer: rebuilds every time (cache busted)
RUN npm run build               # Layer: rebuilds every time
```

---

## Layer Sharing Between Images and Containers

Multiple images that share the same base image share the same lower layers on disk:

```bash
# Pull two images with the same base:
docker pull nginx:alpine
docker pull node:alpine

# Both are based on alpine — they share those base layers
# Check with:
docker image inspect nginx:alpine --format '{{json .RootFS.Layers}}' | python3 -m json.tool
docker image inspect node:alpine --format '{{json .RootFS.Layers}}' | python3 -m json.tool
```

The first layer hash will be identical — it's the alpine base layer, stored only once on disk.

Similarly, 100 containers from the same image share all the read-only layers. Only the upper (writable) layer is unique per container. This is why containers are so much more space-efficient than VMs.

---

## Checking Disk Usage

```bash
# Overall Docker disk usage:
docker system df

# Detailed breakdown:
docker system df -v
```

The "SHARED SIZE" column shows how much data is shared with other images/containers via layer deduplication.

---

## Cleanup

```bash
docker rm -f learn-dd-overlay-demo 2>/dev/null
```

---

## Summary

- OverlayFS merges read-only image layers (lower) with a writable container layer (upper) into a unified view (merged)
- Copy-on-write means reads are free (shared), writes copy the file up, and deletes create whiteouts
- Deleting a file in a later layer doesn't reclaim space — the file still exists in the earlier layer
- Layer ordering affects build cache efficiency — put rarely-changing instructions first
- Multiple containers from the same image share all read-only layers — only the writable layer is unique
- `docker history` shows layer sizes; `docker system df` shows overall disk usage
- Understanding layers explains both "why is my image big?" and "why did my build cache miss?"

---

**Next:** Time to put this knowledge to work. Head to the [challenges](../challenges/01-namespace-exploration.md).
